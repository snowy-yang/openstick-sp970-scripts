#!/bin/bash
# 通过 ADB 从设备导出 rootfs 并打包成可刷镜像
set -uo pipefail
OUT=/mnt/d/msm8916/out
TMP=/opt/msm8916/dump

echo "=== 检查 ADB 可用性 ==="
command -v adb >/dev/null 2>&1 || {
    echo "WSL 无 adb，使用 Windows 侧 adb 路径"
    ADB="/mnt/c/Users/Administrator/Desktop/sp970-debian超频版/adb.exe"
}
echo "  ADB=[$ADB]"

mkdir -p "$TMP"
echo
echo "=== 当前分区信息 ==="
$ADB shell "cat /proc/partitions | grep -E 'mmcblk0p1[0-9]'"
$ADB shell "df -h / | tail -1"

echo
echo "=== 说明 ==="
echo "  rootfs 在 /dev/mmcblk0p14，需要从设备 dump 整个分区"
echo "  arm64 设备上 dd 到 USB 网卡较慢（约 3.3GB），改用直接读分区"
