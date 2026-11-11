#!/bin/bash
echo "=== wget 版本 ==="
wget --version 2>&1 | head -1

echo
echo "=== 直接测试 deb.debian.org ==="
wget -O /tmp/rel.txt --timeout=10 "http://deb.debian.org/debian/dists/bookworm/Release" 2>&1 | tail -6
echo "--- 文件大小 ---"
ls -l /tmp/rel.txt 2>/dev/null && head -3 /tmp/rel.txt

echo
echo "=== 测试 163 ==="
wget -O /tmp/rel2.txt --timeout=10 "http://mirrors.163.com/debian/dists/bookworm/Release" 2>&1 | tail -4
ls -l /tmp/rel2.txt 2>/dev/null | head -2

echo
echo "=== 检查是否 IPv6 优先导致失败 ==="
getent ahosts deb.debian.org | head -5
