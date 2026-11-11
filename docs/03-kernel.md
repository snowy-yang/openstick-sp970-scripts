# 3. 内核

目标是"能在这块板子上稳定跑、但完全不碰 modem 的 5.15 内核"。源码沿用 OpenStick 的 `linux` 分支（5.15 + handsomekernel 补丁集），本项目的改动只有**一个设备树补丁**。

## 3.1 改动范围

| 文件 | 改动 |
|---|---|
| `arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-common.dtsi` | +21 / −17 |
| 其余 | 无 |

补丁以标准格式存放在 [`patches/0001-arm64-dts-qcom-msm8916-handsome-openstick-disable-modem.patch`](../patches/0001-arm64-dts-qcom-msm8916-handsome-openstick-disable-modem.patch)，可直接 `git am`：

```bash
cd /opt/msm8916/linux
git am /path/to/patches/0001-*.patch
```

对应上游分支 `sp970-disable-modem`，提交 `2a93e56b2`。

## 3.2 补丁做了什么

三件事：

1. **删掉 `#include "msm8916-modem.dtsi"`** —— 该头文件一次性引入 mpss/hexagon、SMP2P、SMSM、BAM-DMUX 等整套 modem 传输节点。
2. **删掉 `mpss_mem` 保留内存**：

   ```dts
   mpss_mem: gps_mem: mpss@86800000 {
           reg = <0x0 0x86800000 0x0 0x5500000>;
           no-map;
   };
   ```

   `0x5500000` = 85 MiB。这是 modem 固件的 carveout，512 MB 内存里白留 85 MB 是奢侈的，禁用 modem 后应当还给系统。
3. **在板级显式 disable**，位置移到文件末尾：

   ```dts
   &mpss {
           status = "disabled";
           bam-dmx { status = "disabled"; };
           smd-edge { status = "disabled"; };
   };
   ```

   并保留 `&memshare { status = "disabled"; }`（memshare 是 QMI 服务，仅 GPS 相关；GPS 在 memshare 缺席或拒绝请求时都能工作）。

## 3.3 为什么是 disable，不是删除

早期尝试过"从 `msm8916.dtsi` 基文件里彻底删掉 modem 节点"，**这条路走不通**：

- `&mpss`、`&memshare` 这些标签被 `pm8916.dtsi`、`apq8016-sbc` 等其他板级文件引用，删节点会让 `dtc` 直接报错；
- 即使能编过，也会影响同 SoC 的其他板子，属于破坏上游兼容性。

正确做法是**保留节点定义、在板级覆盖 `status`**。这也是上游推荐姿势，补丁因此只有 38 行改动。

## 3.4 配置要点

构建目录 `O=/opt/msm8916/build`，基线 `.config` 取自 handsomekernel 的 msm8916 配置，改动后 `make olddefconfig`。

规模：`=y` 1277 项 / `=m` 282 项 / `not set` 2388 项。

### 必须为 `=y`（否则挂不上 root）

逐项核对过，缺一不可：

```
CONFIG_EXT4_FS=y
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_MSM=y
CONFIG_EFI_PARTITION=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_BLK_DEV_INITRD=y   # 只有用到 initramfs 时才需要，见第 5 章
```

### 不能动的（WiFi 依赖链）

wcn36xx 走 `RPMSG` + `SMD` + `SMEM` 与固件通信，下列项即使在"去 modem"重构中也**必须保留**：

```
CONFIG_QCOM_SMEM          CONFIG_QCOM_SMD_RPM
CONFIG_RPMSG*             CONFIG_QCOM_Q6V5
CONFIG_QCOM_WCNSS_PIL     CONFIG_WCNSS_CTRL
CONFIG_QCOM_COMMON        CONFIG_QCOM_PIL_INFO
CONFIG_MDT_LOADER         CONFIG_QCOM_APR
```

模块侧（rootfs 里，见 [4.3](04-rootfs.md#43-内核模块集合)）：`wcn36xx`、`mac80211`、`cfg80211`、`lib80211*`。

### 仍是 `=m` 但已无意义（已知问题）

`CONFIG_QRTR=y`、`CONFIG_QRTR_SMD=y`、`CONFIG_QCOM_SYSMON=y`、`CONFIG_NFC=m`、`CONFIG_PPP=m` 都属于 modem/QMI 生态。设备上的 `qrtr`、`ppp` 软件包已被 purge，代码路径不会再被触发，但把它们改成 `=n` 需要重编内核并重新验证 WiFi —— 列入[待办](#37-已知问题与待办)，当前版本不动。

## 3.5 编译

```bash
cd /opt/msm8916/linux
make O=/opt/msm8916/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make O=/opt/msm8916/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs -j"$(nproc)"
make O=/opt/msm8916/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     INSTALL_MOD_PATH=/opt/msm8916/modinst modules_install
```

产物：

| 文件 | 大小 |
|---|---|
| `arch/arm64/boot/Image` | 16,031,752（15.29 MB，未压缩） |
| `arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-sp970.dtb` | 设备树 |
| `vmlinux` | 69,825,712（仅调试用） |

`Image` 进 boot 分区前必须 `gzip -9`，见 [5. 启动镜像](05-boot-image.md)。

## 3.6 模块与 rootfs 的一致性

内核和 rootfs 里的模块必须来自同一次编译：`vermagic` 不一致时 `insmod` 直接拒绝。检查：

```bash
uname -r                                   # 设备上：5.15.0-handsomekernel+
ls /lib/modules/                            # rootfs 里只有一个版本目录
```

`scripts/rootfs/verify-rootfs-match.sh` 用来做这件事：比对 rootfs 内模块目录与内核 ABI、并确认 modem 相关模块已移除。

一次编译产出 **321 个 `.ko`**，其中只有 **175 个**进入 rootfs。剩下 147 个属于"编了但永不发布"的死重量（netfilter 56、ledtrig 10、ppp 8、touchscreen 7、sound/soc 6、videobuf2 6、bluetooth 6、venus 3、nfc 4、f2fs/squashfs/ntfs3/fuse、staging/r8188eu、uvcvideo、cpufreq governor 3 个……）。它们不占镜像空间，但会拖慢编译、并让 `make modules_install` 的输出具有误导性。

## 3.7 已知问题与待办

| 项 | 状态 |
|---|---|
| 147 个 `=m` 模块永不发布 | 应在 config 中改为 `=n`，重编后复验 WiFi |
| `QRTR` / `QRTR_SMD` / `QCOM_SYSMON` 内置但无用 | 同上，需重编验证 |
| `NFC=m`、`PPP=m` | 同上 |
| 模块体积统计 | 不能用 `.o` 汇总推算 `Image` 节省（会混入模块对象） |

## 3.8 校验脚本

| 脚本 | 作用 |
|---|---|
| `scripts/kernel/verify-trim.sh` | 校验裁剪结果（配置项与产物） |
| `scripts/kernel/compare-modules.py` | 对比 ramdisk 官方模块与本地新编模块，列出缺失 |
| `scripts/kernel/check-depmod.sh` | 检查模块依赖索引是否自洽 |
| `scripts/kernel/check-modem-status.py` | 反编译 DTB，确认各 modem 节点 `status` 为 disabled |
| `scripts/kernel/audit-size.sh` | 盘点体积大且对 SP970 无用的子系统 |

---

上一步：[2. 构建环境](02-build-environment.md) · 下一步：[4. 根文件系统](04-rootfs.md)
