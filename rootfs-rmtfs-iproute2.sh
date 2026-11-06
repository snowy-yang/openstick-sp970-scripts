#!/bin/bash
# 在 rootfs 镜像中：1) purge rmtfs  2) 安装 iproute2
# 由于是 arm64 rootfs，无法 chroot 执行 apt，故采用：
#   - rmtfs：dpkg --root 直接 purge（纯删除操作，无需执行代码）
#   - iproute2：从 Debian arm64 源下载 .deb，用 dpkg --root 解包安装
set -uo pipefail

RAW=/opt/msm8916/dl/debian/rootfs.raw
MNT=/mnt/rootfs_edit
mkdir -p "$MNT"
mountpoint -q "$MNT" && umount "$MNT"
mount -o loop,rw "$RAW" "$MNT" || { echo "MOUNT FAILED"; exit 1; }
echo "MOUNTED"

echo
echo "=== [1] purge rmtfs ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -i rmtfs || echo "  (未安装)"
dpkg --root="$MNT" --purge --force-all rmtfs 2>&1 | tail -3
echo "  验证:"
dpkg --root="$MNT" -l 2>/dev/null | grep -i rmtfs || echo "    rmtfs 已移除"
ls "$MNT/usr/bin/rmtfs" 2>/dev/null && echo "    !! 二进制残留" || echo "    二进制已移除"
ls "$MNT/lib/systemd/system/rmtfs.service" 2>/dev/null && echo "    !! 服务文件残留" || echo "    服务文件已移除"

echo
echo "=== [2] 检查 iproute2 是否已存在 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -i iproute2 || echo "  (未安装)"
ls "$MNT/usr/sbin/ip" 2>/dev/null || echo "  /usr/sbin/ip 不存在"

echo
echo "=== [3] 下载 iproute2 arm64 deb ==="
mkdir -p /opt/msm8916/debs
cd /opt/msm8916/debs
# 从 Debian bullseye arm64 源获取
apt-get download --print-uris iproute2:arm64 2>/dev/null | head -2 || true
