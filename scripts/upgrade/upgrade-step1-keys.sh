#!/bin/bash
# Debian 11 -> 12 升级 步骤1：安装 bookworm 密钥、切换 apt 源
set -u
export DEBIAN_FRONTEND=noninteractive

echo "=== [1] 备份现有配置 ==="
cp /etc/apt/sources.list /etc/apt/sources.list.bullseye.bak 2>/dev/null
mkdir -p /root/upgrade-backup
cp -a /etc/apt/sources.list* /root/upgrade-backup/ 2>/dev/null
echo "  备份完成"

echo
echo "=== [2] 安装 debian-archive-keyring 2025.1 ==="
dpkg -i /tmp/keyring.deb 2>&1 | tail -5

echo
echo "=== [3] 验证 bookworm 密钥已就位 ==="
ls -1 /etc/apt/trusted.gpg.d/ | grep -i bookworm
echo "  --- 密钥指纹 ---"
gpg --show-keys /etc/apt/trusted.gpg.d/debian-archive-bookworm-stable.asc 2>/dev/null | head -5

echo
echo "=== [4] 切换 apt 源到 bookworm ==="
cat > /etc/apt/sources.list <<'EOF'
deb http://mirrors.163.com/debian/ bookworm main contrib non-free non-free-firmware
deb http://mirrors.163.com/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://mirrors.163.com/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF
echo "  写入 sources.list:"
cat /etc/apt/sources.list

echo
echo "=== [5] 处理 mobian 源（bookworm 版可能不存在）==="
if [ -f /etc/apt/sources.list.d/mobian.list ]; then
    mv /etc/apt/sources.list.d/mobian.list /root/upgrade-backup/mobian.list.disabled
    echo "  mobian.list 已禁用（备份至 /root/upgrade-backup/）"
fi

echo
echo "=== [6] apt update 测试 ==="
apt-get update 2>&1 | tail -12
