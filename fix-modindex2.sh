#!/bin/bash
# 用 host depmod 重建 rootfs 内模块索引（清理已删 modem 模块的残留条目）
set -uo pipefail
MNT=/mnt/vf_dep
mkdir -p "$MNT"
mountpoint -q "$MNT" && umount "$MNT"
mount -o loop,rw /opt/msm8916/dl/debian/rootfs.raw "$MNT" || { echo MOUNT FAIL; exit 1; }

KV=5.15.0-handsomekernel+
KM="$MNT/lib/modules/$KV"

echo "=== 清理前条目数 ==="
printf "  modules.dep %s / order %s / alias %s\n" \
    "$(wc -l < "$KM/modules.dep")" "$(wc -l < "$KM/modules.order")" "$(wc -l < "$KM/modules.alias")"

echo
echo "=== depmod -b <root> <ver> ==="
# -b 指向包含 lib/modules 的根，即真实文件系统的根
depmod -b "$MNT" "$KV" 2>&1 | grep -vE "modules.builtin.modinfo|multiple versions" | head -5
echo "  exit=$?"

echo
echo "=== 清理后条目数 ==="
printf "  modules.dep %s / order %s / alias %s\n" \
    "$(wc -l < "$KM/modules.dep")" "$(wc -l < "$KM/modules.order")" "$(wc -l < "$KM/modules.alias")"

echo
echo "=== modem 残留 ==="
if grep -lE "bam_dmux|rpmsg_wwan|rmnet" "$KM"/modules.* 2>/dev/null; then
    echo "  (仍有残留，见上)"
else
    echo "  OK: 无残留"
fi

echo
echo "=== 关键模块仍在索引中 ==="
for m in wcn36xx cfg80211 mac80211 ext4; do
    n=$(grep -c "/$m\.ko" "$KM/modules.dep" 2>/dev/null || echo 0)
    printf "  %-10s dep 引用 %s 次\n" "$m" "$n"
done

echo
echo "=== 实际 .ko 数 ==="
find "$KM" -name "*.ko" | wc -l

sync
umount "$MNT"
echo DONE
