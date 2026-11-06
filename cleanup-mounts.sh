#!/bin/bash
# 清理所有测试用 loop 挂载点
for d in /mnt/vf_dep3 /mnt/vf_dep2 /mnt/vf_dep /mnt/vf_wifi /mnt/vf_root \
         /mnt/rootfs_slim /mnt/rootfs_chk4 /mnt/rootfs_chk3 /mnt/rootfs_size \
         /mnt/rootfs_chk2 /mnt/rootfs_chk /mnt/rootfs_rw /mnt/rootfs; do
    if mountpoint -q "$d" 2>/dev/null; then
        umount -l "$d" 2>/dev/null && echo "umounted $d"
    fi
done
echo "--- remaining loop mounts ---"
mount | grep -E "/mnt/(vf_|rootfs)" || echo "CLEAN"
