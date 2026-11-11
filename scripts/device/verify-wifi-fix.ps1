# 验证 QRTR 恢复后 WiFi 是否工作
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

function Run($desc, $cmd) {
    Write-Output "=== $desc ==="
    & $adb shell $cmd 2>&1
    Write-Output ""
}

Run '内核版本' 'uname -r'
Run 'qrtr-ns 服务' 'systemctl is-active qrtr-ns; systemctl is-enabled qrtr-ns'
Run 'wcnss-pil 报错' 'dmesg | grep -iE "wcnss|qmi handle" | head -8'
Run 'remoteproc 设备' 'ls /sys/class/remoteproc/'
Run 'WiFi phy 设备' 'ls /sys/class/ieee80211/ 2>/dev/null || echo "(无)"'
Run 'wcn36xx 模块' 'lsmod | grep -iE "wcn36xx|cfg80211|mac80211"'
Run '网络接口' 'ifconfig -a | grep -E "^[a-z]|inet "'
Run '失败的服务' 'systemctl --failed --no-pager | head -10'
