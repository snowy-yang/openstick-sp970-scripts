#!/bin/bash
# 阶段1：以读写方式挂载 rootfs，删除所有 modem 相关固件/软件/服务
# 注意：wcnss.* 是 WiFi （pronto）固件，必须保留
set -euo pipefail

RAW=/opt/msm8916/dl/debian/rootfs.raw
MNT=/mnt/rootfs_rw

umount "$MNT" 2>/dev/null || true
mkdir -p "$MNT"
mount -o loop,rw "$RAW" "$MNT"
echo "mounted rw at $MNT"

echo
echo "=== [1] 删除 modem 固件 ==="
cd "$MNT/lib/firmware"
for f in mba.mbn modem.mdt modem.b*; do
    if [ -e "$f" ]; then
        rm -f "$f"
        echo "  removed firmware/$f"
    fi
done

echo
echo "=== [2] 停用并卸载 ModemManager / libqmi / libmbim 相关包 ==="
# 用 chroot 方式 purge，避免依赖残留
export DEBIAN_FRONTEND=noninteractive
mount --bind /dev "$MNT/dev"
mount --bind /proc "$MNT/proc"
mount --bind /sys "$MNT/sys"
# 复制 resolv.conf 供 apt 使用
[ -e "$MNT/etc/resolv.conf" ] || echo "nameserver 8.8.8.8" > "$MNT/etc/resolv.conf"

chroot "$MNT" /bin/bash -c 'export DEBIAN_FRONTEND=noninteractive; \
    dpkg --purge --force-all modemmanager libqmi-utils libqmi-proxy libqmi-glib5 libmbim-proxy libmbim-glib4 2>&1 | tail -20' || \
    echo "WARN: purge 部分失败，将回退为手工清理"

umount "$MNT/sys" 2>/dev/null || true
umount "$MNT/proc" 2>/dev/null || true
umount "$MNT/dev" 2>/dev/null || true

echo
echo "=== [3] 手工兜底清理 ==="
rm -f  "$MNT/lib/systemd/system/ModemManager.service" 2>/dev/null || true
rm -f  "$MNT/usr/sbin/ModemManager" 2>/dev/null || true
rm -rf "$MNT/usr/lib/ModemManager" 2>/dev/null || true
rm -rf "$MNT/etc/ModemManager" 2>/dev/null || true
rm -f  "$MNT/usr/lib/systemd/system/ModemManager.service" 2>/dev/null || true

# 禁用多路径相关服务
find "$MNT/etc/systemd/system" -name "*.wants" -type d 2>/dev/null | while read d; do
    rm -f "$d"/ModemManager.service 2>/dev/null || true
done

echo
echo "=== [4] 移除 rootfs 内 modem 内核模块（若有）==="
find "$MNT/lib/modules" -type f \( -name "*bam_dmux*" -o -name "*rpmsg_wwan*" -o -name "rmnet.ko" \) 2>/dev/null | while read f; do
    rm -f "$f"; echo "  removed $f"
done

echo
echo "=== [5] 校验残留 ==="
echo "-- firmware 剩余 --"
ls "$MNT/lib/firmware/"
echo "-- modem 关键字残留 --"
grep -ril "modem" "$MNT/etc/systemd/system" "$MNT/lib/systemd/system" 2>/dev/null | head -5 || echo "  (systemd 无残留)"
command -v ModemManager >/dev/null 2>&1 && echo "  ModemManager 仍在" || true
ls "$MNT/usr/sbin/ModemManager" 2>/dev/null && echo "  !! ModemManager 二进制仍在" || echo "  ModemManager 二进制已移除"

sync
umount "$MNT"
echo
echo "=== done, rootfs unmounted ==="
