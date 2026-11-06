#!/bin/bash
# 查清 USB gadget 配置机制
echo "=== [1] 当前 gadget 状态 ==="
ls /sys/kernel/config/usb_gadget/ 2>/dev/null
echo "--- udc ---"
ls /sys/class/udc/ 2>/dev/null

echo
echo "=== [2] 谁在配置 gadget（systemd 服务）==="
systemctl list-units --all 2>/dev/null | grep -iE "usb|gadget|serial|rndis|network-usb" | head -10

echo
echo "=== [3] gadget 相关脚本/服务文件 ==="
ls /etc/systemd/system/ | grep -iE "usb|gadget" 
grep -rl "usb_gadget\|g1\|rndis" /etc/systemd/system/ /lib/systemd/system/ 2>/dev/null | head -8

echo
echo "=== [4] init 脚本方式 ==="
ls /etc/init.d/ 2>/dev/null | head -20

echo
echo "=== [5] gadget 配置文件 ==="
ls -la /etc/usb-gadget* /opt/usb* /usr/local/bin/*usb* 2>/dev/null | head

echo
echo "=== [6] 当前 g1 配置内容 ==="
for d in /sys/kernel/config/usb_gadget/g1; do
    [ -d "$d" ] || continue
    echo "  idVendor: $(cat $d/idVendor 2>/dev/null)"
    echo "  idProduct: $(cat $d/idProduct 2>/dev/null)"
    echo "  UDC: $(cat $d/UDC 2>/dev/null)"
    echo "  configs: $(ls $d/configs 2>/dev/null | tr '\n' ' ')"
    echo "  functions: $(ls $d/functions 2>/dev/null | tr '\n' ' ')"
done

echo
echo "=== [7] 是否有 usb-gadget 的 dpkg 包 ==="
dpkg -l | grep -iE "usb-gadget|gadget|configfs" | head -5
