#!/bin/bash
# 修复 NetworkManager WiFi 密码存储问题并激活
SSID="WiFi-Ultra"
PSK="${WIFI_PSK:?set WIFI_PSK env var first}"

nmcli connection delete WU 2>/dev/null

# 关键：直接创建 profile 并把 psk 写入
nmcli con add type wifi con-name WU ifname wlan0 ssid "$SSID"

nmcli con modify WU \
    802-11-wireless-security.key-mgmt wpa-psk \
    802-11-wireless-security.psk "$PSK" \
    802-11-wireless-security.psk-flags 0 \
    802-11-wireless-security.auth-alg open \
    ipv4.method auto \
    ipv6.method auto

echo "--- 确认 psk 已写入 profile 文件 ---"
grep -c "psk=" /etc/NetworkManager/system-connections/WU.nmconnection 2>/dev/null

echo "--- 激活 ---"
nmcli con up WU 2>&1 | tail -4
