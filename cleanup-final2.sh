#!/bin/bash
# 第二轮清理：文档/locale/缓存 + 确认 libusbgx 完好
set -u
export DEBIAN_FRONTEND=noninteractive

echo "=== [0] 确认 libusbgx 状态（gadget 核心库）==="
ls -l /lib/libusbgx* 2>/dev/null
echo "  归属: $(dpkg -S /lib/libusbgx.so.2 2>/dev/null || echo '未纳入包管理（手动放置）')"
echo "  gc 链接: $(ldd /usr/bin/gc 2>/dev/null | grep usbgx)"

echo
echo "=== [1] 清理 apt 缓存与索引 ==="
apt-get clean 2>/dev/null
rm -rf /var/lib/apt/lists/* 2>/dev/null
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null
echo "  完成"

echo
echo "=== [2] 清理文档 ==="
du -sh /usr/share/doc /usr/share/man 2>/dev/null
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null
echo "  完成"

echo
echo "=== [3] 清理 locale（保留 en/zh）==="
before=$(du -sm /usr/share/locale 2>/dev/null | cut -f1)
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d ! -name 'en*' ! -name 'zh*' -exec rm -rf {} + 2>/dev/null
after=$(du -sm /usr/share/locale 2>/dev/null | cut -f1)
echo "  ${before}MB -> ${after}MB"

echo
echo "=== [4] 清理日志 ==="
find /var/log -type f \( -name '*.gz' -o -name '*.1' -o -name '*.old' \) -delete 2>/dev/null
journalctl --vacuum-size=5M 2>/dev/null | tail -2
rm -rf /tmp/* /root/.cache/* 2>/dev/null
echo "  完成"

echo
echo "=== [5] 移除 rc 状态包 ==="
RC=$(dpkg -l 2>/dev/null | awk '$1=="rc"{print $2}')
[ -n "$RC" ] && dpkg --purge $RC 2>/dev/null && echo "  已清理: $RC" || echo "  无"

echo
echo "=== [6] 清理升级残留 ==="
rm -rf /var/backups/*.dpkg-old /var/backups/*.dpkg-dist 2>/dev/null
rm -f /root/upgrade.log /root/cleanup*.log /root/u.out /root/cs2.out 2>/dev/null
echo "  完成"

echo
echo "=== [7] 最终验证 gadget ==="
echo "  UDC=$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null || echo '空')"
echo "  adbd=$(pgrep -c adbd 2>/dev/null || echo 0)"
ip -br addr show usb0 2>/dev/null

echo
echo "=== [8] 磁盘 ==="
df -h / | tail -1
