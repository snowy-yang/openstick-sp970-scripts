#!/bin/bash
# 使用稳定 MAC 地址策略重连 WiFi
SSID="WiFi-Ultra"
PSK="${WIFI_PSK:?set WIFI_PSK env var first}"

echo "=== 当前 wlan0 MAC ==="
ip link show wlan0 | grep -oE 'link/ether [0-9a-f:]+'

echo
echo "=== 重建 profile，指定 stable MAC ==="
nmcli con delete WU 2>/dev/null
nmcli con delete "$SSID" 2>/dev/null

nmcli con add type wifi con-name WU ifname wlan0 ssid "$SSID"

nmcli con modify WU \
  802-11-wireless.mac-address-randomization 1 \
  802-11-wireless.cloned-mac-address stable \
  802-11-wireless-security.key-mgmt wpa-psk \
  802-11-wireless-security.psk "$PSK" \
  802-11-wireless-security.psk-flags 0

echo
echo "=== 激活 ==="
nmcli con up WU 2>&1 | tail -3
sleep 15

echo
echo "=== 结果 ==="
ip -br addr show wlan0
nmcli dev status | grep wlan0

echo
echo "=== wpa 日志 ==="
journalctl -u wpa_supplicant --no-pager -n 12 2>/dev/null | tail -8
