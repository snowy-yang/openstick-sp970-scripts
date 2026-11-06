# 通过 SSH 做最终确认（不依赖 ADB）
$ErrorActionPreference = 'Continue'

Write-Output "=== SSH 登录测试 ==="
$r = & ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
           -o ConnectTimeout=10 -o PreferredAuthentications=password `
           -o PubkeyAuthentication=no user@192.168.68.1 'echo SSH_OK; uname -r; uptime' 2>&1
$r | Out-String
