#!/bin/bash
echo "=== mobian-usb-gadget.service 内容 ==="
systemctl cat mobian-usb-gadget.service 2>/dev/null

echo
echo "=== 它调用的脚本 ==="
for f in /usr/bin/mobian-usb-gadget /usr/sbin/mobian-usb-gadget /usr/lib/mobian/usb-gadget.sh; do
    [ -e "$f" ] && { echo "--- $f ---"; head -40 "$f"; }
done

echo
echo "=== 属于哪个包 ==="
dpkg -S /lib/systemd/system/mobian-usb-gadget.service 2>/dev/null || \
dpkg -S /usr/lib/systemd/system/mobian-usb-gadget.service 2>/dev/null || echo "  (未找到归属)"

echo
echo "=== 服务当前状态 ==="
systemctl status mobian-usb-gadget.service --no-pager -l 2>&1 | head -12
