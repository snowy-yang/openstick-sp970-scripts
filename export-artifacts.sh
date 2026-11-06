#!/bin/bash
# 导出 SP970 去 modem 固件产物到 Windows 侧 D:\msm8916\out
set -euo pipefail
OUT=/mnt/d/msm8916/out
BUILD=/opt/msm8916/build
LK2ND=/opt/msm8916/lk2nd/build-lk2nd-msm8916

mkdir -p "$OUT"
rm -f "$OUT"/Image "$OUT"/*.dtb "$OUT"/lk2nd.img 2>/dev/null || true

cp "$BUILD/arch/arm64/boot/Image"                                    "$OUT/Image"
cp "$BUILD/arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-sp970.dtb" "$OUT/"
cp "$LK2ND/lk2nd.img"                                               "$OUT/lk2nd.img"
cp "$LK2ND/emmc_appsboot.mbn"                                       "$OUT/emmc_appsboot.mbn" 2>/dev/null || true

chmod 644 "$OUT"/* 2>/dev/null || true
cd "$OUT"
sha256sum Image msm8916-handsome-openstick-sp970.dtb lk2nd.img > SHA256SUMS.txt
ls -lh
echo "=== config snapshot ==="
grep -E "QCOM_Q6V5_MSS|QCOM_BAM_DMUX|RPMSG_WWAN_CTRL|QCOM_MEMSHARE|^# CONFIG_WWAN|^# CONFIG_QRTR|^# CONFIG_RMNET" "$BUILD/.config" | tee "$OUT/kernel-modem-disabled.txt"
