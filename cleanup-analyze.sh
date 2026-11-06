#!/bin/bash
# 安全清理：先分析，不直接删
set -u
echo "=== [1] autoremove 候选（只列出）==="
apt-get -s autoremove 2>/dev/null | sed -n '/REMOVED/,/^$/p' | head -15

echo
echo "=== [2] 逐个检查候选是否被关键组件依赖 ==="
CAND=$(apt-get -s autoremove 2>/dev/null | sed -n '/packages will be REMOVED/,/^$/p' | grep -E '^  ' | awk '{print $1}' | head -20)
if [ -z "$CAND" ]; then
    echo "  (无候选)"
else
    for p in $CAND; do
        rdep=$(apt-cache rdepends --installed "$p" 2>/dev/null | tail -n +3 | grep -v '^|' | tr -d ' ' | grep -v '^$' | grep -v "^$p$" | tr '\n' ' ')
        if [ -n "$rdep" ]; then
            printf "  ⚠ %-28s 被依赖: %s\n" "$p" "$rdep"
        else
            printf "  ✅ %-28s 无依赖\n" "$p"
        fi
    done
fi

echo
echo "=== [3] 特别确认 USB gadget 相关绝不删除 ==="
for p in libgudev-1.0-0 libglib2.0-0 libconfig9; do
    s=$(dpkg-query -W -f='${Status}' "$p" 2>/dev/null)
    echo "  $p: $s"
done
