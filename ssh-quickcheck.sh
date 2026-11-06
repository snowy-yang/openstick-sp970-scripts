#!/bin/bash
# 快速检查设备当前状态（超时保护）
TARGET=user@192.168.1.48
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o LogLevel=ERROR"

echo "=== SSH 可达性 ==="
timeout 15 sshpass -p ${DEVICE_PASS:?set DEVICE_PASS} ssh $SSHOPTS "$TARGET" "echo ALIVE; uptime -p" 2>&1 || echo "SSH 不通"

echo
echo "=== gadget 状态（只读，不做修改）==="
timeout 20 sshpass -p ${DEVICE_PASS:?set DEVICE_PASS} ssh $SSHOPTS "$TARGET" \
  "ls /sys/kernel/config/usb_gadget/ 2>/dev/null; echo UDC=\$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null); ip -br addr show usb0 2>/dev/null" 2>&1 || echo "查询失败"
