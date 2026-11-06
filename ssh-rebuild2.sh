#!/bin/bash
# 通过 SSH 重建 USB gadget（修正 sudo 提权方式）
TARGET=user@192.168.1.48
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

# 远程脚本：重建 gadget
cat > /tmp/rebuild.sh <<'EOS'
echo "--- 重建前 ---"
ls /sys/kernel/config/usb_gadget/ 2>/dev/null || echo "(空)"
echo "--- 执行 setup ---"
/usr/sbin/mobian-usb-gadget setup
echo "setup_rc=$?"
sleep 4
echo "--- 重建后 ---"
echo "gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null)"
echo "UDC: $(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)"
ip -br addr show usb0 2>/dev/null || echo "NO_USB0"
EOS

sshpass -p 1 ssh $SSHOPTS "$TARGET" "echo 1 | sudo -S bash -s" < /tmp/rebuild.sh
