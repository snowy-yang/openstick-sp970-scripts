#!/bin/bash
# 清理 modules.order 中的已删模块记录，并做最终一致性校验
set -uo pipefail
MNT=/mnt/vf_dep2
mkdir -p "$MNT"
mountpoint -q "$MNT" && umount "$MNT"
mount -o loop,rw /opt/msm8916/dl/debian/rootfs.raw "$MNT" || { echo MOUNT FAIL; exit 1; }

KM="$MNT/lib/modules/5.15.0-handsomekernel+"

echo "=== 清理 modules.order ==="
if [ -f "$KM/modules.order" ]; then
    cp "$KM/modules.order" /tmp/modules.order.bak
    grep -vE "bam_dmux|rpmsg_wwan|rmnet" /tmp/modules.order.bak > "$KM/modules.order"
    echo "  $(wc -l < /tmp/modules.order.bak) -> $(wc -l < "$KM/modules.order") 行"
fi

echo
echo "=== 最终校验 ==="
echo "  实际 .ko 数:     $(find "$KM" -name '*.ko' | wc -l)"
echo "  modules.dep 行:  $(wc -l < "$KM/modules.dep")"
echo "  modules.order:   $(wc -l < "$KM/modules.order")"
echo
echo "  modem 残留:"
if grep -lE "bam_dmux|rpmsg_wwan|rmnet" "$KM"/modules.* 2>/dev/null; then
    echo "    仍有(见上)"
else
    echo "    无"
fi

echo
echo "  WiFi 模块文件:"
find "$KM" -name "wcn36xx.ko" -o -name "cfg80211.ko" -o -name "mac80211.ko" | sed 's|'"$MNT"'||' | sed 's/^/    /'

echo
echo "  depmod 自检:"
depmod -b "$MNT" 5.15.0-handsomekernel+ -n 2>&1 | grep -ciE "error|not found" | sed 's/^/    错误数: /'

sync
umount "$MNT"
echo DONE
