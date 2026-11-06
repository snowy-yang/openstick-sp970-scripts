# 诊断 qrtr 与 wifi 依赖（避免 PowerShell 变量展开）
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

function Run($desc, $cmd) {
    Write-Output "=== $desc ==="
    & $adb shell $cmd 2>&1
    Write-Output ""
}

Run 'qrtr-ns.service 失败原因' 'systemctl status qrtr-ns --no-pager -l | head -15'
Run 'qrtr 内核支持' 'grep -i qrtr /proc/modules; ls /sys/module/ | grep -i qrtr'
Run 'wcnss-pil 报错' 'dmesg | grep -iE "wcnss|pronto" | head -20'
Run 'remoteproc 状态' 'for f in /sys/class/remoteproc/*/state; do echo "$f"; cat "$f"; done'
Run 'usb0 配置' 'ifconfig usb0 | head -5'
Run 'DHCP 服务' 'systemctl is-active dnsmasq dhcpd udhcpd 2>/dev/null'
Run 'wifi 无线扩展' 'iwconfig 2>/dev/null | head -20; ls /sys/class/ieee80211/ 2>/dev/null'
