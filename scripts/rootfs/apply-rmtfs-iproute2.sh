#!/bin/bash
# 在 rootfs 镜像中：purge rmtfs + 离线安装 iproute2 及其依赖
set -uo pipefail

RAW=/opt/msm8916/dl/debian/rootfs.raw
MNT=/mnt/rootfs_edit
DEBS=/opt/msm8916/debs

mkdir -p "$MNT"
mountpoint -q "$MNT" && umount "$MNT"
mount -o loop,rw "$RAW" "$MNT" || { echo "MOUNT FAILED"; exit 1; }
echo "MOUNTED"

BEFORE=$(du -sm --exclude=proc --exclude=sys "$MNT" | cut -f1)

echo
echo "=== [1] purge rmtfs ==="
dpkg --root="$MNT" --purge --force-all rmtfs 2>&1 | tail -3
rm -f "$MNT/usr/bin/rmtfs" "$MNT/lib/systemd/system/rmtfs.service" 2>/dev/null
find "$MNT/etc/systemd/system" -type l -name 'rmtfs.service' -delete 2>/dev/null
rm -rf "$MNT/etc/systemd/system/multi-user.target.wants/rmtfs.service" 2>/dev/null
echo "  验证:"
if dpkg --root="$MNT" -l 2>/dev/null | grep -q '^ii.*rmtfs'; then echo "    !! 仍安装"; else echo "    rmtfs 已移除"; fi
[ -e "$MNT/usr/bin/rmtfs" ] && echo "    !! 二进制残留" || echo "    二进制已删除"
[ -e "$MNT/lib/systemd/system/rmtfs.service" ] && echo "    !! 服务文件残留" || echo "    服务文件已删除"

echo
echo "=== [2] 安装 iproute2 + 依赖 ==="
# 顺序：依赖优先
ORDER="debconf_1.5.77_all.deb libbpf0_0.3-2_arm64.deb libelf1_0.183-1_arm64.deb iproute2_5.10.0-4_arm64.deb"
for d in $ORDER; do
    if [ -f "$DEBS/$d" ]; then
        out=$(dpkg --root="$MNT" --unpack "$DEBS/$d" 2>&1 | tail -3)
        echo "  unpack $d"
        [ -n "$out" ] && echo "$out" | sed 's/^/    /'
    else
        echo "  缺失 $d"
    fi
done

echo
echo "  配置（--configure -a）:"
dpkg --root="$MNT" --force-all --configure -a 2>&1 | tail -8 | sed 's/^/    /'

echo
echo "=== [3] 验证 ip 命令 ==="
if [ -x "$MNT/bin/ip" ]; then
    echo "    /bin/ip 存在"
    file "$MNT/bin/ip" | sed 's/^/    /'
    [ -L "$MNT/sbin/ip" ] && echo "    /sbin/ip -> $(readlink "$MNT/sbin/ip")"
    [ -x "$MNT/sbin/tc" ] && echo "    /sbin/tc 存在"
else
    echo "    !! /bin/ip 不存在"
fi

echo
echo "=== [4] dpkg 数据库状态 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -E "iproute2|libbpf0|libelf1|debconf" | awk '{printf "    %s %s %s\n", $1, $2, $3}'

echo
echo "=== [5] 检查 dpkg 是否有未配置项 ==="
dpkg --root="$MNT" -l 2>/dev/null | grep -E '^.[^i]' | head -5 || echo "    (无异常)"

AFTER=$(du -sm --exclude=proc --exclude=sys "$MNT" | cut -f1)
echo
echo "体积: ${BEFORE} MB -> ${AFTER} MB"

sync
echo "DONE (保持挂载以便后续校验)"
