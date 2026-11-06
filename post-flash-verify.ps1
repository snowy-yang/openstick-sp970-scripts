# 刷机后最终验证：rmtfs 移除、iproute2 安装、WiFi 与网络
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

function Run($desc, $cmd) {
    Write-Output "=== $desc ==="
    & $adb shell $cmd 2>&1
    Write-Output ""
}

Run '内核版本' 'uname -r'
Run 'ip 命令 (iproute2)' 'ip -V; echo "---"; ip -br addr'
Run '默认路由' 'ip route show default; echo "---"; ip route'
Run '失败服务 (rmtfs 应消失)' 'systemctl --failed --no-pager | head -8'
Run 'rmtfs 包状态' 'dpkg -l | grep -i rmtfs || echo "(rmtfs 已移除)"'
Run 'rmtfs 服务文件' 'ls /lib/systemd/system/rmtfs.service 2>/dev/null || echo "(服务文件已删除)"'
Run 'WiFi 设备' 'ls /sys/class/ieee80211/; lsmod | grep wcn36xx'
Run 'WiFi 扫描' 'nmcli -t -f SSID,SIGNAL dev wifi list 2>/dev/null | head -5'
Run '网卡状态' 'nmcli device status | head -5'
Run '系统状态' 'uptime; free -m | head -2; df -h / | tail -1'
