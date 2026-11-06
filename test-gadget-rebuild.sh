#!/bin/bash
# 测试 gadget 重建流程（不重启，直接 stop/start 验证）
echo "=== 当前状态 ==="
ls /sys/kernel/config/usb_gadget/ 2>/dev/null
cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null
ip -br addr show usb0 2>/dev/null

echo
echo "=== 模拟重建：先 reset 再 setup ==="
/usr/sbin/mobian-usb-gadget reset 2>&1 | head -3
sleep 2
echo "  reset 后 gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null || echo '(空)')"

/usr/sbin/mobian-usb-gadget setup 2>&1 | head -5
sleep 3

echo
echo "=== 重建结果 ==="
echo "  gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null)"
echo "  UDC: $(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)"
ip -br addr show usb0 2>/dev/null || echo "  usb0 未出现"
