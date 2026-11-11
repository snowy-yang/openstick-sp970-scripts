#!/bin/bash
# rootfs 瘦身：删除错装内核、headers、apt 缓存、locale/doc/man
# 目标：465MB -> 约 100MB
set -uo pipefail
MNT=/mnt/rootfs_slim
RAW=/opt/msm8916/dl/debian/rootfs.raw

mkdir -p "$MNT"
if ! mountpoint -q "$MNT"; then
    mount -o loop,rw "$RAW" "$MNT" || { echo "MOUNT FAILED"; exit 1; }
fi
echo "MOUNTED $MNT"
BEFORE=$(du -sm --exclude=proc --exclude=sys "$MNT" 2>/dev/null | cut -f1)
echo "  瘦身前: ${BEFORE} MB"
echo

echo "=== [1] 删除错装的内核包 linux-image-5.14-sdm845 (119MB) ==="
dpkg --root="$MNT" --purge --force-all linux-image-5.14-sdm845 2>&1 | tail -3
# 兜底：手工删除残留
rm -rf "$MNT"/boot/*5.14* "$MNT"/lib/modules/5.14* "$MNT"/usr/lib/modules/5.14* 2>/dev/null
echo "  done"

echo
echo "=== [2] 删除 linux-headers (96MB) ==="
dpkg --root="$MNT" --purge --force-all linux-headers-5.15.0-handsomekernel+ 2>&1 | tail -3
rm -rf "$MNT"/usr/src/linux-headers-* 2>/dev/null
echo "  done"

echo
echo "=== [3] 清理 apt 缓存与索引 (75MB) ==="
rm -rf "$MNT"/var/lib/apt/lists/* 2>/dev/null
rm -rf "$MNT"/var/cache/apt/archives/*.deb 2>/dev/null
echo "  done"

echo
echo "=== [4] 清理 locale (44MB, 保留 en_US 与 zh_CN) ==="
if [ -d "$MNT/usr/share/locale" ]; then
    find "$MNT/usr/share/locale" -mindepth 1 -maxdepth 1 -type d \
         ! -name "en*" ! -name "zh*" ! -name "locale" -exec rm -rf {} + 2>/dev/null
    echo "  剩余: $(ls "$MNT/usr/share/locale" | tr '\n' ' ')"
fi

echo
echo "=== [5] 清理 doc / man (28MB) ==="
rm -rf "$MNT"/usr/share/doc/* 2>/dev/null
rm -rf "$MNT"/usr/share/man/* 2>/dev/null
rm -rf "$MNT"/usr/share/info/* 2>/dev/null
echo "  done"

echo
echo "=== [6] 清理其他缓存 ==="
rm -rf "$MNT"/var/cache/* 2>/dev/null
rm -rf "$MNT"/var/log/*.gz "$MNT"/var/log/*.1 2>/dev/null
rm -rf "$MNT"/tmp/* 2>/dev/null
rm -rf "$MNT"/root/.cache/* 2>/dev/null
echo "  done"

echo
echo "=== [7] 删除 /boot 下的旧内核镜像 ==="
ls -lh "$MNT/boot/" 2>/dev/null
echo

echo "=== 瘦身后 ==="
AFTER=$(du -sm --exclude=proc --exclude=sys "$MNT" 2>/dev/null | cut -f1)
echo "  ${AFTER} MB  (节省 $((BEFORE-AFTER)) MB)"

echo
echo "=== 完整性检查：关键组件仍在 ==="
for p in /bin/bash /sbin/init /usr/sbin/sshd /usr/lib/systemd/systemd \
         /lib/firmware/wcnss.mdt /usr/lib/modules; do
    [ -e "$MNT$p" ] && echo "  OK   $p" || echo "  MISS $p"
done

sync
