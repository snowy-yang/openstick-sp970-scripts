#!/bin/bash
# 在 QEMU 支持下正确完成 iproute2 / libc-bin 的 postinst 配置
set -uo pipefail
MNT=/mnt/rootfs_edit
export QEMU_LD_PREFIX="$MNT"

mountpoint -q "$MNT" || mount -o loop,rw /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

echo "=== [1] 恢复原始 postinst ==="
for f in iproute2.postinst libc-bin.postinst; do
    if [ -f "/tmp/$f.bak" ]; then
        cp "/tmp/$f.bak" "$MNT/var/lib/dpkg/info/$f"
        chmod 755 "$MNT/var/lib/dpkg/info/$f"
        echo "  恢复 $f"
    fi
done

echo
echo "=== [2] 验证 postinst 可在 QEMU 下执行 ==="
"$MNT/bin/true" && echo "  ✅ arm64 可执行"

echo
echo "=== [3] 完成 configure ==="
dpkg --root="$MNT" --force-architecture --force-depends --force-overwrite --configure -a 2>&1 \
    | grep -vE '^\(正在读取数据库' | tail -10 | sed 's/^/  /'

echo
echo "=== [4] 状态 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -E "iproute2|libbpf0|libelf1|libc-bin" | awk '{printf "  %-4s %-26s %-12s\n", $1, $2, $3}'

echo
echo "=== [5] audit ==="
OUT=$(dpkg --root="$MNT" --audit 2>&1)
if [ -z "$OUT" ]; then echo "  ✅ 无异常"; else echo "$OUT" | head -6 | sed 's/^/  /'; fi
