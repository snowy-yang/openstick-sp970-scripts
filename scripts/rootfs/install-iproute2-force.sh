#!/bin/bash
# 用 dpkg --root + --force-architecture 离线安装 arm64 包
set -uo pipefail
MNT=/mnt/rootfs_edit
DEBS=/opt/msm8916/debs
mountpoint -q "$MNT" || mount -o loop,rw /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

echo "=== 安装顺序：libbpf0 -> libelf1 -> iproute2 ==="
# debconf 是 Depends 中的可选替代(| debconf-2.0)，且 rootfs 已有 debconf 1.5.77，跳过
for d in libbpf0_0.3-2_arm64.deb libelf1_0.183-1_arm64.deb iproute2_5.10.0-4_arm64.deb; do
    echo
    echo "--- $d ---"
    dpkg --root="$MNT" \
         --force-architecture \
         --force-depends \
         --force-overwrite \
         --unpack "$DEBS/$d" 2>&1 | grep -vE '^\(正在读取数据库' | tail -5 | sed 's/^/  /'
done

echo
echo "=== configure -a ==="
dpkg --root="$MNT" --force-architecture --force-depends --force-overwrite --configure -a 2>&1 \
    | grep -vE '^\(正在读取数据库' | tail -8 | sed 's/^/  /'

echo
echo "=== 验证 ==="
[ -x "$MNT/bin/ip" ] && echo "  ✅ /bin/ip 存在 ($(stat -c%s "$MNT/bin/ip") bytes)" || echo "  ❌ /bin/ip 缺失"
[ -L "$MNT/sbin/ip" ] && echo "  ✅ /sbin/ip -> $(readlink "$MNT/sbin/ip")"
[ -x "$MNT/sbin/tc" ] && echo "  ✅ /sbin/tc 存在"
[ -x "$MNT/sbin/ss" ] && echo "  ✅ /sbin/ss 存在"

echo
echo "=== ip 依赖库检查 ==="
ldd "$MNT/bin/ip" 2>/dev/null | sed 's/^/  /' || true
