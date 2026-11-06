#!/bin/bash
F=/etc/NetworkManager/system-connections/WU.nmconnection
echo "=== 文件权限（必须 600 root）==="
ls -l "$F"

echo
echo "=== 文件内容（psk 部分打码）==="
sed 's/\(psk=\).*/\1***/' "$F"

echo
echo "=== 修复权限 ==="
chmod 600 "$F"
chown root:root "$F"
ls -l "$F"

echo
echo "=== 重新加载配置 ==="
nmcli connection reload 2>&1
sleep 1

echo
echo "=== 再次激活 ==="
nmcli con up WU 2>&1 | tail -4

echo
echo "=== 结果 ==="
ip -br addr show wlan0
