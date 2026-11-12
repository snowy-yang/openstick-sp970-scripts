# 3. 内核

目标是"能在这块板子上稳定跑、但完全不碰 modem、也不为板子上不存在的硬件付账的 5.15 内核"。源码沿用 OpenStick 的 `linux` 分支（5.15 + handsomekernel 补丁集），本项目的改动只有**两个设备树补丁**，且都在同一个文件里。

## 3.1 改动范围

| 补丁 | 文件 | 改动 |
|---|---|---|
| [`0001`](../patches/0001-arm64-dts-qcom-msm8916-handsome-openstick-disable-modem.patch) 关掉 modem | `arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-common.dtsi` | +21 / −17 |
| [`0002`](../patches/0002-arm64-dts-qcom-msm8916-handsome-openstick-disable-unused-peripherals.patch) 关掉无用外设并回收预留内存 | 同一文件 | +61 / −1 |
| 其余 | 无 | — |

两个补丁都是标准 `git format-patch` 格式，可按顺序 `git am`：

```bash
cd /opt/msm8916/linux
git am /path/to/patches/000*.patch
```

对应上游分支 `sp970-disable-modem`，提交 `2a93e56b2`（补丁 1）与 `715e72041`（补丁 2）。

## 3.2 补丁 1：关掉调制解调器

三件事：

1. **删掉 `#include "msm8916-modem.dtsi"`** —— 该头文件一次性引入 mpss/hexagon、SMP2P、SMSM、BAM-DMUX 等整套 modem 传输节点。
2. **删掉板级对 `mpss_mem` 的 85 MiB 覆写**：

   ```dts
   mpss_mem: gps_mem: mpss@86800000 {
           reg = <0x0 0x86800000 0x0 0x5500000>;
           no-map;
   };
   ```

   `0x5500000` = 85 MiB。删掉这个覆写后，`msm8916.dtsi` 基文件里的定义（43 MiB）重新生效 —— 所以补丁 1 **只回收了 85 − 43 = 42 MiB**，剩下的 43 MiB 由补丁 2 处理。
3. **在板级显式 disable**，位置移到文件末尾：

   ```dts
   &mpss {
           status = "disabled";
           bam-dmx { status = "disabled"; };
           smd-edge { status = "disabled"; };
   };
   ```

   并保留 `&memshare { status = "disabled"; }`（memshare 是 QMI 服务，仅 GPS 相关；GPS 在 memshare 缺席或拒绝请求时都能工作）。

## 3.3 补丁 2：关掉无用外设并回收预留内存

SP970 是 USB 棒：没有屏幕、没有摄像头、没有扬声器/麦克风。这些控制器仍会在启动时探测、申请时钟与电源域，甚至等待永远不会到来的固件。补丁 2 把它们连同那个专属 IOMMU 一起关掉：

```dts
&soc {
        gpu@1c00000 { status = "disabled"; };   /* Adreno 306，无显示输出 */
};

&venus {                                        /* 视频编解码器 */
        status = "disabled";
        /delete-property/ memory-region;
};

&lpass_codec { status = "disabled"; };          /* WCD 数字 codec */
&wcd_codec   { status = "disabled"; };          /* PMIC 里的模拟 codec */
&apps_iommu  { status = "disabled"; };          /* 只服务 venus/mdss/camss */
&gpu_iommu   { status = "disabled"; };          /* 只服务 GPU */

/* modem 专用，补丁 1 起就没有对端了；wcnss 那组保留给 WiFi */
/ {
        smp2p-hexagon { status = "disabled"; };
};
```

`&lpass`（MI2S 音频控制器）在 `msm8916.dtsi` 里默认就是 disabled，是板级文件把它打开的，补丁 2 把它改回 `disabled`。

### GPU 为什么可以放心关

`gpu@1c00000`（Adreno 306）在这份内核里**本来就没有驱动**：`.config` 是
`# CONFIG_DRM_MSM is not set`，整个 DRM/MSM（freedreno）栈没编进内核。所以节点是
`okay` 还是 `disabled`，今天对功能没有区别 —— 但关掉能让设备树如实描述这块板的用途
（无显示输出），也省掉两个不会有人认领的节点和它专属的 `&gpu_iommu` 上下文。

真要启用 GPU（离屏渲染，因为这台机器没有任何显示接口），需要 `CONFIG_DRM_MSM=y`
（会连带 `CONFIG_CMA_SIZE_MBYTES=32`，从 512 MB 里划走 32 MB CMA 池）、Mesa 的
freedreno 驱动，并且明确要渲染给谁看。属于另开一摊的事，见 [3.8](#38-已知问题与待办)。

### 音频：内核里根本不存在

这块板没有喇叭也没有麦克风，所以音频不只是"关掉"，而是**整条链路都没有**：

| 层 | 状态 |
|---|---|
| 内核 sound 子系统 | `# CONFIG_SOUND is not set`、`# CONFIG_SOUNDWIRE is not set` —— `.config` 里连一条 `CONFIG_SND*` 都没有，rootfs 里也没有任何 `snd*.ko` |
| 声卡（`sound@7702000`） | `disabled`（板级文件原本就关着） |
| LPASS CPU DAI（`audio-controller@7708000`） | `disabled`（基文件默认关，板级文件曾打开，补丁 2 关回去） |
| WCD 数字 codec（`audio-codec@771c000`） | `disabled` |
| PMIC 模拟 codec（`audio-codec@f000`） | `disabled`，其父节点 `pmic@1` 本来就是 `disabled` |
| ADSP 音频服务（`q6afe`/`q6asm`/`q6adm`/`q6mvm`） | 随 `&mpss` 的 `smd-edge` 一起消失 |

也就是说补丁 2 之后，从设备树到内核镜像都不再有音频代码路径。

顺带清点 PMIC 侧那些「看着也该关」的节点，结论是**大部分在基文件里本来就是 `disabled`**，
板级不需要再写一遍：

| 节点 | 现状 | 说明 |
|---|---|---|
| `charger@1000`（`qcom,pm8916-lbc`） | 基文件已 `disabled` | 这块板没有电池 |
| `vm-bms@4000`（`qcom,pm8916-bms-vm`） | 基文件已 `disabled` | 电量计，同样因为无电池 |
| `extcon@1300`（`qcom,pm8941-misc`） | 基文件已 `disabled` | USB 检测走的是 GPIO extcon `usb-id` |
| `pwm@bc00`（`qcom,pm8916-pwm`） | 基文件已 `disabled` | 背光用，本机无显示 |
| `smp2p-hexagon` | **补丁 2 关闭** | 唯一真正需要动手的：modem 专用 SMP2P 通道 |
| `smp2p-wcnss` | 保留 | pronto 加载 WiFi 固件要用 |

内存侧，把已经没有使用者的 carveout 直接删掉：

```dts
/delete-node/ &mpss_mem;        /* 43 MiB：modem 固件区 */
/delete-node/ &mba_mem;         /*  1 MiB：modem boot loader */
/delete-node/ &venus_mem;       /*  5 MiB：视频编解码 */
```

`mpss_mem`、`mba_mem`、`venus_mem` 各自只被一个节点引用（`&mpss` 的两个子节点与 `&venus` 的 `memory-region`），所以补丁同时用 `/delete-property/ memory-region` 断开引用，`dtc` 才不会因为悬空 phandle 报错。另外两个无标签、无 compatible、无引用的区域也一并删掉：

```dts
/ {
        reserved-memory {
                /delete-node/ reserved@86680000;   /* 512 KiB，无使用者 */
                /delete-node/ rmtfs@86700000;      /* 896 KiB，Android rmtfs 专用 */
                /delete-node/ rfsa@867e0000;       /* 128 KiB，同上 */
        };
};
```

结果（`dtc -I dtb -O dts` 实测）：

| | 优化前 | 优化后 |
|---|---|---|
| 预留内存合计 | 63.00 MB | **12.50 MB** |
| 剩余条目 | tz-apps 3 / smem 1 / hypervisor 1 / tz 1.5 / reserved 0.5 / rmtfs 0.875 / rfsa 0.125 / mpss 43 / wcnss 6 / venus 5 / mba 1 | tz-apps 3 / smem 1 / hypervisor 1 / tz 1.5 / wcnss 6 |

**`wcnss_mem` 必须保留** —— 6 MiB 是 WiFi 固件的加载区，删了 wcn36xx 起不来。

## 3.4 为什么是 disable，不是删除

早期尝试过"从 `msm8916.dtsi` 基文件里彻底删掉 modem 节点"，**这条路走不通**：

- `&mpss`、`&memshare` 这些标签被 `pm8916.dtsi`、`apq8016-sbc` 等其他板级文件引用，删节点会让 `dtc` 直接报错；
- 即使能编过，也会影响同 SoC 的其他板子，属于破坏上游兼容性。

正确做法是**保留节点定义、在板级覆盖 `status`**；只有当节点确实只剩一个引用者、且引用点也一并清理时，才用 `/delete-node/` + `/delete-property/`（补丁 2 的 carveout 就是这么做的）。这也是上游的写法（`msm8916-longcheer-l8150.dts` 顶部同样用 `/delete-node/ &mpss_mem;`）。

## 3.5 配置要点

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

`CONFIG_QRTR=y`、`CONFIG_QRTR_SMD=y`、`CONFIG_QCOM_SYSMON=y`、`CONFIG_NFC=m`、`CONFIG_PPP=m` 都属于 modem/QMI 生态。设备上的 `qrtr`、`ppp` 软件包已被 purge，代码路径不会再被触发，但把它们改成 `=n` 需要重编内核并重新验证 WiFi —— 列入[待办](#38-已知问题与待办)，当前版本不动。

## 3.6 编译

```bash
cd /opt/msm8916/linux
make O=/opt/msm8916/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make O=/opt/msm8916/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs -j"$(nproc)"
make O=/opt/msm8916/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     INSTALL_MOD_PATH=/opt/msm8916/modinst modules_install
```

只改设备树时可以只编 DTB，几秒钟：

```bash
make O=/opt/msm8916/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     qcom/msm8916-handsome-openstick-sp970.dtb
```

产物：

| 文件 | 大小 |
|---|---|
| `arch/arm64/boot/Image` | 16,031,752（15.29 MB，未压缩） |
| `arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-sp970.dtb` | 47,301（优化前 47,692） |
| `vmlinux` | 69,825,712（仅调试用） |

`Image` 进 boot 分区前必须 `gzip -9`，DTB 追加在其尾部，见 [5. 启动镜像](05-boot-image.md)。

## 3.7 模块与 rootfs 的一致性

内核和 rootfs 里的模块必须来自同一次编译：`vermagic` 不一致时 `insmod` 直接拒绝。检查：

```bash
uname -r                                   # 设备上：5.15.0-handsomekernel+
ls /lib/modules/                            # rootfs 里只有一个版本目录
```

`scripts/rootfs/verify-rootfs-match.sh` 用来做这件事：比对 rootfs 内模块目录与内核 ABI、并确认 modem 相关模块已移除。

一次编译产出 **321 个 `.ko`**，其中只有 **175 个**进入 rootfs。剩下 147 个属于"编了但永不发布"的死重量（netfilter 56、ledtrig 10、ppp 8、touchscreen 7、sound/soc 6、videobuf2 6、bluetooth 6、venus 3、nfc 4、f2fs/squashfs/ntfs3/fuse、staging/r8188eu、uvcvideo、cpufreq governor 3 个……）。它们不占镜像空间，但会拖慢编译、并让 `make modules_install` 的输出具有误导性。

> 补丁 2 关掉的 gpu/venus/lpass 都是**内置驱动**（`=y`），不从 rootfs 删任何东西；它省的是启动路径和内存，不是模块文件。

## 3.8 已知问题与待办

| 项 | 状态 |
|---|---|
| 147 个 `=m` 模块永不发布 | 应在 config 中改为 `=n`，重编后复验 WiFi |
| `QRTR` / `QRTR_SMD` / `QCOM_SYSMON` 内置但无用 | 同上，需重编验证 |
| `NFC=m`、`PPP=m` | 同上 |
| `venus` / `lpass` 的驱动仍被编进 `Image` | 补丁 2 只是让它们不 probe；要真正省 `Image` 体积需改 `CONFIG_*`，需重编验证 |
| GPU 没有驱动（`# CONFIG_DRM_MSM is not set`） | 节点已 `disabled`，本来也没人 bind。要 GPU 需开 `DRM_MSM`（占 32 MB CMA），且本机无显示输出，只能离屏渲染 |
| 模块体积统计 | 不能用 `.o` 汇总推算 `Image` 节省（会混入模块对象） |

## 3.9 校验脚本

| 脚本 | 作用 |
|---|---|
| `scripts/kernel/verify-trim.sh` | 校验裁剪结果（配置项与产物） |
| `scripts/kernel/compare-modules.py` | 对比 ramdisk 官方模块与本地新编模块，列出缺失 |
| `scripts/kernel/check-depmod.sh` | 检查模块依赖索引是否自洽 |
| `scripts/kernel/check-modem-status.py` | 反编译 DTB，确认各 modem 节点 `status` 为 disabled |
| `scripts/kernel/audit-size.sh` | 盘点体积大且对 SP970 无用的子系统 |

---

上一步：[2. 构建环境](02-build-environment.md) · 下一步：[4. 根文件系统](04-rootfs.md)
