#!/bin/bash
# 升级前加固：确保 gadget 不会在升级/重启中丢失
set -u
echo "=== [1] 当前 gadget 依赖工具 ==="
ls -l /usr/bin/gc /usr/bin/adbd /usr/sbin/mobian-usb-gadget 2>/dev/null

echo
echo "=== [2] 确认 mobian-tweaks-common 不会被升级移除 ==="
apt-get -s dist-upgrade 2>/dev/null | grep -iE "mobian" || echo "  (mobian 包不在升级列表)"

echo
echo "=== [3] 备份关键文件 ==="
mkdir -p /root/usb-backup
cp -a /usr/sbin/mobian-usb-gadget /root/usb-backup/ 2>/dev/null && echo "  ✅ mobian-usb-gadget"
cp -a /usr/bin/gc /root/usb-backup/ 2>/dev/null && echo "  ✅ gc"
cp -a /usr/bin/adbd /root/usb-backup/ 2>/dev/null && echo "  ✅ adbd"
cp -a /lib/systemd/system/mobian-usb-gadget.service /root/usb-backup/ 2>/dev/null && echo "  ✅ service"

echo
echo "=== [4] 检查 mobian-usb-gadget.service 是否 enabled ==="
systemctl is-enabled mobian-usb-gadget.service

echo
echo "=== [5] 升级清单中是否有会动到这些文件的行 ==="
apt-get -s dist-upgrade 2>/dev/null | grep -iE "^(Inst|Conf).*(mobian-tweaks|base-files)" | head -5
