#!/bin/bash
# 检查 iproute2 deb 的元信息与依赖
set -uo pipefail
D=/tmp/itest/iproute2.deb

echo "=== 包信息 ==="
dpkg-deb -f "$D" Package Version Architecture Depends Pre-Depends
echo
echo "=== 内含文件（关键）==="
dpkg-deb -c "$D" | grep -E "sbin/ip$|bin/ip$|sbin/tc$|sbin/ss$|sbin/bridge$" | head

echo
echo "=== 检查依赖包在 rootfs 中是否存在 ==="
MNT=/mnt/rootfs_edit
mkdir -p "$MNT"
mountpoint -q "$MNT" || mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

DEPS=$(dpkg-deb -f "$D" Depends)
echo "  依赖串: $DEPS"
for dep in $(echo "$DEPS" | tr ',' '\n' | sed 's/|.*//' | sed 's/(.*//' | tr -d ' '); do
    got=$(dpkg --root="$MNT" -l 2>/dev/null | awk -v p="$dep" '$2 ~ "^"p":" {print $2" "$3}')
    printf "  %-24s %s\n" "$dep" "${got:-缺失}"
done

umount "$MNT"
