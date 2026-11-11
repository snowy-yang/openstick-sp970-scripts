#!/bin/bash
# 修复 arm64 包在 amd64 宿主上的 postinst 执行失败，令 dpkg 状态回到正常
set -uo pipefail
MNT=/mnt/rootfs_edit
mountpoint -q "$MNT" || mount -o loop,rw /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

echo "=== 当前状态 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -E "^(i|.).+(iproute2|libbpf0|libelf1|libc-bin)" | awk '{print "  "$1" "$2" "$3}'

echo
echo "=== 原因：postinst 是 arm64 脚本，宿主无法执行 ==="
echo "  处理方式：把 postinst 替换为 no-op 后重新 configure"
for p in libc-bin iproute2; do
    f="$MNT/var/lib/dpkg/info/$p:arm64.postinst"
    if [ -f "$f" ]; then
        cp "$f" "/tmp/$p.postinst.bak" 2>/dev/null || true
        printf '#!/bin/sh\nexit 0\n' > "$f"
        chmod 755 "$f"
        echo "  已中性化 $p:arm64.postinst"
    else
        echo "  (无 $p:arm64.postinst)"
    fi
done

echo
echo "=== 重新 configure ==="
dpkg --root="$MNT" --force-architecture --force-depends --force-overwrite --configure -a 2>&1 \
    | grep -vE '^\(正在读取数据库' | tail -8 | sed 's/^/  /'

echo
echo "=== 最终 dpkg 状态 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -E "iproute2|libbpf0|libelf1|libc-bin|rmtfs" | awk '{printf "  %-4s %-26s %-12s\n", $1, $2, $3}'

echo
echo "=== 是否有未配置/半配置包 ==="
BAD=$(dpkg --root="$MNT" -l 2>/dev/null | grep -cE '^[^ ]{2}([^i ]|i[^ ])' || true)
dpkg --root="$MNT" --audit 2>/dev/null | head -10 | sed 's/^/  /' || echo "  (audit 无输出)"
