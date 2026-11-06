#!/bin/bash
# 验证 iproute2 与 rmtfs 移除结果
set -uo pipefail
MNT=/mnt/rootfs_edit
export QEMU_LD_PREFIX="$MNT"
mountpoint -q "$MNT" || mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

echo "=== [1] ip 命令可用性 ==="
"$MNT/bin/ip" -V
echo "  --- ip addr 帮助 ---"
"$MNT/bin/ip" addr help 2>&1 | head -5

echo
echo "=== [2] ip/tc/ss 文件 ==="
for f in bin/ip sbin/ip sbin/tc bin/ss sbin/bridge; do
    if [ -e "$MNT/$f" ]; then
        printf "  ✅ %-12s %s\n" "$f" "$([ -L "$MNT/$f" ] && echo "-> $(readlink "$MNT/$f")" || stat -c%s "$MNT/$f")"
    else
        printf "  ❌ %-12s 缺失\n" "$f"
    fi
done

echo
echo "=== [3] rmtfs 彻底移除确认 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -i rmtfs && echo "  ❌ 仍在" || echo "  ✅ 包已移除"
[ -e "$MNT/usr/bin/rmtfs" ] && echo "  ❌ 二进制残留" || echo "  ✅ 二进制已删除"
[ -e "$MNT/lib/systemd/system/rmtfs.service" ] && echo "  ❌ 服务残留" || echo "  ✅ 服务已删除"
echo "  --- 残留引用 ---"
grep -rl "rmtfs" "$MNT/etc/systemd/system" 2>/dev/null | head || echo "  ✅ systemd 无引用"

echo
echo "=== [4] iproute2 版本信息 ==="
dpkg --root="$MNT" -s iproute2 2>/dev/null | grep -E "^Package|^Version|^Architecture|^Status"

echo
echo "=== [5] 体积 ==="
du -sm --exclude=proc --exclude=sys "$MNT" | awk '{print "  "$1" MB"}'
