#!/bin/bash
# 重启后完整验证
set -u
echo "=== 系统版本 ==="
cat /etc/os-release | grep PRETTY
echo "  debian_version: $(cat /etc/debian_version)"
echo "  内核: $(uname -r)"
echo "  启动时间: $(uptime -p 2>/dev/null || uptime)"

echo
echo "=== systemd 版本（应为 252）==="
systemctl --version | head -1
echo "  libc: $(dpkg-query -W -f='${Version}' libc6)"

echo
echo "=== dpkg 一致性 ==="
out=$(dpkg --audit 2>&1)
[ -z "$out" ] && echo "  ✅ 无异常" || echo "$out" | head -8
echo "  --- 半配置包 ---"
dpkg -l | awk '$1 ~ /^i[^i]/ {print "  "$1" "$2}' | head -8 || echo "  ✅ 无"

echo
echo "=== 失败单元 ==="
systemctl --failed --no-pager 2>/dev/null | head -8

echo
echo "=== 网络 ==="
ip -br addr show usb0 2>/dev/null
ip -br addr show wlan0 2>/dev/null
echo "  --- 路由 ---"
ip route show default 2>/dev/null || echo "  (无默认路由)"

echo
echo "=== WiFi 状态 ==="
nmcli device status 2>/dev/null | head -5
echo "  --- 已扫描 AP 数 ---"
nmcli -t -f SSID dev wifi list 2>/dev/null | wc -l

echo
echo "=== SSH ==="
ss -tln 2>/dev/null | grep :22 || echo "  22 未监听"

echo
echo "=== 资源 ==="
free -m | head -2
df -h / | tail -1
