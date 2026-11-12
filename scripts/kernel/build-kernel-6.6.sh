#!/usr/bin/env bash
# 编译 6.6 LTS 内核（msm8916-mainline/linux 的 msm8916/6.6 分支）并组装启动镜像
#
# 用法：build-kernel-6.6.sh [源码目录] [构建目录]
#   默认 源码 /opt/msm8916/linux-6.6，构建 /opt/msm8916/build-6.6
set -euo pipefail

SRC=${1:-/opt/msm8916/linux-6.6}
OUT=${2:-/opt/msm8916/build-6.6}
CROSS=${CROSS_COMPILE:-aarch64-linux-gnu-}
DTB_NAME=msm8916-handsome-openstick-sp970.dtb
BOOTSIZE=0xcf5800
CMDLINE="earlycon root=PARTUUID=a7ab80e8-e9d1-e8cd-f157-93f69b1d141e console=ttyMSM0,115200 no_framebuffer=true rw"

log() { printf '\n=== %s ===\n' "$*"; }

[ -d "$SRC" ] || { echo "源码目录不存在: $SRC"; exit 1; }

log "配置（msm8916_defconfig + SP970 片段）"
make -C "$SRC" O="$OUT" ARCH=arm64 CROSS_COMPILE="$CROSS" msm8916_defconfig
if [ -f "$SRC/arch/arm64/configs/msm8916-sp970.config" ]; then
    "$SRC/scripts/kconfig/merge_config.sh" -m -O "$OUT" "$OUT/.config" \
        "$SRC/arch/arm64/configs/msm8916-sp970.config" >/dev/null
    make -C "$SRC" O="$OUT" ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig
fi

log "编译 Image / modules / dtbs"
make -C "$SRC" O="$OUT" ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$(nproc)" Image modules dtbs

KREL=$(make -C "$SRC" O="$OUT" -s kernelrelease)
log "产物（内核版本 $KREL）"
ls -l "$OUT/arch/arm64/boot/Image" "$OUT/arch/arm64/boot/dts/qcom/$DTB_NAME"

log "组装 boot.img"
WK=$(mktemp -d)
trap 'rm -rf "$WK"' EXIT
python3 - "$OUT/arch/arm64/boot/Image" "$OUT/arch/arm64/boot/dts/qcom/$DTB_NAME" "$WK/zImage" <<'PY'
import gzip, sys
img, dtb, out = sys.argv[1:4]
data = gzip.compress(open(img, "rb").read(), 9)
i = data.rfind(b"\xd0\x0d\xfe\xed")
if i > 0 and i > len(data) - 300000:
    data = data[:i]
data += open(dtb, "rb").read()
open(out, "wb").write(data)
print(f"kernel(dtb appended) = {len(data)} bytes")
PY

cat > "$WK/bootimg.cfg" <<EOF
bootsize = $BOOTSIZE
pagesize = 0x800
kerneladdr = 0x80080000
ramdiskaddr = 0x82000000
secondaddr = 0x0
tagsaddr = 0x81e00000
name =
cmdline = $CMDLINE
EOF

# 空 initramfs：内核直接挂 root=PARTUUID
mkdir -p "$WK/empty"
( cd "$WK/empty" && find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 ) > "$WK/initrd-empty.img"

abootimg --create "$WK/boot-6.6-noinitrd.img" -f "$WK/bootimg.cfg" \
    -k "$WK/zImage" -r "$WK/initrd-empty.img" -c "cmdline=$CMDLINE" >/dev/null

cp "$WK/boot-6.6-noinitrd.img" "$OUT/"
log "完成"
ls -l "$OUT/boot-6.6-noinitrd.img"
echo
echo "若需要带 initramfs 的版本，把 -r 换成精简 initramfs（1.88 MB），"
echo "注意 kernel($(stat -c%s "$WK/zImage")) + initramfs 必须 <= 13,588,480 字节。"