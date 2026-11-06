#!/bin/bash
# 阶段2：构建去 modem 的 SP970 boot.img
#   boot.img = 我们的 zImage + 我们的 SP970 dtb + 官方 ramdisk(替换为新编模块、剔除 modem 模块)
set -euo pipefail

MNT=/mnt/rootfs_rw
RAW=/opt/msm8916/dl/debian/rootfs.raw
WORK=/opt/msm8916/bootwork
BUILD=/opt/msm8916/build
MODVER=5.15.0-handsomekernel+

echo "=== [1] 卸载 rootfs ==="
if mountpoint -q "$MNT"; then sync; umount "$MNT"; echo "  unmounted"; else echo "  already unmounted"; fi

echo
echo "=== [2] rootfs 稀疏化 ==="
mkdir -p "$WORK"
img2simg "$RAW" "$WORK/rootfs.img"
ls -lh "$WORK/rootfs.img"
file "$WORK/rootfs.img"

echo
echo "=== [3] 解包官方 boot.img ==="
rm -rf "$WORK/unpack"
mkdir -p "$WORK/unpack"
cd "$WORK/unpack"
abootimg -x /opt/msm8916/dl/boot-sp970.img >/dev/null
ls -1

echo
echo "=== [4] 处理 ramdisk ==="
mkdir -p ramdisk_root
cd ramdisk_root
zcat ../initrd.img | cpio -idm --quiet
MODDIR="usr/lib/modules/$MODVER"

for m in "kernel/drivers/net/wwan/qcom_bam_dmux.ko" \
         "kernel/drivers/net/wwan/rpmsg_wwan_ctrl.ko" \
         "kernel/drivers/net/ethernet/qualcomm/rmnet/rmnet.ko"; do
    [ -e "$MODDIR/$m" ] && { rm -f "$MODDIR/$m"; echo "  removed $m"; }
done

replaced=0
# 使用 strip 过的模块目录（体积与官方一致）
MODSRC=/opt/msm8916/modinst/lib/modules/$MODVER/kernel
while IFS= read -r src; do
    rel="${src#"$MODSRC"/}"
    dst="$MODDIR/kernel/$rel"
    if [ -f "$dst" ]; then
        cp -f "$src" "$dst"
        replaced=$((replaced+1))
    fi
done < <(find "$MODSRC" -name "*.ko" -type f)
echo "  replaced $replaced modules"

# 重新生成索引（vmlinux 不在，depmod 可能警告，属正常）
depmod -b "$PWD" "$MODVER" 2>&1 | head -5 || true
echo "  depmod done"

find . -not -path "./proc/*" -not -path "./sys/*" -print0 \
    | cpio -o -H newc --quiet --null | gzip -9 > ../initrd-new.img
cd ..
ls -lh initrd.img initrd-new.img

echo
echo "=== [5] 内核附加 SP970 dtb ==="
# 不能 cp zImage（那是官方解包出来的内核），必须用我们自己编译的 Image
# 注意：arm64 的 Image 是未压缩的，需 gzip 压缩后才能塞进 boot 分区
gzip -9 -c "$BUILD/arch/arm64/boot/Image" > zImage-new
echo "  源: $BUILD/arch/arm64/boot/Image (gzip -9 压缩)"
ls -lh zImage-new
python3 - <<'PY'
src = "/opt/msm8916/build/arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-sp970.dtb"
dst = "/opt/msm8916/bootwork/unpack/zImage-new"
dtb = open(src, "rb").read()
z = open(dst, "rb").read()
i = z.rfind(b"\xd0\x0d\xfe\xed")
if i > 0:
    print(f"  strip existing dtb at {i}")
    z = z[:i]
open(dst, "wb").write(z + dtb)
print(f"  kernel {len(z)} + dtb {len(dtb)} = {len(z)+len(dtb)}")
PY

echo
echo "=== [6] 生成 boot.img ==="
cat bootimg.cfg
abootimg --create ../boot-sp970-nomodrm.img -f bootimg.cfg -k zImage-new -r initrd-new.img
cd ..
ls -lh boot-sp970-nomodrm.img
echo
abootimg -i boot-sp970-nomodrm.img
echo "DONE"
