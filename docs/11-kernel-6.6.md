# 11. 内核 6.6 LTS 移植

5.15 的 `handsomekernel` 是厂商树（`OpenStick/linux`），能跑但离主线很远。这一章记录把它换到 **6.6 LTS 基线**的工作：基底用 `msm8916-mainline/linux` 的 `msm8916/6.6` 分支，板级设备树重写，配置重做，产物与 5.15 并存。

> **状态：已编译验证，未上机验证。** 设备离线，`boot-sp970-6.6-*.img` 只做了静态校验（DTB 反编译、模块依赖闭包、镜像结构）。刷机前请按 [6. 刷写与回滚](06-flashing.md) 准备好 `boot-sp970-nomodrm-v2.img` 这条退路。

## 11.1 为什么用 msm8916-mainline 的 `msm8916/6.6`

| 候选 | 结论 |
|---|---|
| `OpenStick/linux`（当前 5.15 树） | 厂商树，只有 5.15 一条线 |
| `msm8916-mainline/linux` `msm8916/6.6` | **选它**：专门维护 msm8916 的设备支持，6.6 是 LTS，已有的 ufi/uz801 板级文件说明这一类"U 盘形态"硬件的公共部分已被上游化 |
| 官方 `stable` 6.6 | msm8916 的 remoteproc/WCNSS/电源域支持不完整，板级要自己补一大截 |

`msm8916-mainline/linux` 的分支里还有 `msm8916/6.12`、`msm8916/6.17-rc6`、`old/msm8916/5.18` 等；选 6.6 是因为它是当前 LTS，且 `msm8916/6.6` 的板级支持（`msm8916-ufi.dtsi`、`msm8916-pm8916.dtsi`）已经能覆盖本机 90% 的硬件。

源码获取（浅克隆即可，编译不需要历史）：

```bash
git clone --depth 1 --single-branch --branch msm8916/6.6 \
    https://github.com/msm8916-mainline/linux.git /opt/msm8916/linux-6.6
```

```
1.8 GB，81,888 个文件
Makefile：VERSION=6 PATCHLEVEL=6 SUBLEVEL=0（6.6.0 基线）
```

## 11.2 6.6 与 5.15 的差异

**上游没有 OpenStick/Handsome 的板级文件。** 6.6 的 `arch/arm64/boot/dts/qcom/` 里只有同族的三块板：

| 文件 | 说明 |
|---|---|
| `msm8916-ufi.dtsi` | 147 行，UFI 形态 U 盘的公共部分（eMMC、串口、USB、WCNSS、LED/按键骨架） |
| `msm8916-thwc-ufi001c.dts` | 66 行，ufi-001b/001c |
| `msm8916-yiming-uz801v3.dts` | 35 行，uz801 v3.0 |

所以 SP970 的板级文件要自己写，但**公共部分可以照抄上游的写法**。标签在 6.6 里改过名，这是移植时最容易踩的地方：

| 5.15 标签 | 6.6 标签 | 备注 |
|---|---|---|
| `msmgpio` | `tlmm` | 引脚控制器 |
| `blsp1_uart2` | `blsp_uart2` | 调试串口 ttyMSM0 |
| `pronto` + 子节点 `iris` | `wcnss` + `wcnss_iris` | WiFi/蓝牙组合芯片 |
| `wcd_codec` | `pm8916_codec` | PMIC 模拟 codec |
| `smd_rpm_regulators` | `rpm_requests` 下的 `pm8916_rpm_regulators` | 6.6 的 `msm8916-pm8916.dtsi` 已经把常用电压写好了 |
| `gpu@1c00000`（无标签） | `gpu` | 6.6 才加的标签 |
| `msm8916-modem.dtsi` | `msm8916-modem-qdsp6.dtsi` | 内容重构（Q6V5 → QDSP6 命名），板级不再 include 它 |

另外三处结构性差异：

1. **预留内存节点默认 disabled。** 6.6 的 `msm8916.dtsi` 把 `mpss_mem`、`mba_mem`、`venus_mem`、`wcnss_mem`、`gps_mem` 全部写成 `status = "disabled"`，板级显式 `okay` 才预留（`msm8916-ufi.dtsi` 就是这么做的）。这比 5.15 那套 `/delete-node/` 干净得多 —— 而且核实过内核行为：`drivers/of/fdt.c:587` 的 `fdt_scan_reserved_mem()` 会跳过不可用的节点，`status = "disabled"` 的内存不会被预留。
2. **电压表不用再抄一遍。** 5.15 板级里那 60 行 `&smd_rpm_regulators` 全部删掉，`msm8916-pm8916.dtsi` 已给出 s3/s4/l2/l5/l6/l7/l8/l9/l11/l12/l13 的正确值与 always-on 需求。
3. **USB extcon 两种写法并存。** 上游 ufi 板用 `&pm8916_usbin`（PMIC 的 VBUS 比较器）；SP970 的硬件是 GPIO110 做 ID 检测，所以沿用 5.15 的 `linux,extcon-usb-gpio` 写法（`apq8016-sbc.dts` 也是这个写法，属于上游支持路径）。

## 11.3 板级设备树

两个文件，都放在 `arch/arm64/boot/dts/qcom/`，并在同目录 `Makefile` 里按字母序登记：

```
dtb-$(CONFIG_ARCH_QCOM)	+= msm8916-handsome-openstick-sp970.dtb
```

### `msm8916-handsome-openstick-common.dtsi`（148 行）

家族公共部分，只 include `msm8916-pm8916.dtsi`：

| 节点 | 状态 | 说明 |
|---|---|---|
| `blsp_dma` / `blsp_uart2` | okay | 串口控制台 `ttyMSM0`，115200 |
| `sdhc_1` | okay | eMMC（`vmmc`/`vqmmc` 由 pm8916 dtsi 给） |
| `usb` / `usb_hs_phy` | okay | `extcon = <&usb_id>, <&usb_id>`；PHY 供电 l7/l13 由 pm8916 dtsi 给 |
| `wcnss` | okay | WiFi 固件由 remoteproc 加载 |
| `wcnss_mem` | okay | **6 MB 必须显式打开**，否则 WCNSS 没有固件内存区 |
| `usb_id` | — | `linux,extcon-usb-gpio`，`id-gpio = <&tlmm 110 GPIO_ACTIVE_HIGH>` |
| `mpss` / `mpss_mem` / `mba_mem` | disabled | 没有 modem，也不加载固件 |
| `memshare` / `smp2p-hexagon` | disabled | 只服务 modem/ADSP |
| `bam_dmux` / `bam_dmux_dma` | disabled | modem 数据通道 |
| `gpu` / `gpu_iommu` / `apps_iommu` | disabled | 无显示，且内核没编 DRM_MSM |
| `venus` / `venus_mem` | disabled | 视频编解码器 |
| `lpass` / `lpass_codec` / `pm8916_codec` | disabled | 无音频输出 |

### `msm8916-handsome-openstick-sp970.dts`（86 行）

```dts
model = "Handsome OpenStick SP970";
compatible = "handsome,openstick-sp970", "handsome,openstick", "qcom,msm8916";
```

| 硬件 | GPIO | 定义 |
|---|---|---|
| 复位键 | 107（低有效） | `gpio-keys`，KEY_RESTART |
| WiFi 灯 | 28 | `blue:wifi`，默认触发器 `phy0tx` |
| 联网灯 | 10 | `green:internet` |
| 系统灯 | 9 | `red:os`，`heartbeat`，默认点亮 |
| USB ID | 110 | 在 common dtsi 里 |
| WiFi 芯片型号 | — | `&wcnss_iris { compatible = "qcom,wcn3660b"; };`（SP970 用 WCN3660B，不是 ufi 板的 WCN3620） |

## 11.4 关掉的东西省下多少内存

DTB 反编译实测（`dtc -I dtb -O dts`）：

| 预留内存 | 5.15 原始 | 6.6 本次 |
|---|---|---|
| `tz-apps` | 3.0 MB | 3.0 MB |
| `smem` | 1.0 MB | 1.0 MB |
| `hypervisor` | 1.0 MB | 1.0 MB |
| `tz` | 1.5 MB | 1.5 MB |
| `reserved@86680000` | 0.5 MB | 0.5 MB |
| `rmtfs` | 0.875 MB | 0.875 MB |
| `rfsa` | 0.125 MB | 0.125 MB |
| `mpss` | 43 MB | **关** |
| `mba` | 1 MB | **关** |
| `venus` | 5 MB | **关** |
| `gps` | — | **关** |
| `wcnss` | 6 MB | 6 MB（WiFi 要） |
| **合计** | **63 MB** | **14 MB** |

512 MB 的机器上多出 **49 MB** 可用 RAM。

验证方法：

```bash
dtc -I dtb -O dts msm8916-handsome-openstick-sp970.dtb | grep -A3 reserved-memory
# 上机后
grep -i reserved /proc/meminfo   # MemTotal 应比 5.15 多约 49 MB
```

## 11.5 内核配置

不要直接搬 5.15 的 `.config`（6.6 有大量符号改名与重构，`olddefconfig` 会静默丢东西）。做法是**以 `msm8916_defconfig` 为底，再叠一个功能片段**：

```bash
make O=/opt/msm8916/build-6.6 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- msm8916_defconfig
scripts/kconfig/merge_config.sh -m -O /opt/msm8916/build-6.6 \
    /opt/msm8916/build-6.6/.config arch/arm64/configs/msm8916-sp970.config
make O=/opt/msm8916/build-6.6 olddefconfig
```

片段 `arch/arm64/configs/msm8916-sp970.config` 补齐 `msm8916_defconfig` 没开的东西：

| 功能 | 关键符号 |
|---|---|
| 挂根文件系统 | `EXT4_FS=y`、`MMC_SDHCI_MSM=y`、`DEVTMPFS_MOUNT=y`、`EFI_PARTITION=y`、`BLK_DEV_INITRD=y` |
| USB gadget | `USB_CHIPIDEA=y`（`_UDC`/`_MSM`）、`USB_CONFIGFS=y` + `_F_FS`/`_MASS_STORAGE`/`_RNDIS`/`_ECM`/`_ACM`、`PHY_QCOM_USB_HS=y`、`EXTCON_USB_GPIO=y` |
| 防火墙 | `NF_TABLES=y` + `NF_NAT`/`NF_CONNTRACK`/`NFT_*`、`IP_NF_IPTABLES=y`、`IP6_NF_IPTABLES=y` |
| 内存压缩 | `ZRAM=m`、`CRYPTO_ZSTD=y`、`CRYPTO_LZ4=y` |
| VPN | `WIREGUARD=m` |
| WiFi | `WCN36XX=m`、`CFG80211=y`、`MAC80211=y` |
| 其它 | `LEDS_GPIO=y`、`KEYBOARD_GPIO=y`、`CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`、`SERIAL_MSM=y` |

最终统计：`=y` 1332 项、`=m` 289 项。注意 `CONFIG_WERROR` 在 6.6 里默认关闭，正好省掉 `aarch64-linux-gnu-gcc 15.2.0` 与新内核之间的告警摩擦。

版本串固定为 `6.6.0-sp970+`（`CONFIG_LOCALVERSION="-sp970"`，`LOCALVERSION_AUTO=n`）。

## 11.6 编译与产物

```bash
make O=/opt/msm8916/build-6.6 -j$(nproc) Image modules dtbs
```

| 项目 | 5.15（handsomekernel） | 6.6（本次） |
|---|---|---|
| `Image` | 16,031,752 | 16,449,544 |
| gzip 后 + 附加 DTB | 6,678,415 | **7,364,967** |
| 编译出模块 | 321 | 286 |
| 发布模块 | 175 | **69**（3.1 MB） |
| DTB | 47,301 | 50,525 |

12 核编译约 4 分 40 秒，0 error。

**为什么 6.6 的模块只有 69 个：** 网络防火墙、`cfg80211`/`mac80211`、`leds_gpio`、`usb_f_mass_storage` 这些在本次配置里是内置（`=y`），不再算模块；剩下的按 5.15 的同一套策略裁剪（触碰屏、传感器、蓝牙、NFC、DRM 面板、qdsp6 音频、venus 编码器等全部不发）。

## 11.7 启动镜像：13.59 MB 装不下完整 initramfs

`boot.img` 沿用官方镜像的 `bootsize = 0xcf5800`（13,588,480 字节）。6.6 内核变大后：

```
7,364,967（kernel + DTB）+ 6,565,671（原 initramfs）= 13,930,638
```

超出上限约 340 KB，**6.6 内核不能再和完整 initramfs 装在一起**。而完整 initramfs 里主要是 5.15 的模块和 glibc 库，对 6.6 本来也没用（模块版本不匹配）。于是给出两个能装下的方案：

| 镜像 | 大小 | initramfs | 适用 |
|---|---|---|---|
| `boot-sp970-6.6-tiny.img` | 13,588,480 | 1.88 MB（精简 initramfs，保留 `/init`、`/scripts`、`mount`、`udevadm`、`kmod`） | **推荐**，和 5.15 一样的启动路径 |
| `boot-sp970-6.6-noinitrd.img` | 13,588,480 | 90 字节空 cpio | 内核直接挂 `root=PARTUUID`，少一层但少了早期 fsck/udev |

两个镜像的内核和 cmdline 完全一致：

```
earlycon root=PARTUUID=a7ab80e8-e9d1-e8cd-f157-93f69b1d141e console=ttyMSM0,115200 no_framebuffer=true rw
```

组装方式与 5.15 相同（`gzip -9` 内核 → 追加 DTB → `abootimg --create`），脚本见 `scripts/kernel/build-kernel-6.6.sh`。

## 11.8 根文件系统：两套模块并存

`/lib/modules/` 下现在有两个目录，互不干扰，用哪个内核就加载哪个：

```
/lib/modules/5.15.0-handsomekernel+   175 个 .ko  ← 现有系统，回滚用
/lib/modules/6.6.0-sp970+              69 个 .ko  ← 新内核
```

6.6 模块目录的索引是完整的（`modules.dep` 69 行、`modules.builtin` 319 行、`modules.order` 69 行），`build`/`source` 这两个指向构建目录的符号链接已删除（在设备上只会是死链接）。

依赖闭包校验：逐个读 `modules.dep` 的 depends 字段，确认每个依赖要么在 69 个模块里、要么在 `modules.builtin` 里 —— 缺失 0 个。

镜像重建后：内容 562 MB / 974 MB，剩 345 MB，`swapon /swapfile` 复测通过。

## 11.9 上机验证清单

```bash
uname -r                                  # 期望 6.6.0-sp970+
cat /proc/meminfo | head -1               # MemTotal 应比 5.15 多约 49 MB
ls /lib/modules/                          # 两个目录
systemctl --failed                        # 空
ls /sys/class/udc/                        # ci_hdrc.0
ip -br addr                               # usb0 / wlan0
zramctl                                   # zram0 256 MB，算法 zstd
swapon --show                             # /dev/zram0 + /swapfile
dmesg | grep -iE "wcnss|remoteproc"       # 应看到 wcnss 启动，不应看到 mpss
```

**回滚**：`fastboot flash boot boot-sp970-nomodrm-v2.img` 回到 5.15。两套模块都在 rootfs 里，回滚不需要动根文件系统。

## 11.10 待办

- [ ] 上机验证（本机长期离线）
- [ ] 若 `boot-sp970-6.6-tiny.img` 报 `/init` 缺模块，改用 `noinitrd` 版本
- [ ] 把板级 DTS 提交到 `msm8916-mainline/linux` 上游（先补 `Documentation/devicetree/bindings/vendor-prefixes.yaml` 的 `handsome` 前缀 —— 6.6 里没有这个厂商前缀）
- [ ] 6.6 侧再评估 `CONFIG_DEBUG_INFO=n`、关掉不需要的内置子系统以缩小 `Image`