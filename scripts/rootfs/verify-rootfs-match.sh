#!/bin/bash
# 校验 rootfs 内的模块目录与内核 ABI 一致性，并检查 modem 模块是否已移除
set -uo pipefail
MNT=/mnt/rootfs_chk
RAW=/opt/msm8916/dl/debian/rootfs.raw

mkdir -p "$MNT"
mountpoint -q "$MNT" || mount -o loop,ro "$RAW" "$MNT" || { echo "mount failed"; exit 1; }

echo "=== [1] rootfs 内模块目录 ==="
ls -1 "$MNT/lib/modules/" 2>/dev/null | sed 's/^/  /'

echo
echo "=== [2] rootfs 内 modem 模块残留检查 ==="
find "$MNT/lib/modules" -name "*.ko" 2>/dev/null | grep -iE "bam_dmux|rpmsg_wwan|rmnet" || echo "  (无 modem 模块)"

echo
echo "=== [3] rootfs 模块总数 ==="
find "$MNT/lib/modules" -name "*.ko" 2>/dev/null | wc -l | sed 's/^/  /'

echo
echo "=== [4] vermagic 一致性（内核 vs rootfs 模块）==="
KMOD="$MNT/lib/modules/5.15.0-handsomekernel+"
SAMPLE=$(find "$KMOD/kernel/drivers/net/wireless" -name "*.ko" 2>/dev/null | head -1)
if [ -z "$SAMPLE" ]; then
    SAMPLE=$(find "$KMOD" -name "*.ko" 2>/dev/null | head -1)
fi
echo "  样本: ${SAMPLE#"$MNT"}"
modinfo -F vermagic "$SAMPLE" 2>/dev/null | sed 's/^/  rootfs模块 vermagic: /' || \
    strings "$SAMPLE" | grep -m1 "5\.15\.0" | sed 's/^/  vermagic: /'

HOST_MOD=/opt/msm8916/modinst/lib/modules/5.15.0-handsomekernel+/kernel/crypto/crc32_generic.ko
modinfo -F vermagic "$HOST_MOD" 2>/dev/null | sed 's/^/  新编模块 vermagic: /' || \
    strings "$HOST_MOD" | grep -m1 "5\.15\.0" | sed 's/^/  新编vermagic: /'

echo
echo "=== [5] WiFi 固件仍在 ==="
ls "$MNT/lib/firmware/" | grep -E "wcnss|wlan" | sed 's/^/  /'

echo
echo "=== [6] /lib/firmware 中 modem 固件 ==="
ls "$MNT/lib/firmware/" | grep -iE "^modem|^mba" || echo "  (无, 已清除)"

sync
umount "$MNT" 2>/dev/null
echo
echo "OK"
