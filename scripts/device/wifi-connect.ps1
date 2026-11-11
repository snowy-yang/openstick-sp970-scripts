# 通过 nmcli 连接 WiFi（分步执行，避免密码在命令行被解析）
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'
$pw = $env:WIFI_PSK

Write-Output "=== 1) 先删除可能存在的旧 profile ==="
& $adb shell "nmcli connection delete 'WiFi-Ultra' 2>/dev/null; echo done" 2>&1

Write-Output "`n=== 2) 创建连接（用 -- 分隔）==="
& $adb shell "nmcli connection add type wifi con-name WU ifname wlan0 ssid 'WiFi-Ultra'" 2>&1

Write-Output "`n=== 3) 设置密码 ==="
& $adb shell "nmcli connection modify WU wifi-sec.key-mgmt wpa-psk" 2>&1
& $adb shell "nmcli connection modify WU wifi-sec.psk '$pw'" 2>&1

Write-Output "`n=== 4) 激活 ==="
& $adb shell "nmcli connection up WU" 2>&1

Write-Output "`n=== 5) 检查 ==="
Start-Sleep -Seconds 12
& $adb shell "ip -br addr show wlan0; echo '---route---'; ip route show default" 2>&1
