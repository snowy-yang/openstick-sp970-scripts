# 功能验证：网络、WiFi、SSH、软件包状态
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

Write-Output "=== 网络接口 ==="
& $adb shell "ip -br addr" 2>&1

Write-Output "`n=== 默认路由 ==="
& $adb shell "ip route show default" 2>&1

Write-Output "`n=== WiFi 驱动加载状态 ==="
& $adb shell "lsmod | grep -iE 'wcn36xx|cfg80211|mac80211'" 2>&1
& $adb shell "dmesg | grep -iE 'wcn36xx|wcnss' | tail -5" 2>&1

Write-Output "`n=== 外网连通性 ==="
& $adb shell "ping -c 2 -W 3 223.5.5.5 2>&1 | tail -3" 2>&1

Write-Output "`n=== SSH 服务 ==="
& $adb shell "systemctl is-active sshd 2>/dev/null; systemctl is-enabled sshd 2>/dev/null" 2>&1

Write-Output "`n=== modem 软件包确认已移除 ==="
& $adb shell "dpkg -l 2>/dev/null | grep -icE 'modemmanager|libqmi|libmbim' || echo '0 (已移除)'" 2>&1

Write-Output "`n=== modem 固件确认已移除 ==="
& $adb shell "ls /lib/firmware/ | grep -icE '^modem|^mba' || echo '0 (已移除)'" 2>&1

Write-Output "`n=== WiFi 固件仍在 ==="
& $adb shell "ls /lib/firmware/ | grep -c '^wcnss'" 2>&1

Write-Output "`n=== 根文件系统占用 ==="
& $adb shell "df -h / | tail -1" 2>&1
