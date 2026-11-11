# WiFi 实际联网测试
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

function Run($desc, $cmd) {
    Write-Output "=== $desc ==="
    & $adb shell $cmd 2>&1
    Write-Output ""
}

Run 'NetworkManager 状态' 'systemctl is-active NetworkManager'
Run 'wlan0 状态' 'nmcli device status 2>&1 | head -6'
Run '可用 WiFi 列表' 'nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | head -10'
Run 'WiFi 扫描能力' 'iw dev wlan0 info 2>&1 | head -8'
Run 'USB 网卡 IP' 'ifconfig usb0 | grep "inet "'
Run 'USB 网卡连通(从本机侧) - 由 PowerShell 测试'
