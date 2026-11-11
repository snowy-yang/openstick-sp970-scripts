#!/bin/bash
set -uo pipefail
MNT=/mnt/vf_dep3
mkdir -p "$MNT"
mountpoint -q "$MNT" && umount "$MNT"
mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || { echo MOUNT FAIL; exit 1; }

echo "=== depmod 自检输出（完整）==="
depmod -b "$MNT" 5.15.0-handsomekernel+ -n 2>&1 | head -20
echo "  exit=$?"

umount "$MNT"
