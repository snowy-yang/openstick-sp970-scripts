# 换线后检测设备是否出现
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'
$fb  = 'C:\Users\Administrator\Desktop\sp970-debian超频版\fastboot.exe'

Write-Output "=== 1) ADB ==="
& $adb devices 2>&1

Write-Output "`n=== 2) FASTBOOT ==="
& $fb devices 2>&1

Write-Output "`n=== 3) 关注 VID (18D1=android / 19D1=openstick / 05C6=qualcomm EDL) ==="
$vids = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -like 'USB\VID_*' } |
        ForEach-Object { ($_.InstanceId -split '\\')[1] } | Sort-Object -Unique
$vids
$hit = $vids | Where-Object { $_ -match '18D1|19D1|05C6' }
if ($hit) { Write-Output "`n>>> 检测到目标设备: $hit" } else { Write-Output "`n>>> 未检测到目标设备" }

Write-Output "`n=== 4) 串口 ==="
Get-PnpDevice -PresentOnly -Class Ports -ErrorAction SilentlyContinue |
    Select-Object FriendlyName, InstanceId | Format-Table -AutoSize

Write-Output "`n=== 5) 网卡 ==="
Get-NetAdapter -ErrorAction SilentlyContinue |
    Select-Object Name, InterfaceDescription, Status | Format-Table -AutoSize

Write-Output "`n=== 6) 相关 IP ==="
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -match '^192\.168\.(68|10)\.' } |
    Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize

Write-Output "`n=== 7) ping 目标 ==="
foreach ($ip in '192.168.68.1', '192.168.10.1') {
    $ok = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    Write-Output "  $ip -> $(if($ok){'OK'}else{'FAIL'})"
}
