# 实时监控 USB 插拔事件（监听 60 秒）
Write-Output "=== 开始监控 USB 插拔，请现在插上设备 (60 秒) ==="
$start = Get-Date
$seen = @{}
$baseline = @{}
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'USB\VID_*' } |
    ForEach-Object { $baseline[$_.InstanceId] = $true }
Write-Output "  基线设备数: $($baseline.Count)"

for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    $cur = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
           Where-Object { $_.InstanceId -like 'USB\VID_*' }
    foreach ($d in $cur) {
        if (-not $baseline.ContainsKey($d.InstanceId)) {
            Write-Output ("  [{0:HH:mm:ss}] 新增: {1} | {2}" -f (Get-Date), $d.InstanceId, $d.FriendlyName)
            $baseline[$d.InstanceId] = $true
        }
    }
}
Write-Output "=== 监控结束 ==="
