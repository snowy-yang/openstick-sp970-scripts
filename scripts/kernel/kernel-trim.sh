#!/bin/bash
# 保守内核精简：仅关闭 SP970 上确定不存在的硬件对应驱动
# 保留：40 个网卡厂商驱动、USB 子系统、无关文件系统、蓝牙栈（保守策略不碰）
set -euo pipefail
CFG=/opt/msm8916/build/.config
cp -f "$CFG" "$CFG.before-trim"

python3 - "$CFG" <<'PY'
import sys
p = sys.argv[1]

# 需要关闭的配置项（前缀匹配，会关掉所有子项）
groups = {
    "KVM / 虚拟化": ["CONFIG_KVM", "CONFIG_VIRTUALIZATION", "CONFIG_VHOST",
                     "CONFIG_VIRTIO"],
    "声音子系统":   ["CONFIG_SOUND", "CONFIG_SND"],
    "摄像头 / 视频": ["CONFIG_VIDEO_QCOM_CAMSS", "CONFIG_VIDEO_QCOM_VENUS",
                     "CONFIG_USB_VIDEO_CLASS", "CONFIG_MEDIA_SUPPORT",
                     "CONFIG_VIDEO_DEV", "CONFIG_VIDEO_V4L2"],
    "蓝牙":         ["CONFIG_BT"],
    "触屏驱动":     ["CONFIG_TOUCHSCREEN"],
}

lines = open(p).read().splitlines()
killed = []
out = []
for ln in lines:
    key = None
    if ln.startswith("CONFIG_"):
        key = ln.split("=")[0]
    elif ln.startswith("# CONFIG_") and ln.endswith(" is not set"):
        key = ln[2:-len(" is not set")]
    if key:
        for why, prefixes in groups.items():
            if any(key == pre or key.startswith(pre + "_") for pre in prefixes):
                out.append(f"# {key} is not set")
                killed.append((why, key))
                break
        else:
            out.append(ln)
    else:
        out.append(ln)

open(p, "w").write("\n".join(out) + "\n")

from collections import defaultdict
d = defaultdict(list)
for why, k in killed:
    d[why].append(k)
for why in groups:
    print(f"  {why}: {len(d[why])} 项")
PY

echo
echo "=== olddefconfig ==="
cd /opt/msm8916/linux
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/opt/msm8916/build olddefconfig >/tmp/trim-olddef.log 2>&1
echo "  exit=$?"

echo
echo "=== 确认关键项已关闭 ==="
for c in CONFIG_KVM CONFIG_SOUND CONFIG_SND CONFIG_BT CONFIG_VIDEO_QCOM_CAMSS \
         CONFIG_MEDIA_SUPPORT CONFIG_TOUCHSCREEN_ATMEL_MXT; do
    grep -E "^($c=|# $c is not set)" /opt/msm8916/build/.config | head -1 | sed 's/^/  /'
done

echo
echo "=== 确认保留项仍开启 ==="
for c in CONFIG_WCN36XX CONFIG_CFG80211 CONFIG_MAC80211 CONFIG_USB_GADGET \
         CONFIG_DRM CONFIG_NET_VENDOR_INTEL CONFIG_EXT4_FS; do
    grep -E "^$c=" /opt/msm8916/build/.config | head -1 | sed 's/^/  /' || echo "  $c MISSING!"
done
