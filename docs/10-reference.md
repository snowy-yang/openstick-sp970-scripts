# 10. 参考

集中存放散落在各章的硬数据：版本、路径、体积、配置片段、产物清单。改东西之前先在这里对一眼。

## 10.1 版本矩阵

| 组件 | 版本 / 值 |
|---|---|
| 设备 | OpenStick SP970 |
| SoC | Qualcomm MSM8916（4 × Cortex-A53，AArch64） |
| 内存 | 512 MB |
| 内核 | 5.15.0-handsomekernel+ |
| 内核源码 | OpenStick `linux`，分支 `sp970-disable-modem`，提交 `2a93e56b2` |
| 内核编译器 | `aarch64-linux-gnu-gcc` 15.2.0 |
| 引导 | lk2nd（32 位 ARM），ARM GNU Toolchain 13.3.rel1 |
| 发行版 | Debian 12.15 bookworm (arm64) |
| systemd | 252.39 |
| glibc | 2.36 |
| 构建主机 | WSL2 Ubuntu |

## 10.2 路径

| 路径 | 内容 |
|---|---|
| `/opt/msm8916/linux` | 内核源码 |
| `/opt/msm8916/build` | 内核 out-of-tree 构建目录 |
| `/opt/msm8916/modinst` | `modules_install` 暂存 |
| `/opt/msm8916/rootfs-slim/root` | rootfs 工作目录树 |
| `/opt/msm8916/bootwork` | boot.img 解包/组装 |
| `/opt/msm8916/rdcheck/root` | initramfs 精确解包 |
| `/opt/msm8916/toolchains` | 独立工具链 |
| `/mnt/d/msm8916/out` | 原始产物（Windows `D:\msm8916\out`） |
| `/mnt/d/msm8916/out-slim` | 精简 rootfs 产物 |
| `/mnt/d/msm8916/out-boot` | boot.img 候选 |
| `/mnt/d/msm8916/out-gcc13` | GCC 13.3 编出的 lk2nd |

## 10.3 关键配置摘录

### 内核 cmdline（写死在 boot.img 里）

```
earlycon root=PARTUUID=a7ab80e8-e9d1-e8cd-f157-93f69b1d141e \
console=ttyMSM0,115200 no_framebuffer=true rw
```

### `/etc/fstab`（除 swapfile 外没有别的条目）

```
/swapfile none swap sw,pri=10 0 0
```

### `/etc/default/zramswap`

```bash
ALGO=zstd
PERCENT=50
PRIORITY=100
```

### `/etc/sysctl.d/99-zram.conf`

```
vm.swappiness=100
vm.page_cluster=0
vm.vfs_cache_pressure=50
```

### `/etc/systemd/journald.conf`

```ini
Storage=volatile
RuntimeMaxUse=16M
RuntimeMaxFileSize=4M
Compress=yes
```

### 预留内存（补丁 1 + 补丁 2 之后）

| 区域 | 大小 | 用途 |
|---|---|---|
| `tz-apps@86000000` | 3.000 MB | TrustZone 应用 |
| `smem_region@86300000` | 1.000 MB | 共享内存（SMD/SMP2P，WiFi 需要） |
| `hypervisor@86400000` | 1.000 MB | EL2 |
| `tz@86500000` | 1.500 MB | TrustZone |
| `wcnss@8df00000` | 6.000 MB | WiFi 固件加载区（**不可删**） |
| **合计** | **12.500 MB** | 优化前 63.00 MB |

被删掉的：`mpss@86800000` 43 MB、`venus@8e500000` 5 MB、`mba@8ea00000` 1 MB、`rmtfs@86700000` 0.875 MB、`rfsa@867e0000` 0.125 MB、`reserved@86680000` 0.5 MB。

### 文件系统

| 项目 | 值 |
|---|---|
| 类型 | ext4 |
| 逻辑大小 | 1 GiB（974 MiB 可用） |
| 文件系统 UUID | `e92c62a7-390f-4edc-b36f-b71f931c5a21` |
| 分布格式 | Android sparse image |

## 10.4 内核配置要点

| 项 | 值 | 说明 |
|---|---|---|
| `CONFIG_EXT4_FS` | `y` | 挂 root |
| `CONFIG_MMC` / `MMC_BLOCK` / `MMC_SDHCI` / `MMC_SDHCI_MSM` | `y` | eMMC |
| `CONFIG_EFI_PARTITION` | `y` | 读 GPT |
| `CONFIG_DEVTMPFS` / `DEVTMPFS_MOUNT` | `y` | /dev |
| `CONFIG_BLK_DEV_INITRD` | `y` | 用 initramfs 时需要 |
| `CONFIG_QCOM_SMEM` / `QCOM_SMD_RPM` / `RPMSG*` | `y` | **WiFi 依赖，不可关** |
| `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL` | `y` | 因此可删 3 个 governor 模块 |
| `CONFIG_QRTR` / `QRTR_SMD` / `QCOM_SYSMON` | `y` | modem 专用，但已内置；见待办 |
| `CONFIG_NFC` / `CONFIG_PPP` | `m` | 同上 |

规模：`=y` 1277 / `=m` 282 / `not set` 2388；编译出 321 个 `.ko`，发布 175 个。

## 10.5 体积账本

| 项 | 字节 |
|---|---|
| `Image`（未压缩） | 16,031,752 |
| `vmlinux`（含符号） | 69,825,712 |
| boot.img（当前可用） | 13,588,480 |
| ├ boot image header | 2,048 |
| ├ kernel（gzip Image + DTB） | 6,680,576 |
| ├ ramdisk | 6,565,888 |
| └ 填充 | 339,968 |
| boot.img（tiny-rd 候选） | 8,658,944 |
| boot.img（no-initrd 候选） | 6,684,672 |
| lk2nd.img | 397,328 |
| rootfs 稀疏镜像 | ≈ 266 MB |
| rootfs 内容 | 559 MB / 974 MB |

## 10.6 产物清单

### `D:\msm8916\out-slim\`

| 文件 | SHA256 |
|---|---|
| `rootfs-sp970-debian12-slim.img`（sparse） | `f0fcb1dd762a1f62ec449957c011e318b2ea3d29d9c2db4d52e2ed09a41673f6` |
| `rootfs-sp970-debian12-slim.raw.img` | `ade8d6c5dab229408dcc4b84cc17bd91cb2bdd5f7fa381f795e0486ce5924fb9` |
| `rootfs-debian12-slim.tar.gz` | `f11d968f824d7d63aaf7cb5e1267fddcbdca05b40c627981a61986a239906e19` |

### `D:\msm8916\out-boot\`

| 文件 | 字节 | 状态 |
|---|---|---|
| `boot-sp970-current.img` | 13,588,480 | 与可用系统配套，回退基准 |
| `boot-sp970-nomodrm-v2.img` | 13,588,480 | 设备树优化（预留内存 12.5 MB），未上机验证 |
| `msm8916-handsome-openstick-sp970.dtb` | 47,301 | `v2` 里使用的设备树，可直接反编译比对 |
| `boot-sp970-tiny-rd.img` | 8,658,944 | 未上机验证 |
| `boot-sp970-noinitrd.img` | 6,684,672 | 未上机验证 |

### `D:\msm8916\out-gcc13\`

| 文件 | 字节 |
|---|---|
| `lk2nd.img` | 397,328 |
| `lk.bin` | 303,124 |
| `lk2nd.tar` | 399,360 |
| `emmc_appsboot.mbn` | 375,564 |

### `D:\msm8916\out\`（原始，未改动）

| 文件 | 说明 |
|---|---|
| `boot-sp970-nomodrm.img` | 首个可用的去 modem boot.img（13 MB） |
| `rootfs-sp970-debian12.img` | 首个可用的 Debian 12 rootfs（306 MB） |
| `rootfs-sp970-nomodrm.img` | Debian 11 旧版，备用（243 MB） |
| `lk2nd.img` | 设备原用 lk2nd（387 KB） |

## 10.7 设备实测状态

2026-11-05 在设备上取得的基线（用于回归比对）：

| 项目 | 值 |
|---|---|
| 发行版 | Debian 12.15 bookworm |
| 内核 | 5.15.0-handsomekernel+ |
| systemd | 252.39 |
| USB gadget | UDC `ci_hdrc.0`，`usb0` = 192.168.68.1 |
| WiFi | `wlan0` = 192.168.1.48，可上网 |
| 失败单元 | 0 |
| dpkg 一致性 | 无异常 |
| 磁盘 | 345 MB / 3.3 GB（11%） |
| 已装包 | 234（精简后 232） |

当前镜像的精简后数据：模块 175 个、包 232 个、镜像内容 559 MB / 974 MB。

## 10.8 已知限制

| 限制 | 说明 |
|---|---|
| 无显示输出 | `no_framebuffer=true`，排障只能靠串口/USB/WiFi |
| 512 MB 内存 | 必须依赖 zram + swapfile |
| 设备端无自动扩容 | 镜像多大就是多大 |
| boot 分区真实容量未知 | 官方镜像头的 `bootsize` 不能证明上限；设备离线未验证 |
| 两个 boot 候选未上机 | tiny-rd / no-initrd |
| 重编的 lk2nd 未刷入 | 避免写坏 `aboot` |
| 147 个 `=m` 模块永不发布 | 应改为 `=n`，需重编验证 |

## 10.9 待办

1. 把 147 个不发布的 `=m` 改成 `=n`，重编内核并复验 WiFi。
2. 关闭 `QRTR` / `QRTR_SMD` / `QCOM_SYSMON` / `NFC` / `PPP`，同样需要重编 + WiFi 回归。
3. 上机验证 `boot-sp970-noinitrd.img`（省 6.2 MB ramdisk，同时去掉 initramfs 维护成本）。
4. SSH 改为纯密钥登录。
5. 根文件系统挂载加 `noatime`（减少 eMMC 写放大）。
6. `zoneinfo` / `locale` 进一步按需精简（当前刻意保留）。

## 10.10 参考资料

- OpenStick 项目内核：[OpenStick/linux](https://github.com/OpenStick/linux)
- lk2nd 上游：[msm8916-mainline/lk2nd](https://github.com/msm8916-mainline/lk2nd)，启动说明见其 `Documentation/boot.md`
- mainline msm8916 设备树：[msm8916-mainline/linux](https://github.com/msm8916-mainline/linux)
- U-Boot 替代引导方案：[dragonboard410c.rst](https://github.com/u-boot/u-boot/blob/master/doc/board/qualcomm/dragonboard410c.rst)
- Debian bookworm 软件包索引：<https://deb.debian.org/debian/dists/bookworm/>

---

上一步：[9. 故障排查](09-troubleshooting.md) · 回到 [README](../README.md)
