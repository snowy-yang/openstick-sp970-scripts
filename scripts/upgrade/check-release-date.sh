#!/bin/bash
echo "=== 下载 Release 文件看日期 ==="
apt-get -o Dir::State::lists=/tmp/l1 update 2>&1 | tail -3
echo
echo "=== 163 镜像的 Release 头部 ==="
head -12 /tmp/l1/partial/*_InRelease 2>/dev/null | head -15
echo
echo "=== 文件实际内容（第一行）==="
sed -n '1,12p' /tmp/l1/partial/mirrors.163.com_debian_dists_bullseye_InRelease 2>/dev/null
echo
echo "=== 系统时间戳 ==="
date -u +%s
echo "  即 $(date -u)"
