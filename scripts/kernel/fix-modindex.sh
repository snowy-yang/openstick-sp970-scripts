#!/bin/bash
# 清理 rootfs 中 modules.dep 等索引对已删除 modem 模块的残留引用
set -uo pipefail
MNT=/mnt/vf_dep
mkdir -p "$MNT"
mountpoint -q "$MNT" && umount "$MNT"
mount -o loop,rw /opt/msm8916/dl/debian/rootfs.raw "$MNT" || { echo MOUNT FAIL; exit 1; }

KM="$MNT/lib/modules/5.15.0-handsomekernel+"

echo "=== 清理前 ==="
for f in modules.dep modules.order modules.builtin modules.alias; do
    [ -f "$KM/$f" ] && printf "  %-18s %s 行\n" "$f" "$(wc -l < "$KM/$f")"
done

echo
echo "=== 用 host depmod 重建索引（-b 指定根，架构无关）==="
# depmod 只读 .ko 的 modinfo，不执行代码，可跨架构安全使用
KV=$(basename "$KM")
depmod -b "$MNT/lib/modules/.." "$KV" -a 2>&1 | grep -v "modules.builtin.modinfo" | head -5 || true

echo
echo "=== 清理后 ==="
for f in modules.dep modules.order modules.builtin modules.alias; do
    [ -f "$KM/$f" ] && printf "  %-18s %s 行\n" "$f" "$(wc -l < "$KM/$f")"
done

echo
echo "=== modem 残留检查 ==="
grep -lE "bam_dmux|rpmsg_wwan|rmnet" "$KM"/modules.* 2>/dev/null | sed 's/^/  仍有残留: /' || echo "  OK: 无残留"

echo
echo "=== WiFi 索引是否正常 ==="
grep -c "wcn36xx" "$KM/modules.alias" 2>/dev/null | sed 's/^/  wcn36xx alias 条目: /'

sync
umount "$MNT"
echo DONE
