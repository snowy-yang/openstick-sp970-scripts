#!/bin/bash
# 导出最终 SP970 去 modem 固件包到 Windows 侧
set -uo pipefail
OUT=/mnt/d/msm8916/out
WORK=/opt/msm8916/bootwork

mkdir -p "$OUT"
rm -f "$OUT"/*.img "$OUT"/*.dtb "$OUT"/Image "$OUT"/lk2nd* "$OUT"/emmc_appsboot.mbn "$OUT"/SHA256SUMS.txt 2>/dev/null || true

echo "=== 复制产物 ==="
cp "$WORK/boot-sp970-nomodrm.img"                    "$OUT/boot-sp970-nomodrm.img"
cp "$WORK/rootfs.img"                                "$OUT/rootfs-sp970-nomodrm.img"
cp "$WORK/unpack/zImage-new"                         "$OUT/Image-sp970-nomodrm"
cp /opt/msm8916/build/arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-sp970.dtb \
   "$OUT/msm8916-handsome-openstick-sp970.dtb"
cp /opt/msm8916/lk2nd/build-lk2nd-msm8916/lk2nd.img  "$OUT/lk2nd.img"

chmod 644 "$OUT"/* 2>/dev/null || true
cd "$OUT"
sha256sum *.img Image-sp970-nomodrm msm8916-handsome-openstick-sp970.dtb > SHA256SUMS.txt

echo
echo "=== 产物清单 ==="
ls -lh "$OUT"
echo
echo "=== SHA256 ==="
cat SHA256SUMS.txt
