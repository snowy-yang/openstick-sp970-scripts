#!/bin/bash
# 升级后检查
set -u
echo "=== 版本 ==="
cat /etc/os-release | head -4
echo "  debian_version: $(cat /etc/debian_version)"
echo "  内核: $(uname -r)"

echo
echo "=== dpkg 一致性 ==="
dpkg --audit 2>&1 | head -10 || echo "  ✅ 无异常"
echo "  --- 半配置包 ---"
dpkg -l | grep -E '^i[^i]' | head -10 || echo "  ✅ 无"

echo
echo "=== apt 状态 ==="
apt-get -s -f install 2>&1 | tail -3

echo
echo "=== 关键服务 ==="
for s in ssh NetworkManager wpa_supplicant systemd-networkd; do
    printf "  %-20s %s\n" "$s" "$(systemctl is-active $s 2>/dev/null)"
done

echo
echo "=== 网络 ==="
ip -br addr show usb0 2>/dev/null
ip -br addr show wlan0 2>/dev/null
ip route show default 2>/dev/null

echo
echo "=== 内存/磁盘 ==="
free -m | head -2
df -h / | tail -1

echo
echo "=== 失败单元 ==="
systemctl --failed --no-pager 2>/dev/null | head -10
