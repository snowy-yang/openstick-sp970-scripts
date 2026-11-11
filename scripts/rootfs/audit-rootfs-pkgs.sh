#!/bin/bash
# 统计 rootfs 中具体可清理项
set -uo pipefail
MNT=/mnt/rootfs_size
mkdir -p "$MNT"
mountpoint -q "$MNT" || mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

echo "=== 大体积软件包 TOP 20 ==="
dpkg --root="$MNT" --get-selections 2>/dev/null | awk '{print $1}' > /tmp/pkgs.txt
while read -r p; do
    sz=$(dpkg --root="$MNT" -s "$p" 2>/dev/null | awk '/^Installed-Size:/ {print $2}')
    [ -n "${sz:-}" ] && echo "$sz $p"
done < /tmp/pkgs.txt | sort -rn | head -20 | while read -r s n; do
    printf "  %7d KB  %s\n" "$s" "$n"
done

echo
echo "=== 内核模块包 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -iE "linux-image|linux-headers|linux-kbuild" | awk '{printf "  %-40s %s\n", $2, $3}'

echo
echo "=== 可安全移除的体积 ==="
for p in usr/share/locale usr/share/doc usr/share/man usr/src var/lib/apt/lists; do
    printf "  %-24s %s\n" "$p" "$(du -sh "$MNT/$p" 2>/dev/null | cut -f1)"
done

echo
echo "=== initramfs 工具（可移除）==="
dpkg --root="$MNT" -l 2>/dev/null | grep -iE "initramfs-tools" | awk '{printf "  %s %s\n", $2, $3}'

umount "$MNT"
echo OK
