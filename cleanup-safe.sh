#!/bin/bash
# 受控清理：删除候选包后立即验证 gadget，失败则自动回滚
set -u
LOG=/root/cleanup2.log
export DEBIAN_FRONTEND=noninteractive

echo "===== 清理 $(date) =====" | tee "$LOG"

echo "--- [1] 记录清理前 gadget ---" | tee -a "$LOG"
BEFORE_UDC=$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)
echo "  UDC_before=$BEFORE_UDC" | tee -a "$LOG"

echo "--- [2] 下载候选包（用于回滚）---" | tee -a "$LOG"
mkdir -p /root/rollback && cd /root/rollback
apt-get download libcbor0 libgudev-1.0-0 libldap-2.4-2 libncurses6 libprocps8 libqrtr1 >>"$LOG" 2>&1
ls *.deb 2>/dev/null | wc -l | sed 's/^/  已下载 /' | tee -a "$LOG"

echo "--- [3] 执行 autoremove ---" | tee -a "$LOG"
apt-get -y autoremove --purge >>"$LOG" 2>&1
echo "  rc=$?" | tee -a "$LOG"

echo "--- [4] 立即验证 gadget ---" | tee -a "$LOG"
sleep 3
AFTER_UDC=$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)
ADBD=$(pgrep -c adbd 2>/dev/null || echo 0)
echo "  UDC_after=$AFTER_UDC" | tee -a "$LOG"
echo "  adbd进程=$ADBD" | tee -a "$LOG"
echo "  usb0: $(ip -br addr show usb0 2>/dev/null || echo '不存在')" | tee -a "$LOG"

if [ -z "$AFTER_UDC" ] || [ "$ADBD" = "0" ]; then
    echo "  ⚠️ gadget 异常，执行回滚" | tee -a "$LOG"
    dpkg -i /root/rollback/*.deb >>"$LOG" 2>&1
    pkill -9 adbd 2>/dev/null; sleep 1
    /usr/sbin/mobian-usb-gadget setup >>"$LOG" 2>&1
    sleep 3
    echo "  回滚后 UDC=$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)" | tee -a "$LOG"
else
    echo "  ✅ gadget 正常，清理安全" | tee -a "$LOG"
fi

echo "--- [5] 磁盘 ---" | tee -a "$LOG"
df -h / | tail -1 | tee -a "$LOG"
echo "===== 完成 $(date) =====" | tee -a "$LOG"
