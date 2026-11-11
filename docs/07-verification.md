# 7. 验收

刷完不是结束，是开始。这一章给出可执行的验收清单：每条都有命令、预期输出、以及"如果不符合该看哪一章"。

## 7.1 系统与内核

```bash
uname -r
# 预期：5.15.0-handsomekernel+

cat /etc/debian_version
# 预期：12.15

systemctl --version | head -1
# 预期：systemd 252 (252.39-1~deb12u1)

ldd --version | head -1
# 预期：ldd (Debian GLIBC 2.36-9+deb12u...) 2.36
```

## 7.2 设备树：modem 确实是关的

```bash
ls /proc/device-tree/soc@0/ | grep -i -E 'mpss|remoteproc'
cat /proc/device-tree/soc@0/remoteproc@*/status 2>/dev/null
# 预期：disabled（或节点不存在）

dmesg | grep -i -E 'q6v5|mba|mpss|remoteproc' 
# 预期：没有任何 mba/mpss 固件加载成功的日志
```

宿主机侧不连设备也能验：`scripts/kernel/check-modem-status.py` 直接反编译 boot.img 里的 DTB。

```bash
python3 scripts/kernel/check-modem-status.py boot-sp970-nomodrm.img
# 预期：&mpss disabled / bam-dmx disabled / smd-edge disabled / &memshare disabled
```

同时确认保留内存已释放（`mpss_mem` 的 85 MiB 应当在内核可用内存里）：

```bash
grep MemTotal /proc/meminfo
# 预期：接近 480000 kB 量级；若 modem carveout 仍被保留会明显偏小
```

## 7.3 模块

```bash
ls /lib/modules/
# 预期：只有一个版本目录 5.15.0-handsomekernel+

find /lib/modules -name '*.ko' | wc -l
# 预期：175

modinfo ext4 | head -3
# 预期：包含 (builtin)

modinfo wcn36xx >/dev/null && echo WIFI_MOD_OK
# 预期：WIFI_MOD_OK

# modem 相关模块必须不存在
for m in qcom_q6v5_mss qcom_memshare qrtr cdc_wdm qcom_bam_dmux rmnet; do
    modinfo "$m" >/dev/null 2>&1 && echo "LEFTOVER: $m"
done
# 预期：无输出
```

一致性交叉验证（宿主机侧）：

```bash
scripts/rootfs/verify-rootfs-match.sh
scripts/kernel/verify-trim.sh
```

## 7.4 网络

### USB gadget

```bash
ls /sys/class/udc/
# 预期：ci_hdrc.0

ip -4 addr show usb0
# 预期：192.168.68.1/24

systemctl status mobian-usb-gadget --no-pager | head -5
# 预期：active (exited)
```

宿主机（Windows）侧应出现一个新的 RNDIS 网卡，且能 `ssh user@192.168.68.1`。

### WiFi

```bash
iw dev                     # 或: ip link show wlan0
# 预期：wlan0 存在

nmcli device status
# 预期：wlan0  connected

nmcli -f GENERAL.STATE,GENERAL.CONNECTION dev show wlan0
ping -c3 223.5.5.5
```

`dmesg | grep -i wcn36xx` 应看到固件加载成功（`wcnss` / `pronto`），不应出现 `firmware: failed to load`。

## 7.5 交换

```bash
swapon --show
# 预期两行：
# /dev/zram0   partition  256M  100        ← zram，优先级高
# /swapfile    file       256M   10        ← 兜底

zramctl
# 预期：ALGORITHM=zstd, DISKSIZE=256M

cat /proc/sys/vm/swappiness
# 预期：100

cat /proc/sys/vm/page-cluster
# 预期：0
```

压力测试（可选，别在正式用的时候做）：

```bash
# 分配 300 MB 匿名内存，观察 zram 压缩是否生效
python3 -c "b=bytearray(300*1024*1024); print(len(b))" &
sleep 20; zramctl; swapon --show; wait
```

## 7.6 服务与日志

```bash
systemctl --failed
# 预期：0 units listed（空）

systemctl is-enabled systemd-networkd qrtr-ns getty@tty1 2>&1
# 预期：全部 disabled 或 masked（报 "Failed to get unit file state" 也可接受）

journalctl --disk-usage
# 预期：≤ 16M；且 /var/log/journal 为空（Storage=volatile）

df -h /
# 预期：约 559M 已用 / 974M 可用 / 约 350M 剩余
```

包一致性：

```bash
dpkg -C
# 预期：无输出

apt-get check
# 预期：0 broken

dpkg -l | grep -c '^ii'
# 预期：232
```

## 7.7 脚本清单

| 脚本 | 覆盖范围 |
|---|---|
| `scripts/device/device-verify.ps1` | 内核版本、设备树、modem 节点、模块加载 |
| `scripts/device/device-func-test.ps1` | 网络、WiFi、SSH、包状态 |
| `scripts/device/device-net-diag.ps1` | USB 网卡与 iproute2 |
| `scripts/device/verify-wifi-rootfs.sh` | rootfs 内 WiFi/USB gadget 模块与 vermagic |
| `scripts/rootfs/verify-rootfs-match.sh` | 模块目录与内核 ABI 一致性 |
| `scripts/flash/postboot-verify.sh` | 重启后完整验证 |
| `scripts/flash/post-flash-verify.ps1` | 刷机后验证 |

把上面 7.1–7.6 全跑一遍，或者直接跑 `postboot-verify.sh`。

---

上一步：[6. 刷写与回滚](06-flashing.md) · 下一步：[8. 运行维护](08-maintenance.md)
