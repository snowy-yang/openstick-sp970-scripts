# 诊断 usb0 丢失 IPv4 地址
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

function Run($desc, $cmd) {
    Write-Output "=== $desc ==="
    & $adb shell $cmd 2>&1
    Write-Output ""
}

Run 'usb0 详细' 'ip addr show usb0'
Run 'usb0 配置来源' 'ls /etc/NetworkManager/system-connections/ 2>/dev/null; cat /etc/NetworkManager/system-connections/* 2>/dev/null | head -30'
Run 'NetworkManager 日志 usb0' 'journalctl -u NetworkManager --no-pager -n 25 2>/dev/null | grep -iE "usb0|dhcp|addr" | tail -12'
Run 'usb0 静态IP配置 (原配置方式)' 'grep -rn "192.168.68" /etc/ 2>/dev/null | head -10'
Run 'systemd-networkd 配置' 'ls /etc/systemd/network/ 2>/dev/null; cat /etc/systemd/network/*.network 2>/dev/null | head -20'
Run 'usb0 驱动' 'ls /sys/class/net/usb0/ 2>/dev/null | head -3; ip -d link show usb0'
