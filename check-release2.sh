#!/bin/bash
# 直接查看 apt 缓存中的 InRelease 文件日期
mkdir -p /tmp/l1/partial
apt-get -o Dir::State::lists=/tmp/l1 -o Dir::Cache=/tmp/c1 update 2>&1 | tail -3

echo
echo "=== 缓存的 InRelease 文件 ==="
ls -la /tmp/l1/ 2>/dev/null | head

echo
echo "=== bullseye InRelease 的 Date/Valid-Until ==="
for f in /tmp/l1/*InRelease; do
    [ -f "$f" ] || continue
    echo "--- $f ---"
    grep -E "^(Date|Valid-Until):" "$f" 2>/dev/null
done

echo
echo "=== 系统当前时间 ==="
date -u
