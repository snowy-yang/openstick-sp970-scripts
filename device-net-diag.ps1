# 诊断 USB 网卡与 iproute2
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

Write-Output "=== iproute2 是否安装 ==="
& $adb shell "which ip ifconfig 2>/dev/null; dpkg -l iproute2 2>/dev/null | tail -1" 2>&1

Write-Output "`n=== 用 /sys 查看网络接口 ==="
& $adb shell "ls /sys/class/net/" 2>&1

Write-Output "`n=== 各接口状态 ==="
& $adb shell "for i in /sys/class/net/*; do echo -n \"\$(basename \$i): \"; cat \$i/operstate 2>/dev/null; done" 2>&1

Write-Output "`n=== usb0 是否有地址 (通过 /proc/net) ==="
& $adb shell "cat /proc/net/fib_trie | head -30" 2>&1

Write-Output "`n=== usb gadget 配置 ==="
& $adb shell "ls /sys/class/udc/ 2>/dev/null; ls /sys/kernel/config/usb_gadget/ 2>/dev/null" 2>&1

Write-Output "`n=== systemd 网络相关单元失败项 ==="
& $adb shell "systemctl --failed --no-pager 2>/dev/null | head -15" 2>&1
