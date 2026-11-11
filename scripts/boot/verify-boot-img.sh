#!/bin/bash
# 最终验证 boot.img 内容正确性
set -uo pipefail
WORK=/opt/msm8916/bootwork
IMG="$WORK/boot-sp970-nomodrm.img"
VERIFY=/tmp/verify_boot

echo "=== 基本信息 ==="
abootimg -i "$IMG"

echo
echo "=== 解包并检查 ==="
rm -rf "$VERIFY"; mkdir -p "$VERIFY"
cd "$VERIFY"
abootimg -x "$IMG" >/dev/null

echo
echo "--- [A] 内核内嵌 dtb 是否为 SP970 去 modem 版 ---"
python3 - <<'PY'
z = open("/tmp/verify_boot/zImage","rb").read()
i = z.rfind(b"\xd0\x0d\xfe\xed")
print(f"  dtb offset={i}, bytes={len(z)-i}")
open("/tmp/verify_boot/embedded.dtb","wb").write(z[i:])
PY
dtc -I dtb -O dts "$VERIFY/embedded.dtb" -o "$VERIFY/embedded.dts" 2>/dev/null
grep -m1 'model = ' "$VERIFY/embedded.dts" | sed 's/^/  /'
python3 /mnt/d/msm8916/scripts/check-modem-status.py "$VERIFY/embedded.dts"

echo
echo "--- [B] ramdisk 中 modem 模块是否已移除 ---"
mkdir -p "$VERIFY/rd" && cd "$VERIFY/rd"
zcat ../initrd.img | cpio -idm --quiet 2>/dev/null
MD="usr/lib/modules/5.15.0-handsomekernel+"
echo "  模块总数: $(find "$MD" -name '*.ko' | wc -l)"
echo "  modem 模块:"
find "$MD" -name "*.ko" | grep -iE "bam_dmux|rpmsg_wwan|rmnet" || echo "    (无, 已清除)"

echo
echo "--- [C] ramdisk 模块与内核版本匹配 ---"
echo "  ramdisk 模块路径: $(ls -1 usr/lib/modules/)"
grep -m1 "Linux version" -r usr/lib/modules/*/modules.builtin 2>/dev/null || true

echo
echo "--- [D] rootfs 稀疏镜像 ---"
ls -lh "$WORK/rootfs.img" | sed 's/^/  /'
file "$WORK/rootfs.img" | sed 's/^/  /'

echo
echo "=== 全部验证完成 ==="
