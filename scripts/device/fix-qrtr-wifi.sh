#!/bin/bash
# 修正：恢复 WiFi 所需的 QRTR / QMI HELPERS，但保持 modem 本体关闭
set -euo pipefail
CFG=/opt/msm8916/build/.config

echo "=== 恢复前状态 ==="
grep -E "CONFIG_QRTR|CONFIG_QCOM_QMI_HELPERS|CONFIG_QCOM_Q6V5_MSS|CONFIG_QCOM_BAM_DMUX|CONFIG_WWAN|CONFIG_RMNET" "$CFG"

python3 - "$CFG" <<'PY'
import sys
p = sys.argv[1]
enable = {
    "CONFIG_QRTR": "y",
    "CONFIG_QRTR_SMD": "y",
    "CONFIG_QCOM_QMI_HELPERS": "y",
    "CONFIG_RPMSG": "y",
    "CONFIG_RPMSG_QCOM_GLINK_SMEM": "y",
    "CONFIG_QCOM_SMD_RPM": "y",
    "CONFIG_QCOM_SMEM_STATE": "y",
}
lines = open(p).read().splitlines()
out, done = [], set()
for ln in lines:
    key = None
    if ln.startswith("CONFIG_"):
        key = ln.split("=")[0]
    elif ln.startswith("# CONFIG_") and ln.endswith(" is not set"):
        key = ln[2:-len(" is not set")]
    if key in enable:
        out.append(f"{key}={enable[key]}")
        done.add(key)
    else:
        out.append(ln)
# 补上原配置里完全缺失的项（依赖自动解析）
for k, v in enable.items():
    if k not in done:
        out.append(f"{k}={v}")
open(p, "w").write("\n".join(out) + "\n")
print("enabled:", sorted(enable))
PY

echo
echo "=== olddefconfig ==="
cd /opt/msm8916/linux
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/opt/msm8916/build olddefconfig >/tmp/fix-qrtr.log 2>&1
echo "  exit=$?"

echo
echo "=== 恢复后状态 ==="
grep -E "^CONFIG_QRTR|^CONFIG_QCOM_QMI_HELPERS|^# CONFIG_QRTR|^# CONFIG_QCOM_QMI_HELPERS|CONFIG_QCOM_Q6V5_MSS|CONFIG_QCOM_BAM_DMUX|^# CONFIG_WWAN|^CONFIG_WWAN|CONFIG_RMNET" "$CFG"
