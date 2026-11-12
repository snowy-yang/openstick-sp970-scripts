# 更新记录

本项目的版本按"一个可刷写的产物集"划分。每条记录都给出可验证的量化结果。

## [0.3.0] - 2026-11-12

**设备树精简：关掉板子上不存在的硬件，并把它们的预留内存还给系统。**

### 新增

- `patches/0002-arm64-dts-qcom-msm8916-handsome-openstick-disable-unused-peripherals.patch` —— 关闭 GPU（Adreno 306）、venus、两套 LPASS（`&lpass` / `&lpass_codec`）、PMIC 模拟 codec（`&wcd_codec`）、只服务它们的 `&apps_iommu` / `&gpu_iommu`，以及 modem 专用的 `smp2p-hexagon`。文档同时补上音频链路清点（内核 `# CONFIG_SOUND is not set`，rootfs 无 `snd*.ko`）与 PMIC 侧「基文件本就 disabled」的核对结果。
- 删除已无使用者的预留内存：`mpss_mem` 43 MB、`venus_mem` 5 MB、`mba_mem` 1 MB、`rmtfs` 0.875 MB、`rfsa` 0.125 MB、无名的 `reserved@86680000` 0.5 MB；同时用 `/delete-property/ memory-region` 断开 `&mpss` 子节点与 `&venus` 的引用，避免 `dtc` 悬空 phandle 报错。
- `boot-sp970-nomodrm-v2.img`（13,588,480 字节）与独立的 `msm8916-handsome-openstick-sp970.dtb`（47,301 字节），导出在 `D:\msm8916\out-boot\`。

### 变更

- 预留内存 **63.00 MB → 12.50 MB**，512 MB 的机器多出约 **50 MB** 可用 RAM；`wcnss` 的 6 MB 保留（WiFi 固件）。
- 修正文档里"补丁 1 释放了 85 MiB"的说法：85 MiB 是板级覆写值，删除后回落到基文件的 43 MiB，真正的回收发生在补丁 2。

### 验证

- `make qcom/msm8916-handsome-openstick-sp970.dtb` 编译通过；`dtc` 反编译确认目标节点全部 `disabled`、预留内存合计 12.50 MB、`mpss_mem` / `venus_mem` / `mba_mem` / `86800000` 全部消失。
- 新 boot.img 与旧镜像**同尺寸**（13,588,480），kernel/ramdisk/cmdline 未变，仅尾部 DTB 不同。
- **尚未上机验证**（设备离线）。

## [0.2.0] - 2026-11-11

**文档与仓库重构。** 目标是让项目能被别人独立复现，而不是一堆 bring-up 期间的临时脚本。

### 新增

- `docs/` —— 10 章开发流程文档，覆盖硬件与启动链、构建环境、内核、根文件系统、启动镜像、刷写回滚、验收、维护、故障排查、参考数据。
- `patches/0001-arm64-dts-qcom-msm8916-handsome-openstick-disable-modem.patch` —— 内核设备树补丁以标准 `git format-patch` 格式入库，不再依赖第二个仓库（`+21 / −17`，单文件）。
- `scripts/README.md` —— 全部 110 个脚本的分类索引与环境变量说明。
- `CHANGELOG.md`、`LICENSE`（GPL-2.0）、`.gitignore`。

### 变更

- 脚本从"根目录平铺 108 个文件"改为按流程阶段分组：`scripts/{kernel,rootfs,boot,flash,upgrade,device}`。
- `README.md` 重写为标准项目首页（结果、硬件、原理、快速开始、结构、文档索引、设计决策、限制）。
- `artifacts/SHA256SUMS.txt` 按产物目录分组并加上校验方式说明。
- 移除 `SP970-BUILD-NOTES.md`，内容并入 `docs/`（构建记录、USB 掉线复盘、升级与清理数据）。

### 安全

- 5 个脚本里硬编码的设备 SSH/sudo 口令改为从 `DEVICE_PASS` 环境变量读取（`ssh-quickcheck.sh`、`ssh-rebuild-gadget.sh`、`ssh-rebuild2.sh`、`ssh-rebuild3.sh`、`ssh-rebuild4.sh`）。
  **注意：历史提交里仍可见旧口令，使用该口令的设备请立刻更换。**

### 修复（含本次一并记录的前序工作）

- 删除 `mobian-setup-usb-network` 中对不存在设备 `wwan0qmi0` 的 `nmcli con add` —— modem 移除后 NetworkManager 每次开机都在尝试连接死设备。
- `dpkg --purge ppp qrtr`（两者 `Priority: optional` 且反向依赖为空）；保留 `nm-pppd-plugin.so`（属 network-manager 包）。
- 删除 `cpufreq_{conservative,ondemand,userspace}.ko`（默认 governor 是 `schedutil`）。

### 量化结果

| 指标 | 之前 | 现在 |
|---|---|---|
| 内核模块 | 325 | **175** |
| 已装软件包 | 234 | **232** |
| 根文件系统用户空间 | 332 MB | **303 MB** |
| 镜像内容 | 341 MB | **559 MB**（含 256 MB swapfile） |
| 失败单元 | 0 | 0 |
| 保留内存 | modem 占用 85 MiB | 已释放 |

## [0.1.0] - 2026-11-06

**首次可刷写产物。**

### 新增

- 内核设备树补丁：去掉 `msm8916-modem.dtsi` include 与 85 MiB `mpss_mem` 保留内存，板级 disable `&mpss` / `bam-dmx` / `smd-edge` / `&memshare`。
- 去 modem 的 `boot.img`（13,588,480 字节）：gzip `Image` + 附加 SP970 DTB + 官方 ramdisk（替换为新编模块、剔除 `qcom_bam_dmux` / `rpmsg_wwan_ctrl` / `rmnet`）。
- Debian 12.15 bookworm rootfs（从实机导出，1 GiB ext4，沿用原分区 UUID）。
- `lk2nd` 用 ARM GNU Toolchain 13.3.rel1 编译通过（系统 gcc 14.2.1 会报 47 个错误），源码零改动。

### 已知问题（当时未解决）

- 根文件系统仍有 325 个内核模块，其中大量与 SP970 无关。
- 未配置 swap，512 MB 内存下 systemd + NetworkManager 偏紧。
- 脚本平铺在仓库根目录。

[0.2.0]: https://github.com/snowy-yang/openstick-sp970-scripts/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/snowy-yang/openstick-sp970-scripts/releases/tag/v0.1.0
