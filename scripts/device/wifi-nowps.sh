#!/bin/bash
# 关闭 WPS，清理 PMKSA 缓存，重新连接
echo "=== 1) 关闭 WPS ==="
nmcli con modify WU 802-11-wireless-security.key-mgmt wpa-psk
nmcli con modify WU wifi-sec.wps-method 0
nmcli con modify WU 802-11-wireless.wps-method 0
echo "  已设置 wps-method=0"

echo
echo "=== 2) 重启 wpa_supplicant 清理状态 ==="
systemctl restart wpa_supplicant
sleep 3
systemctl is-active wpa_supplicant

echo
echo "=== 3) 关闭 NetworkManager 的 wifi 后重开（重置 state machine）==="
nmcli radio wifi off
sleep 3
nmcli radio wifi on
sleep 6
nmcli dev status | grep wlan0

echo
echo "=== 4) 首次连接（用 wifi connect，会创建新 profile）==="
nmcli dev wifi connect "WiFi-Ultra" password "${WIFI_PSK}" 2>&1 | tail -4
sleep 12

echo
echo "=== 结果 ==="
ip -br addr show wlan0
nmcli dev status | grep wlan0
