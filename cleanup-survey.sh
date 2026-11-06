#!/bin/bash
# 清理无用包与配置（升级后）
set -u
export DEBIAN_FRONTEND=noninteractive

echo "=== [1] 升级前的自动清理候选 ==="
apt-get -s autoremove 2>/dev/null | grep -E "^Remv" | head -30

echo
echo "=== [2] 手动指定的无用包（modem 残留 + 未用的开发/文档包）==="
CANDIDATES="libqmi-glib5 libqmi-proxy libqmi-utils libmbim-glib4 libmbim-proxy libmbim-utils \
libqrtr-glib0 libmm-glib0 modemmanager \
linux-headers-5.15.0-handsomekernel+ \
python3 python3.9 python3-minimal \
man-db manpages info \
vim-tiny vim-common \
btrfs-progs ntfs-3g exfat-fuse f2fs-tools \
wpasupplicant-doc"
for p in $CANDIDATES; do
    if dpkg -l "$p" 2>/dev/null | grep -q '^ii'; then
        sz=$(dpkg-query -W -f='${Installed-Size}' "$p" 2>/dev/null || echo 0)
        printf "  %-42s %6s KB\n" "$p" "$sz"
    fi
done

echo
echo "=== [3] 当前磁盘 ==="
df -h / | tail -1
