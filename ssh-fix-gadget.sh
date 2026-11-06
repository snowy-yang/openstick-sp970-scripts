#!/bin/bash
# 通过 SSH 修复 USB gadget（设备当前 gadget 已被 reset 移除）
set -u

echo "=== [1] 当前 gadget 状态 ==="
ls /sys/kernel/config/usb_gadget/ 2>/dev/null || echo "(空 - gadget 已被移除)"
echo "  adbd 进程: $(pgrep -c adbd 2>/dev/null || echo 0)"

echo
echo "=== [2] 重新执行 setup ==="
# setup 会调用 gc -a rndis / gc -a ffs / mount functionfs / adbd / gc -e
/usr/sbin/mobian-usb-gadget setup
echo "  setup 返回: $?"

echo
echo "=== [3] 结果 ==="
sleep 3
echo "  gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null || echo '(空)')"
echo "  UDC: $(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null || echo '(无)')"
ip -br addr show usb0 2>/dev/null || echo "  usb0 未出现"
