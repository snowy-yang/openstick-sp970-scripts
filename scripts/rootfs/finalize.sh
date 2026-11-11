#!/bin/bash
# 最终阶段：卸载 rootfs、重新稀疏化、验证、导出
set -uo pipefail
MNT=/mnt/rootfs_slim
RAW=/opt/msm8916/dl/debian/rootfs.raw
WORK=/opt/msm8916/bootwork
OUT=/mnt/d/msm8916/out

echo "=== [1] 卸载 ==="
if mountpoint -q "$MNT"; then sync; umount "$MNT"; echo "  unmounted"; else echo "  already"; fi

echo
echo "=== [2] e2fsck 检查 ==="
e2fsck -f -y "$RAW" 2>&1 | tail -5

echo
echo "=== [3] 重新稀疏化 ==="
rm -f "$WORK/rootfs.img"
img2simg "$RAW" "$WORK/rootfs.img"
ls -lh "$WORK/rootfs.img"

echo
echo "=== [4] 导出到 $OUT ==="
cp -f "$WORK/boot-sp970-nomodrm.img" "$OUT/boot-sp970-nomodrm.img"
cp -f "$WORK/rootfs.img"             "$OUT/rootfs-sp970-nomodrm.img"
cp -f "$WORK/unpack/zImage-new"      "$OUT/Image-sp970-nomodrm"
cp -f /opt/msm8916/build/arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-sp970.dtb "$OUT/"
cp -f /opt/msm8916/lk2nd/build-lk2nd-msm8916/lk2nd.img "$OUT/lk2nd.img"
chmod 644 "$OUT"/* 2>/dev/null

cd "$OUT"
sha256sum boot-sp970-nomodrm.img rootfs-sp970-nomodrm.img Image-sp970-nomodrm \
          msm8916-handsome-openstick-sp970.dtb lk2nd.img > SHA256SUMS.txt

echo
echo "=== 最终产物 ==="
ls -lh "$OUT"
echo
cat SHA256SUMS.txt
