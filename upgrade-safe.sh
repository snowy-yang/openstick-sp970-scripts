#!/bin/bash
# Debian 12 升级（安全版）：升级后自动校验并修复 USB gadget
set -u
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
LOG=/root/upgrade.log
CONF="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

echo "===== 升级开始 $(date) =====" | tee "$LOG"

echo "--- [1] minimal ---" | tee -a "$LOG"
apt-get $CONF -y --allow-change-held-packages install dpkg apt libc6 >>"$LOG" 2>&1
echo "  rc=$?" | tee -a "$LOG"

echo "--- [2] dist-upgrade ---" | tee -a "$LOG"
apt-get $CONF -y --allow-change-held-packages dist-upgrade >>"$LOG" 2>&1
echo "  rc=$?" | tee -a "$LOG"

echo "--- [3] fix-broken ---" | tee -a "$LOG"
apt-get $CONF -y --fix-broken install >>"$LOG" 2>&1
echo "  rc=$?" | tee -a "$LOG"

echo "--- [4] 恢复关键文件（防止被覆盖）---" | tee -a "$LOG"
for f in mobian-usb-gadget gc adbd; do
    src="/root/usb-backup/$f"
    [ -f "$src" ] || continue
    case "$f" in
        mobian-usb-gadget) dst=/usr/sbin/mobian-usb-gadget ;;
        gc)                dst=/usr/bin/gc ;;
        adbd)              dst=/usr/bin/adbd ;;
    esac
    if [ ! -x "$dst" ]; then
        cp -a "$src" "$dst"; chmod 755 "$dst"
        echo "  恢复 $dst" | tee -a "$LOG"
    fi
done

echo "--- [5] 校验 USB gadget ---" | tee -a "$LOG"
UDC=$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)
echo "  UDC=$UDC" | tee -a "$LOG"
if [ -z "$UDC" ]; then
    echo "  gadget 未激活，尝试重建" | tee -a "$LOG"
    pkill -9 adbd 2>/dev/null
    gc -c 2>/dev/null; sleep 1
    /usr/sbin/mobian-usb-gadget setup >>"$LOG" 2>&1
    sleep 3
    echo "  重建后 UDC=$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)" | tee -a "$LOG"
fi

echo "--- [6] 版本 ---" | tee -a "$LOG"
cat /etc/debian_version >>"$LOG" 2>&1
cat /etc/debian_version | tee -a "$LOG"

echo "===== 升级结束 $(date) =====" | tee -a "$LOG"
echo DONE > /root/upgrade.done
