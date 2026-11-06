#!/bin/bash
# 清理残留 adbd 与 gadget 状态，然后重建
TARGET=user@192.168.1.48
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

cat > /tmp/rb.sh <<'EOS'
#!/bin/bash
echo "--- 清理残留 adbd ---"
pkill -9 adbd 2>/dev/null; sleep 1
echo "  剩余 adbd: $(pgrep -c adbd 2>/dev/null || echo 0)"

echo "--- 确认无进程占用 5037 / functionfs ---"
ss -tlnp 2>/dev/null | grep 5037 || echo "  5037 空闲"
umount /dev/usb-ffs/adb 2>/dev/null && echo "  umount functionfs" || echo "  functionfs 未挂载"

echo "--- 清空 gadget ---"
if [ -d /sys/kernel/config/usb_gadget/g1 ]; then
    gc -c 2>/dev/null
    sleep 1
fi
echo "  gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null || echo '(空)')"

echo "--- 重建 ---"
/usr/sbin/mobian-usb-gadget setup 2>&1
sleep 4

echo "--- 结果 ---"
echo "  gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null)"
echo "  UDC: $(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)"
echo "  adbd: $(pgrep -c adbd 2>/dev/null || echo 0)"
ip -br addr show usb0 2>/dev/null || echo "  NO_USB0"
EOS

B64=$(base64 -w0 /tmp/rb.sh)
sshpass -p 1 ssh $SSHOPTS "$TARGET" "echo '$B64' | base64 -d > /tmp/rb.sh && chmod +x /tmp/rb.sh && echo 1 | sudo -S /tmp/rb.sh 2>&1 | grep -v '^\[sudo\]'"
