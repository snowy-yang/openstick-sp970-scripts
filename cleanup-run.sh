#!/bin/bash
# 清理无用包与配置
set -u
export DEBIAN_FRONTEND=noninteractive
LOG=/root/cleanup.log
BEFORE=$(df -m / | tail -1 | awk '{print $3}')

echo "===== 清理开始 $(date) =====" | tee -a "$LOG"

echo "--- [1] apt autoremove ---" | tee -a "$LOG"
apt-get -y autoremove --purge >> "$LOG" 2>&1
echo "  rc=$?" | tee -a "$LOG"

echo "--- [2] 移除 modem 残留库（modem 已不存在的 GLib 绑定）---" | tee -a "$LOG"
apt-get -y purge libqrtr-glib0 libmm-glib0 >> "$LOG" 2>&1
echo "  rc=$?" | tee -a "$LOG"

echo "--- [3] 移除未使用的文件系统工具（rootfs 是 ext4）---" | tee -a "$LOG"
apt-get -y purge btrfs-progs f2fs-tools >> "$LOG" 2>&1
echo "  rc=$?" | tee -a "$LOG"

echo "--- [4] 清理 apt 缓存与索引 ---" | tee -a "$LOG"
apt-get clean >> "$LOG" 2>&1
rm -rf /var/lib/apt/lists/* >> "$LOG" 2>&1
rm -rf /var/cache/apt/archives/*.deb >> "$LOG" 2>&1
echo "  done" | tee -a "$LOG"

echo "--- [5] 清理文档/man/locale ---" | tee -a "$LOG"
rm -rf /usr/share/doc/* >> "$LOG" 2>&1
rm -rf /usr/share/man/* >> "$LOG" 2>&1
rm -rf /usr/share/info/* >> "$LOG" 2>&1
# locale 保留 en / zh
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
     ! -name 'en*' ! -name 'zh*' -exec rm -rf {} + 2>/dev/null
echo "  剩余 locale: $(ls /usr/share/locale | tr '\n' ' ')" | tee -a "$LOG"

echo "--- [6] 清理日志与临时文件 ---" | tee -a "$LOG"
find /var/log -type f \( -name '*.gz' -o -name '*.1' -o -name '*.old' \) -delete 2>/dev/null
rm -rf /var/backups/*.dpkg-old /var/backups/*.dpkg-dist 2>/dev/null
rm -rf /tmp/* /root/.cache/* 2>/dev/null
echo "  done" | tee -a "$LOG"

echo "--- [7] 清理 dpkg 残留配置（已卸载包）---" | tee -a "$LOG"
RC=$(dpkg -l | awk '$1=="rc"{print $2}')
if [ -n "$RC" ]; then
    echo "  残留配置: $RC" | tee -a "$LOG"
    dpkg --purge $RC >> "$LOG" 2>&1
else
    echo "  无 rc 状态包" | tee -a "$LOG"
fi

AFTER=$(df -m / | tail -1 | awk '{print $3}')
echo "" | tee -a "$LOG"
echo "===== 磁盘占用: ${BEFORE} MB -> ${AFTER} MB (节省 $((BEFORE-AFTER)) MB) =====" | tee -a "$LOG"
echo "===== 清理结束 $(date) =====" | tee -a "$LOG"
