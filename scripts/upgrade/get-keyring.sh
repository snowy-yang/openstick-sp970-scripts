#!/bin/bash
# 在宿主机下载 bookworm 的 debian-archive-keyring 包
set -uo pipefail
D=/opt/msm8916/debs
cd "$D"
BASE="http://ftp.debian.org/debian/pool/main/d/debian-archive-keyring"

echo "=== 列出可用版本 ==="
curl -sL "$BASE/" | grep -oE 'debian-archive-keyring_[^"<>]*_all\.deb' | sort -u | tail -5

echo
echo "=== 下载最新 ==="
LATEST=$(curl -sL "$BASE/" | grep -oE 'debian-archive-keyring_[^"<>]*_all\.deb' | sort -uV | tail -1)
echo "  文件: $LATEST"
if [ -n "$LATEST" ]; then
    curl -sL -o "$LATEST" "$BASE/$LATEST" -w '  HTTP:%{http_code} SIZE:%{size_download}\n'
    ls -lh "$LATEST"
    echo
    echo "=== 包信息 ==="
    dpkg-deb -f "$LATEST" Package Version
    echo
    echo "=== 包含的密钥 ==="
    dpkg-deb -c "$LATEST" | grep -E "bookworm" | head -10
fi
