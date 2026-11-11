#!/bin/bash
set -uo pipefail
MNT=/mnt/rootfs_chk2
mkdir -p "$MNT"
mountpoint -q "$MNT" || mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || exit 1

echo "=== rootfs 中 WiFi 相关模块 ==="
find "$MNT/lib/modules" -name "*.ko" | grep -iE "wcn36xx|ath6kl|cfg80211|mac80211" | sed "s|$MNT||" | head

echo
echo "=== rootfs 中 USB gadget 相关模块 ==="
find "$MNT/lib/modules" -name "*.ko" | grep -iE "gadget|udc|dwc3|phy-msm" | sed "s|$MNT||" | head

echo
echo "=== 我们的 modinst 中对应模块 ==="
find /opt/msm8916/modinst -name "*.ko" | grep -iE "wcn36xx|cfg80211|mac80211|dwc3|gadget" | sed "s|/opt/msm8916/modinst||" | head

umount "$MNT"
