#!/bin/bash
set -u
echo "=== 清理 apt 缓存 ==="
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/l1 /tmp/c1

echo
echo "=== 禁用 repo.mobian-project.org（404 已废弃）==="
if [ -f /etc/apt/sources.list.d/mobian.list ]; then
    mv /etc/apt/sources.list.d/mobian.list /root/mobian.list.disabled
    echo "  已禁用并备份到 /root/"
fi

echo
echo "=== 当前源 ==="
cat /etc/apt/sources.list
echo "--- sources.list.d ---"
ls /etc/apt/sources.list.d/ 2>/dev/null || echo "(空)"

echo
echo "=== apt update ==="
apt-get update 2>&1 | tail -8
