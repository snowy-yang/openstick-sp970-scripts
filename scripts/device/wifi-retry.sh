#!/bin/bash
echo "=== 当前 SSID 是否存在（信号强度）==="
nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | grep -i "WiFi-Ultra"

echo
echo "=== 尝试重新扫描并连接 ==="
nmcli dev wifi rescan 2>/dev/null
sleep 5

echo
echo "=== 再次激活 ==="
nmcli con up WU 2>&1 | tail -4
sleep 10

echo
echo "=== 结果 ==="
ip -br addr show wlan0
nmcli device status | grep wlan0

echo
echo "=== 关联失败原因（networkmanager 日志）==="
journalctl -u NetworkManager --no-pager -n 40 2>/dev/null | grep -iE "associat|disconnect|reason|4-way|handshake|deauth|WU" | tail -10

echo
echo "=== wpa_supplicant 日志 ==="
journalctl -u wpa_supplicant --no-pager -n 20 2>/dev/null | tail -10
