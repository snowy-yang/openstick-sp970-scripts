# 设备端验证：内核版本、设备树、modem 节点、模块加载
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

Write-Output "=== 内核版本 ==="
& $adb shell "cat /proc/version" 2>&1

Write-Output "`n=== 设备树 model ==="
& $adb shell "cat /proc/device-tree/model" 2>&1

Write-Output "`n=== modem 相关节点状态 ==="
$nodes = @(
    'soc/remoteproc@4080000',
    'soc/remoteproc@4080000/bam-dmux',
    'soc/remoteproc@4080000/smd-edge',
    'soc/memshare',
    'soc/remoteproc@a21b000'
)
foreach ($n in $nodes) {
    $s = (& $adb shell "cat /proc/device-tree/$n/status 2>/dev/null || echo MISSING" 2>&1) -join ''
    $s = $s -replace "`r|`n", ''
    Write-Output ("  {0,-42} {1}" -f $n, $s)
}

Write-Output "`n=== modem 内核模块加载数（应为 0）==="
& $adb shell "grep -icE 'bam_dmux|rpmsg_wwan|rmnet' /proc/modules || echo 0" 2>&1

Write-Output "`n=== WWAN/RMNET 网络接口（应为空）==="
& $adb shell "ip link show 2>/dev/null | grep -iE 'wwan|rmnet' || echo '(无)'" 2>&1

Write-Output "`n=== 系统状态 ==="
& $adb shell "uptime" 2>&1
& $adb shell "free -m | head -2" 2>&1
& $adb shell "df -h / | tail -1" 2>&1
