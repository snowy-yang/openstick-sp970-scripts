#!/bin/bash
# 用 nmcli 写文件方式配置 WiFi，避免 shell 引号问题
SSID="WiFi-Ultra"
PSK="${WIFI_PSK:?set WIFI_PSK env var first}"

# 删除旧配置
nmcli connection delete WU 2>/dev/null

# 用 nmcli 交互式输入密码
nmcli connection add type wifi con-name WU ifname wlan0 ssid "$SSID" \
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK" 2>&1 | tail -2

echo "--- 检查配置 ---"
nmcli -s -g 802-11-wireless-security.psk connection show WU 2>/dev/null | sed 's/./*/g'

echo "--- 激活 ---"
nmcli connection up WU 2>&1 | tail -3
