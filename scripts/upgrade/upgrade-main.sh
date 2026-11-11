#!/bin/bash
# Debian 11 -> 12 主升级流程（后台执行，日志落盘）
set -u
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
LOG=/root/upgrade.log

echo "===== 升级开始 $(date) =====" | tee -a "$LOG"

# 关键：保留现有配置文件，避免交互
CONF_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

run_step() {
    local name="$1"; shift
    echo "" | tee -a "$LOG"
    echo "----- [$name] $(date +%H:%M:%S) -----" | tee -a "$LOG"
    "$@" >> "$LOG" 2>&1
    local rc=$?
    echo "----- [$name] 结束 rc=$rc -----" | tee -a "$LOG"
    return $rc
}

# 1) 先升级 dpkg/apt 等基础工具（minimal）
run_step "minimal-upgrade" \
    apt-get $CONF_OPTS -y --allow-change-held-packages \
    -o APT::Get::Always-Include-Phased-Updates=false \
    install dpkg apt libc6

# 2) 完整升级
run_step "dist-upgrade" \
    apt-get $CONF_OPTS -y --allow-change-held-packages dist-upgrade

# 3) 修复潜在缺失依赖
run_step "fix-broken" \
    apt-get $CONF_OPTS -y --fix-broken install

echo "" | tee -a "$LOG"
echo "===== 升级结束 $(date) =====" | tee -a "$LOG"
cat /etc/debian_version >> "$LOG" 2>&1
echo "DONE" > /root/upgrade.done
