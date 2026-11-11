#!/bin/bash
# 升级前详细检查：将被移除的包、内核相关包、下载体积
set -u
echo "=== 将被移除的包 ==="
apt-get -s dist-upgrade 2>/dev/null | grep -iE "^Remv|will be REMOVED" | head -10

echo
echo "=== 内核相关包是否会变动 ==="
apt-get -s dist-upgrade 2>/dev/null | grep -iE "linux-image|linux-headers" | head -10 || echo "  (无内核包变动)"

echo
echo "=== 下载体积 ==="
apt-get -s dist-upgrade 2>/dev/null | grep -E "Need to get|After this operation"

echo
echo "=== 系统分区剩余 ==="
df -h / | tail -1

echo
echo "=== zram 是否启用（缓解内存压力）==="
systemctl is-active zramswap 2>/dev/null || echo "  zramswap 未启用"
free -m | head -2

echo
echo "=== 关键包当前版本 ==="
for p in systemd libc6 network-manager wpasupplicant openssh-server iproute2; do
    v=$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null || echo "(未安装)")
    printf "  %-18s %s\n" "$p" "$v"
done
