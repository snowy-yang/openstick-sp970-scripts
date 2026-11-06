#!/bin/bash
# 二次瘦身：/boot 与 package 数据库缓存
set -uo pipefail
MNT=/mnt/rootfs_slim
mountpoint -q "$MNT" || { echo "not mounted"; exit 1; }

BEFORE=$(du -sm --exclude=proc --exclude=sys "$MNT" | cut -f1)

echo "=== 当前 /boot ==="
ls -lh "$MNT/boot/"

# 引导由 lk2nd + boot 分区提供，rootfs 内 /boot 不参与启动
# 但保留 config 与 System.map 便于调试
echo
echo "=== 删除 vmlinuz / initrd.img (启动不依赖，走 boot 分区) ==="
rm -f "$MNT"/boot/vmlinuz-* "$MNT"/boot/initrd.img-* 2>/dev/null
ls -lh "$MNT/boot/"

echo
echo "=== 清理 dpkg 旧文件备份 ==="
rm -rf "$MNT"/var/backups/*.dpkg-old "$MNT"/var/backups/*.dpkg-dist 2>/dev/null

echo
echo "=== 检查是否有重复的 kernel 模块目录 ==="
ls -1 "$MNT/lib/modules/" 2>/dev/null | sed 's/^/  /'

AFTER=$(du -sm --exclude=proc --exclude=sys "$MNT" | cut -f1)
echo
echo "结果: ${BEFORE} MB -> ${AFTER} MB"
sync
