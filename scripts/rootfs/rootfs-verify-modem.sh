#!/bin/bash
# rootfs 最终清理与校验
set -uo pipefail
MNT=/mnt/rootfs_rw

mountpoint -q "$MNT" || { echo "not mounted"; exit 1; }

echo "=== 清除残留目录 ==="
rm -rf "$MNT/etc/systemd/system/ModemManager" 2>/dev/null
echo "  removed /etc/systemd/system/ModemManager"

echo
echo "=== 检查 modules-load / modprobe 配置 ==="
grep -rn "bam_dmux\|rpmsg_wwan\|rmnet\|q6v5" "$MNT"/etc/modules-load.d/ "$MNT"/etc/modprobe.d/ 2>/dev/null || echo "  (无自动加载配置)"

echo
echo "=== 检查 /etc/modules ==="
grep -n "bam\|wwan\|rmnet" "$MNT/etc/modules" 2>/dev/null || echo "  (/etc/modules 无相关内容)"

echo
echo "=== 检查 NetworkManager cellular 插件 ==="
ls "$MNT/usr/lib/NetworkManager/"*modem* 2>/dev/null || echo "  (无 modem 插件)"

echo
echo "=== 全盘扫描 modem 关键字（文件名）==="
find "$MNT" -xdev \( -iname "*modem*" -o -iname "*qmi*" -o -iname "*mbim*" \) 2>/dev/null | grep -v "^$MNT/proc" | head -20 || echo "  (无匹配)"

echo
echo "=== /lib/firmware 最终内容 ==="
ls "$MNT/lib/firmware/"

echo
echo "=== rootfs 内 modem 内核模块最终状态 ==="
find "$MNT/lib/modules" -name "*.ko" 2>/dev/null | grep -iE "bam_dmux|rpmsg_wwan|rmnet" || echo "  (已全部移除)"

echo
echo "=== apt 数据库中的相关包 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -iE "modemmanager|libqmi|libmbim" || echo "  (无)"
