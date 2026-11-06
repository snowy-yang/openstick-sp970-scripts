#!/bin/bash
# 校验内核裁剪结果
set -uo pipefail
CFG=/opt/msm8916/build/.config

echo "=== 应已关闭（期望输出 is not set）==="
for c in CONFIG_KVM CONFIG_VIRTUALIZATION CONFIG_SOUND CONFIG_SND \
         CONFIG_BT CONFIG_BT_HCIUART CONFIG_VIDEO_QCOM_CAMSS \
         CONFIG_MEDIA_SUPPORT CONFIG_TOUCHSCREEN_ATMEL_MXT; do
    line=$(grep -E "^(# )?${c}(=| is not set)" "$CFG" 2>/dev/null | head -1)
    [ -z "$line" ] && line="(条目不存在)"
    printf "  %-32s %s\n" "$c" "$line"
done

echo
echo "=== 应仍开启（期望 =y 或 =m）==="
for c in CONFIG_WCN36XX CONFIG_CFG80211 CONFIG_MAC80211 CONFIG_USB_GADGET \
         CONFIG_USB_CONFIGFS CONFIG_DRM CONFIG_EXT4_FS CONFIG_NETFILTER \
         CONFIG_NET_VENDOR_INTEL CONFIG_NET_VENDOR_BROADCOM; do
    line=$(grep -E "^${c}=" "$CFG" 2>/dev/null | head -1)
    [ -z "$line" ] && line="MISSING"
    printf "  %-32s %s\n" "$c" "$line"
done

echo
echo "=== 统计 ==="
printf "  =y 项数: %s\n" "$(grep -cE '^CONFIG_[A-Z0-9_]+=y' "$CFG")"
printf "  =m 项数: %s\n" "$(grep -cE '^CONFIG_[A-Z0-9_]+=m' "$CFG")"
