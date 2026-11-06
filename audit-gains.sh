#!/bin/bash
# 量化裁剪收益：Image 体积占比分析
set -uo pipefail
BUILD=/opt/msm8916/build

echo "=== vmlinux 各部分大小 ==="
ls -l "$BUILD/vmlinux" 2>/dev/null | awk '{printf "  vmlinux: %.2f MB\n", $5/1048576}'
ls -l "$BUILD/arch/arm64/boot/Image" | awk '{printf "  Image(gz): %.2f MB\n", $5/1048576}'

echo
echo "=== 用 size 看代码段构成 ==="
aarch64-linux-gnu-size "$BUILD/vmlinux" 2>/dev/null | head -5

echo
echo "=== 模块总体积 ==="
du -sh /opt/msm8916/modinst/lib/modules/5.15.0-handsomekernel+/kernel 2>/dev/null
echo "  模块数: $(find /opt/msm8916/modinst -name '*.ko' | wc -l)"

echo
echo "=== boot.img 空间占用分析 ==="
W=/opt/msm8916/bootwork/unpack
ls -l "$W/zImage-new" "$W/initrd-new.img" 2>/dev/null | awk '{printf "  %-16s %.2f MB\n", $9, $5/1048576}'
echo "  boot 分区上限: 12.96 MB (13588480)"
echo

echo "=== rootfs 已用/总量 ==="
echo "  rootfs.raw: $(ls -lh /opt/msm8916/dl/debian/rootfs.raw | awk '{print $5}')  (ext4, 已用约 516MB)"
echo "  sparse:     $(ls -lh /opt/msm8916/bootwork/rootfs.img | awk '{print $5}')"

echo
echo "=== rootfs 中可裁剪的软件体积 ==="
MNT=/mnt/rootfs_size
mkdir -p "$MNT"
mountpoint -q "$MNT" || mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1
for p in usr/share/doc usr/share/man usr/share/locale usr/src usr/include var/cache/apt var/lib/apt/lists usr/lib/debug; do
    [ -d "$MNT/$p" ] && printf "  %-24s %s\n" "$p" "$(du -sh "$MNT/$p" 2>/dev/null | cut -f1)"
done
echo
echo "  linux-headers 包体积:"
du -sh "$MNT/usr/src/linux-headers"* 2>/dev/null
echo "  全盘已用: $(du -sh --exclude=proc --exclude=sys "$MNT" 2>/dev/null | cut -f1)"
umount "$MNT"
