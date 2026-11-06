#!/bin/bash
# 为 SP970 构建去 modem 固件：
#   1) 设备树：从 OpenStick common dtsi 移除 modem 相关节点
#   2) 内核配置：关闭 Q6V5/MSS、BAM DMUX、RPMSG WWAN、QMI、memshare 等
set -euo pipefail

DTS_QCOM=/opt/msm8916/linux/arch/arm64/boot/dts/qcom
COMMON="$DTS_QCOM/msm8916-handsome-openstick-common.dtsi"
BUILD=/opt/msm8916/build
CONFIG="$BUILD/.config"

echo "=== backup ==="
[ -f "$COMMON.orig" ] || cp "$COMMON" "$COMMON.orig"
[ -f "$CONFIG.orig" ] || cp "$CONFIG" "$CONFIG.orig"

echo "=== 1) dts: drop msm8916-modem.dtsi include ==="
sed -i '/#include "msm8916-modem.dtsi"/d' "$COMMON"

echo "=== 2) dts: drop mpss_mem reserved-memory ==="
python3 - "$COMMON" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
# 移除 mpss_mem/gps_mem 保留内存节点（modem firmware 区域）
pattern = re.compile(
    r"\n\t\tmpss_mem: gps_mem: mpss@86800000 \{.*?\n\t\t\};\n", re.S)
new, n = pattern.subn("\n", s)
open(p, "w").write(new)
print("mpss_mem removed:", n)
PY

echo "=== 3) dts: neuter &memshare / &mpss references if any remain ==="
grep -n "memshare\|mpss" "$COMMON" || echo "(no remaining refs)"

echo "=== 4) kernel config: disable modem drivers ==="
python3 - "$CONFIG" <<'PY'
import sys
p = sys.argv[1]
disable = [
    "CONFIG_QCOM_Q6V5_MSS",
    "CONFIG_QCOM_Q6V5_COMMON",
    "CONFIG_QCOM_Q6V5_PAS",
    "CONFIG_QCOM_Q6V5_WCSS",
    "CONFIG_QCOM_QMI_HELPERS",
    "CONFIG_QCOM_MEMSHARE_QMI_SERVICE",
    "CONFIG_QCOM_BAM_DMUX",
    "CONFIG_RPMSG_WWAN_CTRL",
    "CONFIG_QCOM_IPA",
    "CONFIG_RMNET",
    "CONFIG_WWAN",
    "CONFIG_QRTR",
    "CONFIG_QRTR_SMD",
    "CONFIG_QRTR_TUN",
    "CONFIG_MEDIA_SUBDRV_AUTOSELECT",
]
lines = open(p).read().splitlines()
out = []
seen = set()
for ln in lines:
    m = ln.lstrip("# ").split("=")[0]
    if m in disable:
        out.append(f"# {m} is not set")
        seen.add(m)
    else:
        out.append(ln)
open(p, "w").write("\n".join(out) + "\n")
print("disabled:", sorted(seen))
PY

echo "=== done ==="
