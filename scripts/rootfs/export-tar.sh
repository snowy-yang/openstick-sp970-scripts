#!/bin/bash
# 从设备导出当前根文件系统为 tar（排除虚拟文件系统）
set -uo pipefail
ADB="C:/Users/Administrator/Desktop/sp970-debian超频版/adb.exe"

echo "=== 设备端打包（排除 proc/sys/dev/run/tmp）==="
$ADB shell "cd / && tar --numeric-owner -czf /tmp/rootfs.tar.gz \
    --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./run \
    --exclude=./tmp --exclude=./mnt --exclude=./media \
    --exclude=./var/log/*.gz --exclude=./lost+found \
    bin boot etc home lib opt root sbin srv usr var 2>/dev/null; echo rc=\$?; ls -lh /tmp/rootfs.tar.gz"
