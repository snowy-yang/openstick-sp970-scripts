#!/bin/bash
# 盘点当前内核配置中体积大/对 SP970 无用的子系统
set -uo pipefail
CFG=/opt/msm8916/build/.config
IMG=/opt/msm8916/build/arch/arm64/boot/Image

echo "=== 当前内核体积 ==="
ls -l "$IMG" | awk '{printf "  %s bytes (%.2f MB)\n", $5, $5/1048576}'

echo
echo "=== 体积大户统计（按模块大小/内建项数量）==="
MODINST=/opt/msm8916/modinst/lib/modules/5.15.0-handsomekernel+
du -sh "$MODINST/kernel/"* 2>/dev/null | sort -rh | head -20

echo
echo "=== 各子系统模块总大小 ==="
for d in drivers/gpu drivers/media drivers/net/wireless drivers/net/ethernet \
         drivers/usb drivers/input drivers/sound drivers/crypto fs net \
         drivers/bluetooth drivers/spi drivers/i2c drivers/mfd drivers/hid; do
    p="$MODINST/kernel/$d"
    [ -d "$p" ] && printf "  %-28s %s\n" "$d" "$(du -sh "$p" 2>/dev/null | cut -f1)"
done

echo
echo "=== 内建(y)且体积可能很大的配置 ==="
grep -E "^CONFIG_(DRM|MEDIA|SND|USB|NET|IPV6|WIRELESS|BT|CAN|ISDN|HAMRADIO|IEEE802154|NFC|RDS)" "$CFG" 2>/dev/null | grep "=y" | head -40
