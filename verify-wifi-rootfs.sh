#!/bin/bash
# 确认 rootfs 中 WiFi/USB gadget 模块完好，且与新内核 vermagic 一致
set -uo pipefail
MNT=/mnt/vf_wifi
mkdir -p "$MNT"
mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || { echo MOUNT FAIL; exit 1; }

KM="$MNT/lib/modules/5.15.0-handsomekernel+"
echo "=== rootfs WiFi 模块 ==="
find "$KM" -name "*.ko" | grep -iE "wcn36xx|cfg80211|mac80211|ath" | sed "s|$MNT||"

echo
echo "=== 模块总数 ==="
find "$KM" -name "*.ko" | wc -l

echo
echo "=== vermagic 核对 ==="
for f in $(find "$KM" -name "wcn36xx.ko" -o -name "cfg80211.ko" | head -2); do
    echo "  $(basename $f):"
    strings "$f" | grep -m1 "5\.15\.0-handsomekernel" | sed 's/^/    /'
done

echo
echo "=== depmod 索引是否与现存模块一致 ==="
if [ -f "$KM/modules.dep" ]; then
    echo "  modules.dep 条目: $(wc -l < "$KM/modules.dep")"
    echo "  实际 .ko 数:      $(find "$KM" -name '*.ko' | wc -l)"
    echo "  引用已删模块的行:"
    grep -E "bam_dmux|rpmsg_wwan|rmnet" "$KM/modules.dep" | sed 's/^/    /' || echo "    (无)"
else
    echo "  (无 modules.dep)"
fi

echo
echo "=== USB gadget 模块 ==="
find "$KM" -name "*.ko" | grep -iE "gadget|dwc3|phy-msm" | sed "s|$MNT||" | head
umount "$MNT"
