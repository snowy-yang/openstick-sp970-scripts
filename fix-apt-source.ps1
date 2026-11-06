# 修复 apt 源与时区，为升级 Debian 12 做准备
$adb = 'C:\Users\Administrator\Desktop\sp970-debian超频版\adb.exe'

Write-Output "=== 1) 备份并查看当前源 ==="
& $adb shell "cp /etc/apt/sources.list /etc/apt/sources.list.bullseye.bak 2>/dev/null; cat /etc/apt/sources.list" 2>&1

Write-Output "`n=== 2) 查看 sources.list.d ==="
& $adb shell "ls /etc/apt/sources.list.d/ 2>/dev/null; cat /etc/apt/sources.list.d/* 2>/dev/null | head -20" 2>&1

Write-Output "`n=== 3) 设置时区为 Asia/Shanghai ==="
& $adb shell "ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; echo 'Asia/Shanghai' > /etc/timezone; date" 2>&1

Write-Output "`n=== 4) 测试各源可用性 ==="
& $adb shell "for u in http://mirrors.163.com/debian/dists/bullseye/Release http://deb.debian.org/debian/dists/bullseye/Release http://mirrors.tuna.tsinghua.edu.cn/debian/dists/bullseye/Release http://mirrors.aliyun.com/debian/dists/bullseye/Release; do printf '%-60s ' `$u; curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 `$u; done" 2>&1
