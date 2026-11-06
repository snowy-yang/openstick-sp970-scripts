#!/bin/bash
# 升级前评估：查看将要变更的规模
set -u
echo "=== 当前系统 ==="
cat /etc/debian_version
uname -r

echo
echo "=== 内存/存储 ==="
free -m | head -2
df -h / | tail -1

echo
echo "=== 模拟升级（仅统计，不安装）==="
apt-get -s dist-upgrade 2>&1 | tail -25
