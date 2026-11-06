#!/bin/bash
set -uo pipefail
MNT=/mnt/rootfs_chk3
mkdir -p "$MNT"
mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || { echo "MOUNT FAILED"; exit 1; }
echo "mount ok"
echo "=== /etc/fstab ==="
cat "$MNT/etc/fstab" 2>/dev/null || echo "(none)"
echo
echo "=== resize2fs 相关单元/脚本 ==="
grep -rl "resize2fs" "$MNT/etc" "$MNT/usr/lib/systemd/system" 2>/dev/null | head
echo
echo "=== growpart / 首次启动扩缩容服务 ==="
ls "$MNT/etc/systemd/system/" 2>/dev/null | head -20
echo
echo "=== 文件数/大小 ==="
du -sh --exclude=proc --exclude=sys "$MNT" 2>/dev/null
df -h "$MNT" | tail -1
umount "$MNT"
