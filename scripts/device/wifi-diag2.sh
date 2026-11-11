#!/bin/bash
echo "=== wpa_supplicant 状态 ==="
systemctl is-active wpa_supplicant
ps aux | grep '[w]pa_supplicant' | head -2

echo
echo "=== NetworkManager 详细日志（最近 30 行）==="
journalctl -u NetworkManager --no-pager -n 30 2>/dev/null | grep -iE "wlan0|secret|psk|supplicant|WU" | tail -15

echo
echo "=== 尝试显式提供密码激活 ==="
nmcli --ask con up WU <<< "${WIFI_PSK}" 2>&1 | tail -5

echo
echo "=== 结果 ==="
ip -br addr show wlan0
