#!/bin/bash
# 用设备导出的 tar 构建新的 rootfs 镜像（Debian 12）
set -euo pipefail
TAR=/mnt/d/msm8916/dump/rootfs-debian12.tar.gz
IMG=/opt/msm8916/newrootfs.img
MNT=/mnt/newroot

echo "=== [1] 创建 1GB ext4 镜像 ==="
rm -f "$IMG"
truncate -s 1G "$IMG"
mkfs.ext4 -q -L rootfs -U "$(cat /opt/msm8916/orig-uuid 2>/dev/null || echo e92c62a7-390f-4edc-b36f-b71f931c5a21)" "$IMG"
echo "  完成: $(ls -lh "$IMG" | awk '{print $5}')"

echo
echo "=== [2] 挂载并解包 ==="
mkdir -p "$MNT"
mount -o loop "$IMG" "$MNT"
tar --numeric-owner -xzf "$TAR" -C "$MNT"
echo "  解包完成"

echo
echo "=== [3] 重建必要目录 ==="
for d in proc sys dev tmp run mnt media lost+found; do
    mkdir -p "$MNT/$d"
done
chmod 1777 "$MNT/tmp"
chmod 700 "$MNT/lost+found" 2>/dev/null || true
echo "  完成"

echo
echo "=== [4] 验证关键文件 ==="
for f in /etc/debian_version /etc/os-release /sbin/init /usr/bin/gc /usr/sbin/mobian-usb-gadget /lib/libusbgx.so.2; do
    [ -e "$MNT$f" ] && echo "  ✅ $f" || echo "  ❌ $f 缺失"
done
echo "  debian_version: $(cat "$MNT/etc/debian_version" 2>/dev/null)"

echo
echo "=== [5] 卸载 ==="
sync
umount "$MNT"

echo
echo "=== [6] 转 sparse 格式 ==="
img2simg "$IMG" /opt/msm8916/newrootfs.sparse.img
ls -lh /opt/msm8916/newrootfs.sparse.img
echo "DONE"
