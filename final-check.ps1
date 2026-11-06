# 最终完整验证
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

function Run($desc, $cmd) {
    Write-Output "=== $desc ==="
    & $adb shell $cmd 2>&1
    Write-Output ""
}

Run '系统版本' 'cat /etc/os-release | grep PRETTY; echo "  debian_version: $(cat /etc/debian_version)"; echo "  内核: $(uname -r)"; echo "  运行: $(uptime -p)"'
Run 'systemd / libc' 'systemctl --version | head -1; dpkg-query -W -f="  libc6: ${Version}\n" libc6'
Run 'USB gadget' 'echo "  UDC: $(cat /sys/kernel/config/usb_gadget/g1/UDC)"; echo "  adbd: $(pgrep -c adbd)"; ip -br addr show usb0'
Run 'WiFi' 'ip -br addr show wlan0; ip route show default'
Run '失败单元' 'systemctl --failed --no-pager'
Run 'dpkg 一致性' 'dpkg --audit 2>&1 | head -5; echo "(空=正常)"'
Run '网络连通' 'ping -c 2 -W 3 223.5.5.5 2>&1 | tail -2'
Run '资源' 'free -m | head -2; df -h / | tail -1'
Run '已装包数' 'dpkg -l | grep -c "^ii"'
