#!/bin/bash
# 挂载 rootfs.raw 并用 dpkg --root 清除 modem 相关软件包（arm64，无法 chroot）
set -uo pipefail

RAW=/opt/msm8916/dl/debian/rootfs.raw
MNT=/mnt/rootfs_rw

mkdir -p "$MNT"
if ! mountpoint -q "$MNT"; then
    mount -o loop,rw "$RAW" "$MNT" || { echo "MOUNT FAILED"; exit 1; }
fi
echo "MOUNTED at $MNT"

echo
echo "=== 相关包当前状态 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -iE "modemmanager|libqmi|libmbim" || echo "  (db 中无匹配)"

echo
echo "=== 执行 purge（--root 模式）==="
PKGS="modemmanager libqmi-utils libqmi-proxy libqmi-glib5 libmbim-proxy libmbim-glib4 libmbim-utils"
for p in $PKGS; do
    if dpkg --root="$MNT" -s "$p" >/dev/null 2>&1; then
        dpkg --root="$MNT" --purge --force-all "$p" >/dev/null 2>&1 \
            && echo "  purged: $p" || echo "  purge failed: $p"
    else
        echo "  not installed: $p"
    fi
done

echo
echo "=== 手工兜底 ==="
rm -rf "$MNT/usr/lib/ModemManager" "$MNT/etc/ModemManager" 2>/dev/null
rm -f  "$MNT/usr/sbin/ModemManager" "$MNT/lib/systemd/system/ModemManager.service" \
       "$MNT/usr/lib/systemd/system/ModemManager.service" 2>/dev/null
find "$MNT/etc/systemd/system" -type l -name "ModemManager.service" -delete 2>/dev/null
echo "  done"

echo
echo "=== 最终校验 ==="
echo "-- ModemManager 相关文件 --"
find "$MNT" -maxdepth 4 -iname "*ModemManager*" 2>/dev/null | head || true
echo "-- /lib/firmware --"
ls "$MNT/lib/firmware/"

sync
