#!/bin/bash
# 刷机前严格校验 boot.img 内容
set -uo pipefail
IMG=/opt/msm8916/bootwork/boot-sp970-nomodrm.img
V=/tmp/preflash
rm -rf "$V"; mkdir -p "$V"; cd "$V"
abootimg -x "$IMG" >/dev/null

echo "=== [1] 内核版本串（必须是 gcc 15 / 2026）==="
zcat zImage 2>/dev/null | strings | grep -m1 "Linux version 5.15" || \
    strings zImage | grep -m1 "Linux version 5.15"

echo
echo "=== [2] 内嵌 dtb ==="
python3 - <<'PY'
z=open("/tmp/preflash/zImage","rb").read()
i=z.rfind(b"\xd0\x0d\xfe\xed")
print(f"  dtb offset={i} size={len(z)-i}")
open("/tmp/preflash/e.dtb","wb").write(z[i:])
PY
dtc -I dtb -O dts "$V/e.dtb" -o "$V/e.dts" 2>/dev/null
grep -m1 "model" "$V/e.dts" | sed 's/^/  /'
python3 /mnt/d/msm8916/scripts/check-modem-status.py "$V/e.dts" | sed 's/^/  /'

echo
echo "=== [3] ramdisk modem 模块 ==="
mkdir -p "$V/rd" && cd "$V/rd"
zcat ../initrd.img | cpio -idm --quiet 2>/dev/null
MD=usr/lib/modules/5.15.0-handsomekernel+
echo "  模块数: $(find $MD -name '*.ko' | wc -l)"
echo "  modem:  $(find $MD -name '*.ko' | grep -ciE 'bam_dmux|rpmsg_wwan|rmnet' || true)"

echo
echo "=== 校验结果 ==="
if zcat /tmp/preflash/zImage 2>/dev/null | strings | grep -q "Ubuntu 15.2.0"; then
    echo "  ✅ 内核是我们编译的版本 (gcc 15.2.0)"
else
    echo "  ❌ 内核不是我们的版本！"
fi
