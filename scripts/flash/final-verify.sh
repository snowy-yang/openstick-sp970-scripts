#!/bin/bash
# 最终完整验证
set -uo pipefail
WORK=/opt/msm8916/bootwork
OUT=/mnt/d/msm8916/out
VERIFY=/tmp/vf

echo "########## boot.img ##########"
abootimg -i "$OUT/boot-sp970-nomodrm.img" | grep -E "image size|kernel size|ramdisk size|cmdline"

echo
rm -rf "$VERIFY"; mkdir -p "$VERIFY"; cd "$VERIFY"
abootimg -x "$OUT/boot-sp970-nomodrm.img" >/dev/null

echo "########## 内核内嵌 dtb ##########"
python3 - <<'PY'
z=open("/tmp/vf/zImage","rb").read()
i=z.rfind(b"\xd0\x0d\xfe\xed")
open("/tmp/vf/emb.dtb","wb").write(z[i:])
print(f"  dtb {len(z)-i} bytes")
PY
dtc -I dtb -O dts "$VERIFY/emb.dtb" -o "$VERIFY/emb.dts" 2>/dev/null
grep -m1 "model" "$VERIFY/emb.dts" | sed 's/^/  /'
python3 /mnt/d/msm8916/scripts/check-modem-status.py "$VERIFY/emb.dts"

echo
echo "########## ramdisk 模块 ##########"
mkdir -p "$VERIFY/rd" && cd "$VERIFY/rd"
zcat ../initrd.img | cpio -idm --quiet 2>/dev/null
MD="usr/lib/modules/5.15.0-handsomekernel+"
echo "  模块数: $(find "$MD" -name '*.ko' | wc -l)"
echo "  modem 模块: $(find "$MD" -name '*.ko' | grep -ciE 'bam_dmux|rpmsg_wwan|rmnet' || echo 0)"
echo "  WiFi 模块: $(find "$MD" -name 'wcn36xx*.ko' | wc -l)"

echo
echo "########## rootfs ##########"
MNT=/mnt/vf_root
mkdir -p "$MNT"
mount -o loop,ro /opt/msm8916/dl/debian/rootfs.raw "$MNT" || { echo "MOUNT FAIL"; exit 1; }
echo "  占用: $(du -sh --exclude=proc --exclude=sys "$MNT" 2>/dev/null | cut -f1)"
df -h "$MNT" | tail -1 | awk '{print "  容量: "$2", 可用: "$4}'

echo "  -- modem 固件 --"
ls "$MNT/lib/firmware/" | grep -icE "^modem|^mba" || echo "    0 (已清除)"
echo "  -- WiFi 固件 --"
ls "$MNT/lib/firmware/" | grep -E "^wcnss" | wc -l | sed 's/^/    /'
echo "  -- 错装内核包 --"
dpkg --root="$MNT" -l 2>/dev/null | grep -c "5.14-sdm845" || echo "    0 (已删)"
echo "  -- headers --"
ls -d "$MNT/usr/src/linux-headers"* 2>/dev/null || echo "    0 (已删)"
echo "  -- 关键二进制 --"
for p in /sbin/init /usr/lib/systemd/systemd /usr/sbin/sshd /bin/bash /usr/bin/nmcli; do
    [ -e "$MNT$p" ] && echo "    OK  $p" || echo "    MISS $p"
done
echo "  -- 内核模块 dir --"
ls -1 "$MNT/lib/modules/" | sed 's/^/    /'
umount "$MNT"
echo
echo "########## 完成 ##########"
