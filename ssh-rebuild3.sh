#!/bin/bash
# 方案：先把脚本写到设备，再用 sudo 执行
TARGET=user@192.168.1.48
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

# 1) 确认 sudo 是否需要密码
echo "=== sudo 权限检查 ==="
sshpass -p 1 ssh $SSHOPTS "$TARGET" "echo 1 | sudo -S -k true 2>&1 && echo SUDO_OK || echo SUDO_FAIL"

# 2) 生成远程脚本内容
cat > /tmp/rb.sh <<'EOS'
#!/bin/bash
echo "--- 重建前 ---"
ls /sys/kernel/config/usb_gadget/ 2>/dev/null || echo "(空)"
/usr/sbin/mobian-usb-gadget setup
echo "setup_rc=$?"
sleep 4
echo "--- 重建后 ---"
echo "gadget: $(ls /sys/kernel/config/usb_gadget/ 2>/dev/null)"
echo "UDC: $(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)"
ip -br addr show usb0 2>/dev/null || echo "NO_USB0"
EOS

# 3) 用 base64 传脚本，规避 stdin 冲突
B64=$(base64 -w0 /tmp/rb.sh)
echo
echo "=== 执行 ==="
sshpass -p 1 ssh $SSHOPTS "$TARGET" "echo '$B64' | base64 -d > /tmp/rb.sh && chmod +x /tmp/rb.sh && echo 1 | sudo -S /tmp/rb.sh 2>&1 | grep -v '^\[sudo\]'"
