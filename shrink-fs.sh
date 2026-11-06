#!/bin/bash
# 收缩 ext4 文件系统，使稀疏镜像真正变小
set -uo pipefail
RAW=/opt/msm8916/dl/debian/rootfs.raw

echo "=== 当前大小 ==="
ls -lh "$RAW"
dumpe2fs -h "$RAW" 2>/dev/null | grep -E "Block count|Block size|Inode count"

echo
echo "=== resize2fs 收缩到最小 ==="
resize2fs -M "$RAW" 2>&1 | tail -5

echo
echo "=== 收缩后 ==="
ls -lh "$RAW"
dumpe2fs -h "$RAW" 2>/dev/null | grep -E "Block count"

echo
echo "=== 再检查一遍完整性 ==="
e2fsck -f -y "$RAW" 2>&1 | tail -3
