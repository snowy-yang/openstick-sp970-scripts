#!/bin/bash
# 最终残留清理：polkit 策略、systemd mask 记录、headers 中的 modem 配置项
set -uo pipefail
MNT=/mnt/rootfs_rw
mountpoint -q "$MNT" || { echo "not mounted"; exit 1; }

echo "=== 1) 删除 polkit 中 ModemManager 策略 ==="
rm -f "$MNT/var/lib/polkit-1/localauthority/10-vendor.d/org.freedesktop.ModemManager1.pkla"
echo "  removed ModemManager pkla"
find "$MNT/var/lib/polkit-1" -iname "*ModemManager*" -print -delete 2>/dev/null

echo
echo "=== 2) 清除 systemd masked 记录 ==="
rm -f "$MNT/var/lib/systemd/deb-systemd-helper-masked/ModemManager"
echo "  removed masked record"

echo
echo "=== 3) headers 中 modem 配置标记 ==="
HDR="$MNT/usr/src/linux-headers-5.15.0-handsomekernel+"
if [ -d "$HDR" ]; then
    for c in QCOM_QMI_HELPERS QCOM_MEMSHARE_QMI_SERVICE QCOM_Q6V5_MSS QCOM_BAM_DMUX RPMSG_WWAN_CTRL; do
        if [ -e "$HDR/include/config/$c" ]; then
            rm -f "$HDR/include/config/$c"
            echo "  removed headers config/$c"
        fi
    done
    # autoconf.h 里同步注释掉
    if [ -f "$HDR/include/generated/autoconf.h" ]; then
        sed -i -E \
          -e 's@^#define CONFIG_QCOM_QMI_HELPERS 1@/* modem disabled */@' \
          -e 's@^#define CONFIG_QCOM_MEMSHARE_QMI_SERVICE_MODULE 1@/* modem disabled */@' \
          -e 's@^#define CONFIG_QCOM_Q6V5_MSS_MODULE 1@/* modem disabled */@' \
          -e 's@^#define CONFIG_QCOM_BAM_DMUX_MODULE 1@/* modem disabled */@' \
          -e 's@^#define CONFIG_RPMSG_WWAN_CTRL_MODULE 1@/* modem disabled */@' \
          "$HDR/include/generated/autoconf.h"
        echo "  patched autoconf.h"
    fi
else
    echo "  (headers 目录不存在)"
fi

echo
echo "=== 4) 最终确认 ==="
echo "-- polkit --"
find "$MNT/var/lib/polkit-1" -iname "*ModemManager*" 2>/dev/null || true
echo "-- masked --"
ls "$MNT/var/lib/systemd/deb-systemd-helper-masked/" 2>/dev/null | head
echo "-- firmware --"
ls "$MNT/lib/firmware/"
sync
echo "OK"
