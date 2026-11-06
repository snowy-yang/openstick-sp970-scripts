#!/bin/bash
# 通过 SSH 重建 USB gadget
SSH="sshpass -p 1 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
TARGET=user@192.168.1.48

cat > /tmp/rebuild.sh <<'EOS'
#!/bin/bash
ls /sys/kernel/config/usb_gadget/ 2>/dev/null || echo "(gadget 已空)"
/usr/sbin/mobian-usb-gadget setup
echo "setup_rc=$?"
sleep 4
echo "gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null)"
echo "UDC: $(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)"
ip -br addr show usb0 2>/dev/null || echo "NO_USB0"
EOS

$SSH "$TARGET" "sudo -S bash -s" < /tmp/rebuild.sh <<'PW'
1
PW
