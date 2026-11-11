#!/bin/bash
# 在设备上测试各个 Debian 镜像源可用性
for u in \
  "http://mirrors.163.com/debian/dists/bullseye/Release" \
  "http://mirrors.163.com/debian/dists/bookworm/Release" \
  "http://deb.debian.org/debian/dists/bullseye/Release" \
  "http://deb.debian.org/debian/dists/bookworm/Release" \
  "http://mirrors.tuna.tsinghua.edu.cn/debian/dists/bookworm/Release" \
  "http://mirrors.aliyun.com/debian/dists/bookworm/Release" \
  "http://mirrors.ustc.edu.cn/debian/dists/bookworm/Release" ; do
    out=$(wget -q -O /dev/null --timeout=8 --tries=1 -S "$u" 2>&1 | head -1)
    code=$(echo "$out" | grep -oE '[0-9]{3}' | head -1)
    printf "%-62s %s\n" "$u" "${code:-FAIL}"
done
