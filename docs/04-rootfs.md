# 4. 根文件系统

这一章是整个项目工作量最大的部分：把一台 Debian 11 的棒子升级成 Debian 12、去掉 modem 相关的一切、砍掉用不到的驱动与服务、再针对 512 MB 内存把交换策略调好，最后装成可刷写的 ext4 镜像。

## 4.1 来源与基线

根文件系统不是从零 debootstrap 出来的，而是**先从设备导出、再离线加工**。原因很简单：设备的 USB gadget、ADB、`libusbgx` 等关键组件不在 dpkg 管理范围内，debootstrap 重建反而会丢掉它们。

```
设备上已有系统
   │  scripts/rootfs/export-tar.sh      （排除 /proc /sys /dev 等虚拟文件系统）
   ▼
rootfs-debian12.tar.gz  (≈ 90 MB)
   │  scripts/rootfs/build-newrootfs.sh
   ▼
1 GB ext4 raw 镜像 → img2simg → 可刷写的 sparse 镜像
```

加工后的目录树暂存在 `/opt/msm8916/rootfs-slim/root/`，所有清理脚本都 `mount` 这个目录（或直接改目录，最后统一装镜像）。

基线版本：

| 组件 | 版本 |
|---|---|
| 发行版 | Debian 12.15 bookworm (arm64) |
| systemd | 252.39 |
| glibc | 2.36 |
| 内核 | 5.15.0-handsomekernel+ |

Debian 11 → 12 的升级过程单独成章，见 [8.2](08-maintenance.md#82-发行版升级)。

## 4.2 镜像格式与 UUID

| 项目 | 值 |
|---|---|
| 文件系统 | ext4 |
| 逻辑大小 | 1 GiB（974 MiB 可用） |
| UUID | `e92c62a7-390f-4edc-b36f-b71f931c5a21` |
| 分发格式 | Android sparse image（`img2simg`），刷机时用 `fastboot -S 200M flash ...` |

**两条硬约束：**

1. **UUID 不能变。** 内核 cmdline 用 `root=PARTUUID=a7ab80e8-e9d1-e8cd-f157-93f69b1d141e` 指定根分区（这是**分区** UUID，不是文件系统 UUID），而 `/etc/fstab` 里除 swapfile 外没有任何条目 —— 也就是说根分区的挂载完全依赖 cmdline。换镜像时必须沿用原有分区表，或同步修改 boot.img 的 cmdline。
2. **设备端不会自动扩容。** `resize-1g.sh` 的注释写得很清楚：本机没有自动扩展机制。所以镜像做多大，设备上就是多大；不能在镜像里塞满数据指望首次启动时 `resize2fs`。

`scripts/rootfs/resize-1g.sh` 负责把文件系统调到 1 GiB 的合理余量，`scripts/rootfs/shrink-fs.sh` 负责反向收缩（让 sparse 镜像真正变小，而不是"看起来小"）。

## 4.3 内核模块集合

一次内核编译产出 321 个 `.ko`，rootfs 只需要 **175 个**。

### 裁剪方法：依赖闭包校验

不能按名字删。删除前对每个候选模块做反向依赖检查，任何冲突就中止：

```bash
# 对候选列表逐个求 depends，闭包中出现未在保留集合里的模块 → 拒绝删除
modinfo -F depends "<模块名>"
```

第一版就踩过：`leds-sgm3140` 依赖 `v4l2-flash-led-class`，而保留后者会把整个 V4L2 核心拖回来。结论是把 `sgm3140` 一起删（DTS 查证：本机 LED 走内置的 `gpio-leds`，无需该驱动）。

### 删掉了什么

| 类别 | 数量 | 理由 |
|---|---|---|
| netfilter 冷门匹配 | 49 | 只保留 NAT/过滤核心，见下表 |
| ledtrig | 10 | 无 LED 触发器使用场景 |
| ppp | 8 | 无拨号/PPPoE，`ppp` 软件包已 purge |
| touchscreen | 7 | 无屏幕 |
| sound codec | 6 | 无音频输出 |
| videobuf2 | 6 | 无摄像头 |
| bluetooth | 6 | 未使用蓝牙 |
| v4l2-core | 5 | 无摄像头 |
| md | 4 | 无软 RAID |
| venus | 3 | 视频编解码硬件，无显示输出用不上 |
| nfc | 4 | 无 NFC |
| 文件系统（fuse/squashfs/overlayfs/ntfs/ntfs3/f2fs/exfat） | 8 | 只用 ext4 |
| qrtr / qcom_q6v5_mss / qcom_memshare / cdc-wdm | 4 | modem 传输层 |
| usblp / usb_f_uvc / gud / vkms | 4 | 无打印、无摄像头、无显示 |
| staging r8188eu / r8712u | 2 | 板载是 wcn36xx，不是 USB WiFi |
| cpufreq governor（conservative / ondemand / userspace） | 3 | 默认 `schedutil`，无任何引用 |

### 保留了什么

- **WiFi 链路**：`wcn36xx`、`mac80211`、`cfg80211`、`lib80211*`、`qcom_wcnss_pil`、`wcnss_ctrl`、`qcom_q6v5`、`qcom_common`、`qcom_pil_info`、`mdt_loader`、`apr`、`pdr_interface`
- **内存与随机数**：`zram`、`rng-core`
- **netfilter 核心**：`nf_tables`、`nfnetlink`、`nf_conntrack`、`nf_nat`、`nf_defrag*`、`nf_log_syslog`、`nf_conncount`、`ip_tables`、`iptable_*`、`x_tables`、`nft_*`、`xt_conntrack`、`xt_nat`、`xt_MASQUERADE`、`xt_LOG`、`xt_state`、`xt_limit`、`xt_addrtype`、`xt_comment`、`xt_mark`、`xt_multiport`、`xt_tcpudp`、`xt_standard`、`xt_REDIRECT`、`xt_TCPMSS`、`xt_set`

### 陷阱：`depmod` 不生成 builtin 索引

```bash
depmod -b <root> <version>
```

只会写 `modules.dep`、`modules.alias`、`modules.symbols`。**`modules.builtin`、`modules.order`、`modules.builtin.modinfo` 不会被重建**。误删后 `modprobe` 会认为内置驱动不存在。恢复方式是从原始 tarball 里取回来 —— 注意路径是 `usr/lib/modules/<ver>/`（usrmerge 之后 `lib` 是指向 `usr/lib` 的符号链接），不是 `lib/modules/`。

恢复后自检：`modinfo ext4`、`modinfo usb_f_mass_storage`、`modinfo leds_gpio` 应显示 `(builtin)`；`modules.builtin` 应有 303 行。

### 陷阱：adbd 的 OpenSSL 依赖

`adbd` 的 ELF 动态段引用 `libcrypto.so.1.1`，看起来像 OpenSSL 3 时代遗留的孤儿库，**但它不能删** —— 删了 ADB 就没了，而 ADB 是救砖通道之一。

## 4.4 内存与交换：zram + swapfile

512 MB 物理内存，跑 systemd + NetworkManager + SSH 已经很紧，因此配了两级交换。

### zram（优先级 100）

`/etc/default/zramswap`：

```bash
ALGO=zstd
PERCENT=50
PRIORITY=100
```

`PERCENT=50` 取 512 MB 的一半 ≈ 256 MB，压缩算法 zstd（内核侧 `CONFIG_ZRAM` 为模块，`zramswap.service` 自带 `modprobe zram`，无需额外配置）。

### swapfile（优先级 10）

```bash
fallocate -l 256M /swapfile
chmod 600 /swapfile
mkswap /swapfile
```

`/etc/fstab` 追加：

```
/swapfile none swap sw,pri=10 0 0
```

即 **zram 优先，swapfile 兜底**：内存页先尝试压缩进 zram，压缩不掉的才落 eMMC。

### 内核参数

`/etc/sysctl.d/99-zram.conf`：

```
vm.swappiness=100
vm.page-cluster=0
vm.vfs_cache_pressure=50
```

- `swappiness=100`：在有 zram 的场景下，鼓励把匿名页尽早交给 zram（压缩比 eMMC 换页快几个数量级）。
- `page-cluster=0`：一次只换 1 页。zram 是随机访问设备，批量预读没有意义，反而放大内存占用。
- `vfs_cache_pressure=50`：更倾向于保留 dentry/inode 缓存，减少小文件反复回读 eMMC。

### 一个反直觉的结果

swapfile 是 `fallocate` 出来的，内容全零，**稀疏镜像因此反而更小**。但 512 MB 的 swapfile 会让镜像内容涨到 816 MB / 1 GB，只剩 91 MB 给系统 —— 所以最终定 256 MB。

## 4.5 systemd 服务裁剪

删掉 `.wants` 里的符号链接即可禁用（不 uninstall，保留可回滚）。

| 服务 | 为什么禁用 |
|---|---|
| `systemd-networkd.service` / `.socket` / `-wait-online.service` | 系统里只有 container/vm/veth/ad-hoc/6rd 模式的 `.network` 文件，本机没有任何匹配设备；网络由 NetworkManager 全权负责 |
| `qrtr-ns.service` | QIPCRTR 名字服务，纯 modem 生态 |
| `e2scrub_reap.service`、`e2scrub_all.timer` | 需要 LVM 快照，本机无 LVM |
| `getty@tty1.service` | 无显示输出 |

**保留**：NetworkManager、dnsmasq、wpa_supplicant、`mobian-usb-gadget`、`mobian-setup-usb-network`、`mobian-ssh-keygen`、netfilter-persistent、zramswap、systemd-timesyncd、systemd-pstore、`ssh.socket`、NetworkManager-wait-online、apt-daily 系列、dpkg-db-backup、fstrim 定时器。

### 一个真实的 bug 修复

`/usr/sbin/mobian-setup-usb-network` 里有一行：

```bash
nmcli con add con-name "modem" type gsm ifname "wwan0qmi0"
```

modem 移除后 `wwan0qmi0` 永远不会存在，NetworkManager 会反复尝试这条死连接。这行和对应的 `modem.nmconnection` 都已删除。**这类"删了硬件但没删配置"的残留，是重构里最容易漏的一类问题** —— 排查方法见 [9.5](09-troubleshooting.md#95-开机后-networkmanager-反复重试某个连接)。

## 4.6 日志策略

eMMC 上曾经攒了 18 MB journal（全是要被清理的旧日志）。`/etc/systemd/journald.conf`：

```ini
Storage=volatile
RuntimeMaxUse=16M
RuntimeMaxFileSize=4M
Compress=yes
```

日志只落 tmpfs，最多 16 MB，重启即清。对一台无显示、靠 SSH 排障的设备足够；真要留证据，接串口或用 `systemd-pstore`。

## 4.7 软件包

最终 **232 个包**。

### 移除 modem 生态

| 包 | 说明 |
|---|---|
| `rmtfs` | modem 的远程文件系统服务 |
| `qrtr` | QIPCRTR 工具与 `qrtr-ns.service`（含 `qrtr-cfg`/`qrtr-lookup`） |
| `ppp` | 无拨号需求；`ppp` 模块也已从 rootfs 删除 |

两者（`ppp`、`qrtr`）都是 `Priority: optional` 且**反向依赖为空**，可安全 purge。但要注意：`/usr/lib/pppd/2.4.9/nm-pppd-plugin.so` 归属 **`network-manager`** 包，不是 ppp 残留，删了会导致包不一致。

### 离线安装 iproute2

设备上原先没有 `iproute2`（`ip` 命令缺失），且 arm64 rootfs 不能直接 chroot 跑 apt。做法是用宿主机下载 arm64 deb，再 `dpkg --root` 强制架构安装：

```bash
dpkg --root=/mnt/rootfs_rw --force-architecture -i iproute2_*.deb ...
```

`postinst` 在 binfmt + qemu-user 下执行（见 [2.5](02-build-environment.md#25-交叉环境下的-dpkg)）。`debconf` 在依赖里是 `| debconf-2.0` 的可选项，rootfs 已有 debconf 1.5.77，可跳过。

相关脚本：`rootfs/rootfs-rmtfs-iproute2.sh`、`rootfs/fetch-deps.sh`、`rootfs/install-iproute2-force.sh`、`rootfs/finalize-iproute2.sh`。

### 不在 dpkg 管理内的组件（必须保留）

| 文件 | 作用 |
|---|---|
| `/lib/libusbgx.so.2` | USB gadget 核心库，**手工放置** |
| `/usr/bin/gc` | gadget 配置工具，手工放置 |
| `/usr/bin/adbd` | ADB 守护进程，手工放置 |
| `/usr/sbin/mobian-usb-gadget` + `.service` | gadget 装配脚本（属 `mobian-tweaks-common`） |
| `wcnss.*` 固件 9 个文件 | WiFi 固件 |

前三个不属于任何包，`apt autoremove`、`dpkg -S` 都查不到它们 —— 但它们是设备唯一的 USB 通道。清理脚本必须先确认它们完好再继续（`cleanup-safe.sh` 就是这么做的：删完立即验证 gadget，失败自动回滚）。

## 4.8 空间账本

| 阶段 | 占用 |
|---|---|
| 设备原始状态（Debian 11） | 655 MB |
| Deb 11→12 升级 + locale/doc/man/apt 缓存清理 | 345 MB |
| 内核模块精简（325 → 175 个 `.ko`，17 MB → 7 MB） | 332 MB |
| journal / qemu-aarch64-static / System.map / 零散日志 | 304 MB |
| **最终用户空间** | **≈ 303 MB** |
| `/swapfile` | 256 MB |
| **镜像内合计** | **559 MB / 974 MB**（余量约 350 MB，含 5% 保留块） |
| 分发稀疏镜像文件 | 266 MB |

清理明细：

| 项目 | 节省 |
|---|---|
| `/usr/share/locale`（保留 en/zh） | 44 MB |
| `/usr/share/doc` + man | 27 MB |
| apt 缓存与索引 | ~50 MB |
| journal | 18 MB |
| `/usr/bin/qemu-aarch64-static`（构建期工具，不属于任何包） | 6.4 MB |
| `/boot/System.map` | 3.6 MB |

**刻意没有删的东西**：perl 全家桶（约 55 MB）、`hwdb.bin`（12.4 MB）、zoneinfo、locale（en/zh 以外的确实删了，但保留这两个）。设备根分区 3.3 GB 只用了 11%，继续抠这几十 MB 没有收益。

`scripts/rootfs/compare-debian-pkgs.py` 会把当前包集合与 Debian 官方 bookworm arm64 索引（62,856 个包）对比，用于判断"还缺什么"。当前缺 `vim`/`nano`/`less`/`curl`/`wget` —— 需要时按需安装，不预置。

## 4.9 装配与产出

```bash
# 1. 准备目录树
scripts/rootfs/build-newrootfs.sh          # tar → 1 GB raw ext4（沿用 UUID）

# 2. 清理（顺序有依赖：先系统层，再模块层）
scripts/rootfs/rootfs-strip-modem.sh       # 去 modem 固件/服务
scripts/rootfs/rootfs-slim.sh              # 错装内核、headers、locale、doc、man
scripts/rootfs/rootfs-slim2.sh             # /boot 与 dpkg 缓存
scripts/rootfs/fix-modindex.sh             # 清理模块索引残留
scripts/rootfs/rootfs-final-clean.sh       # polkit 策略、mask 记录、headers 配置

# 3. 收尾：卸载、稀疏化、验证、导出
scripts/rootfs/finalize.sh
```

产物在 `D:\msm8916\out-slim\`：

| 文件 | 说明 |
|---|---|
| `rootfs-sp970-debian12-slim.raw.img` | 1 GB raw ext4 |
| `rootfs-sp970-debian12-slim.img` | sparse 镜像，用于 `fastboot flash` |
| `rootfs-debian12-slim.tar.gz` | 目录树 tar，便于二次加工 |
| `SHA256SUMS.txt` | 校验和 |

原始未改动的 `D:\msm8916\out\rootfs-sp970-debian12.img`（306 MB）始终保留，作为回退基准。

## 4.10 脚本索引

| 脚本 | 作用 |
|---|---|
| `build-newrootfs.sh` | tar → 镜像 |
| `dump-rootfs.sh` / `export-tar.sh` | 从设备导出 rootfs |
| `rootfs-strip-modem.sh` | 去 modem 固件/软件/服务 |
| `rootfs-slim.sh` / `rootfs-slim2.sh` | 两轮瘦身 |
| `rootfs-final-clean.sh` | 最终残留清理 |
| `fix-modindex.sh` / `fix-modindex2.sh` / `fix-modindex3.sh` | 模块索引一致性（迭代版本，后者覆盖前者） |
| `purge-modem-pkgs.sh` | `dpkg --root` 清除 modem 包 |
| `cleanup-safe.sh` | 受控清理 + gadget 验证 + 自动回滚 |
| `cleanup-analyze.sh` / `cleanup-survey.sh` / `cleanup-run.sh` / `cleanup-final2.sh` | 分级清理 |
| `resize-1g.sh` / `shrink-fs.sh` / `check-resize.sh` | 文件系统大小 |
| `finalize.sh` | 卸载、稀疏化、验证、导出 |
| `compare-debian-pkgs.py` | 与官方包索引对比 |

---

上一步：[3. 内核](03-kernel.md) · 下一步：[5. 启动镜像](05-boot-image.md)
