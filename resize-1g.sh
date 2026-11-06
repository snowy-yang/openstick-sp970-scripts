#!/bin/bash
# 将 rootfs 文件系统扩到合理余量（1GB），避免设备端空间告急且无自动扩展
set -uo pipefail
RAW=/opt/msm8916/dl/debian/rootfs.raw

echo "=== 当前 ==="
ls -lh "$RAW"
dumpe2fs -h "$RAW" 2>/dev/null | grep -E "Block count|Block size"

echo
echo "=== 扩展文件系统到 1GB (262144 块) ==="
truncate -s 1G "$RAW"
resize2fs "$RAW" 2>&1 | tail -3

echo
echo "=== 结果 ==="
ls -lh "$RAW"
dumpe2fs -h "$RAW" 2>/dev/null | grep -E "Block count"

echo
echo "=== 可用空间检查 ==="
MNT=/mnt/rootfs_chk4
mkdir -p "$MNT"
mount -o loop,ro "$RAW" "$MNT" && df -h "$MNT" | tail -1 && umount "$MNT"
