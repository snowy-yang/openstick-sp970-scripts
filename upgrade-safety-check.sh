#!/bin/bash
# 升级前关键检查：确认 autoremove 不会误删 USB gadget 依赖
set -u
echo "=== [1] dist-upgrade 规模 ==="
apt-get -s dist-upgrade 2>/dev/null | grep -E "^[0-9]+ upgraded"

echo
echo "=== [2] 升级过程中将被移除的包 ==="
apt-get -s dist-upgrade 2>/dev/null | sed -n '/packages will be REMOVED/,/^$/p' | head -10

echo
echo "=== [3] 升级后被 autoremove 的候选（这是上次出事的地方）==="
apt-get -s dist-upgrade 2>/dev/null | grep -A5 "automatically installed and are no longer required" | head -10

echo
echo "=== [4] 检查关键库 libgudev / libqrtr 是否被依赖 ==="
for lib in libgudev-1.0-0 libqrtr1 libmbim-glib4 libqmi-glib5; do
    echo "--- $lib ---"
    rdep=$(apt-cache rdepends --installed "$lib" 2>/dev/null | tail -n +3 | tr -d ' ' | grep -v '^|' | grep -v '^$' | tr '\n' ' ')
    printf "  被依赖: %s\n" "${rdep:-（无）}"
done

echo
echo "=== [5] USB gadget 相关包状态 ==="
for p in libusbgx libusbgx2 libconfig9 libqrtr-glib0 udisks2 libblockdev; do
    s=$(dpkg-query -W -f='${Status}' "$p" 2>/dev/null || echo "not-installed")
    printf "  %-18s %s\n" "$p" "$s"
done

echo
echo "=== [6] 谁依赖 libgudev（关键）==="
apt-cache rdepends --installed libgudev-1.0-0 2>/dev/null | head -12
