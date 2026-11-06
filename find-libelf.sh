#!/bin/bash
# 查找 libelf1 的可用 arm64 包
echo "=== elfutils 目录 ==="
curl -sL "http://ftp.debian.org/debian/pool/main/e/elfutils/" \
  | grep -oE 'libelf1_[^"<>]*_arm64\.deb' | sort -u | tail -8

echo
echo "=== 尝试 bookworm/bullseye 索引 ==="
curl -sL "http://ftp.debian.org/debian/dists/bullseye/main/binary-arm64/Packages.gz" 2>/dev/null \
  | gunzip -c 2>/dev/null | grep -A3 -m1 "^Package: libelf1$" | head -6
