#!/bin/bash
# 步骤1：安装 Debian 12 (bookworm) 签名密钥
set -u
echo "=== 现有密钥 ==="
ls -1 /etc/apt/trusted.gpg.d/ 2>/dev/null
echo "--- 现有密钥指纹 ---"
apt-key list 2>/dev/null | grep -E "^pub|^uid" | head -20

echo
echo "=== 下载 bookworm 密钥 ==="
# bookworm 使用 debian-archive-bookworm-*.asc
BASE=http://deb.debian.org/debian/pool/main/d/debian-archive-keyring
LATEST=$(apt-get download --print-uris debian-archive-keyring 2>/dev/null | head -1 | cut -d"'" -f2)
echo "  尝试: $LATEST"

cd /tmp
if [ -n "$LATEST" ]; then
    apt-get download debian-archive-keyring 2>&1 | tail -2
    ls -l /tmp/debian-archive-keyring*.deb 2>/dev/null
fi
