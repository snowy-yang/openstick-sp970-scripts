#!/bin/bash
# 修正：postinst 文件实际名为 info/<pkg>.postinst（不带架构后缀）
set -uo pipefail
MNT=/mnt/rootfs_edit
mountpoint -q "$MNT" || mount -o loop,rw /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

echo "=== 查找真实的 postinst 文件 ==="
ls -1 "$MNT/var/lib/dpkg/info/" | grep -E "^(iproute2|libc-bin)" | grep postinst | sed 's/^/  /'

for f in iproute2.postinst libc-bin.postinst; do
    p="$MNT/var/lib/dpkg/info/$f"
    if [ -f "$p" ]; then
        cp "$p" "/tmp/$f.bak"
        printf '#!/bin/sh\nexit 0\n' > "$p"
        chmod 755 "$p"
        echo "  已中性化 $f (备份 /tmp/$f.bak)"
    fi
done

echo
echo "=== 重新 configure ==="
dpkg --root="$MNT" --force-architecture --force-depends --force-overwrite --configure -a 2>&1 \
    | grep -vE '^\(正在读取数据库' | tail -8 | sed 's/^/  /'

echo
echo "=== 状态 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -E "iproute2|libbpf0|libelf1|libc-bin|rmtfs" | awk '{printf "  %-4s %-26s %-12s\n", $1, $2, $3}'

echo
echo "=== --audit ==="
OUT=$(dpkg --root="$MNT" --audit 2>&1)
if [ -z "$OUT" ]; then echo "  ✅ 无异常"; else echo "$OUT" | head -8 | sed 's/^/  /'; fi
