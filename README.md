# OpenStick SP970 · Debian 12（去 modem 固件）

[![Platform](https://img.shields.io/badge/platform-MSM8916%20%2F%20aarch64-informational?style=flat-square)](#硬件)
[![Kernel](https://img.shields.io/badge/kernel-5.15.0--handsomekernel%2B-informational?style=flat-square)](#内核)
[![Debian](https://img.shields.io/badge/debian-12.15%20bookworm-A81D33?style=flat-square)](#根文件系统)
[![License](https://img.shields.io/badge/license-GPL--2.0-blue?style=flat-square)](LICENSE)

把一块 OpenStick SP970（Qualcomm MSM8916，512 MB 内存的 U 盘形态 ARM 主机）改造成一台**自编译内核、彻底移除 modem、运行 Debian 12** 的常驻小服务器。

本仓库包含完整开发流程：设备树补丁、内核裁剪、根文件系统精简与装配、启动镜像构建、刷写与回滚、验收清单、故障排查，以及过程中用到的全部脚本。**所有内容都在这一个仓库里** —— 内核补丁以 `patches/` 形式收录，不需要另外 fork 或第二个仓库。

## 目录

- [结果](#结果)
- [硬件](#硬件)
- [工作原理](#工作原理)
- [快速开始](#快速开始)
- [仓库结构](#仓库结构)
- [文档](#文档)
- [关键设计决策](#关键设计决策)
- [已知限制](#已知限制)
- [参与](#参与)
- [许可](#许可)

## 结果

| 项目 | 结果 |
|---|---|
| 内核 | 5.15.0-handsomekernel+，自编译，**modem 子系统关闭** |
| 系统 | Debian 12.15 bookworm arm64，systemd 252.39 |
| 内存策略 | zram（zstd，256 MB，pri 100）+ 256 MB swapfile（pri 10） |
| 根文件系统 | 303 MB 用户空间 + 256 MB swap，装进 1 GiB ext4 |
| 内核模块 | 321 编出 → **175 个发布**（删掉 146 个用不上的驱动） |
| 软件包 | 232 个，`dpkg -C` 干净，`systemctl --failed` 为空 |
| 启动镜像 | 13,588,480 字节；另有 8.6 MB / 6.7 MB 两个候选 |
| 失败单元 | 0 |

对比改造前：磁盘 655 MB → 303 MB，模块 325 → 175 个，释放 85 MiB 被 modem 固件占用的保留内存。

## 硬件

| 项目 | 参数 |
|---|---|
| SoC | Qualcomm MSM8916，4 × Cortex-A53（AArch64） |
| 内存 | 512 MB LPDDR3 |
| 存储 | eMMC，根分区 3.3 GB |
| 无线 | WCN36xx（SDIO） |
| 显示 | 无 |
| 有线 | 单个 USB 口：供电 + RNDIS 网卡 + ADB |
| 引导 | lk2nd（32 位 ARM）→ AArch64 内核（经 EL3 monitor 交接） |

设备没有显示输出，只有 LED 指示状态；因此一切操作都必须有独立于"正在动的通道"的退路 —— 详见 [1. 硬件与启动链](docs/01-hardware-and-boot-chain.md)。

## 工作原理

```
PBL/SBL → lk2nd (aboot, 32-bit) → scm_elexec_call (EL3) → Linux arm64
                                                              │
        boot.img = gzip(Image + 附加 DTB) + initramfs  ─────────┘
                                                              │
                                            root=PARTUUID=... → ext4 (Debian 12)
```

改动只落在三处：**设备树**（关 modem）、**内核配置**（裁驱动）、**根文件系统**（裁模块/包/服务，配 zram）。lk2nd 保持原样。

## 快速开始

前置：Linux 构建主机（本项目用 WSL2）、`adb`/`fastboot`、约 3 GB 空闲磁盘。

```bash
# 1. 打内核补丁并编译
git clone https://github.com/OpenStick/linux && cd linux
git am /path/to/patches/0001-*.patch
make O=build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs -j"$(nproc)"

# 2. 装配根文件系统（详见 docs/04-rootfs.md）
scripts/rootfs/build-newrootfs.sh
scripts/rootfs/rootfs-strip-modem.sh
scripts/rootfs/rootfs-slim.sh

# 3. 组装启动镜像
scripts/boot/build-boot-img.sh
scripts/boot/verify-boot-img.sh

# 4. 刷写
adb reboot bootloader
fastboot flash boot   boot-sp970-nomodrm.img
fastboot -S 200M flash rootfs rootfs-sp970-debian12-slim.img
fastboot reboot
```

> 刷机前请先读 [6. 刷写与回滚](docs/06-flashing.md) —— 特别是 `PARTUUID` 不可改、`aboot` 不要动这两条红线。

## 仓库结构

```
.
├── README.md
├── CHANGELOG.md
├── LICENSE                        GPL-2.0
├── .gitignore
├── docs/                          开发流程文档（按阶段编号）
│   ├── 01-hardware-and-boot-chain.md
│   ├── 02-build-environment.md
│   ├── 03-kernel.md
│   ├── 04-rootfs.md
│   ├── 05-boot-image.md
│   ├── 06-flashing.md
│   ├── 07-verification.md
│   ├── 08-maintenance.md
│   ├── 09-troubleshooting.md
│   └── 10-reference.md
├── patches/
│   └── 0001-arm64-dts-qcom-msm8916-handsome-openstick-disable-modem.patch
├── artifacts/
│   └── SHA256SUMS.txt            构建产物校验和（二进制不入库）
└── scripts/                      按流程阶段分组的脚本（索引见 scripts/README.md）
    ├── kernel/   内核：设备树、配置、模块一致性
    ├── rootfs/   根文件系统：装配、瘦身、装包、模块索引
    ├── boot/     启动镜像：组装与验证
    ├── flash/    刷写前后验证
    ├── upgrade/  Debian 11 → 12 升级
    └── device/   设备侧运维：USB gadget、WiFi、SSH、诊断
```

## 文档

| 章节 | 内容 |
|---|---|
| [1. 硬件与启动链](docs/01-hardware-and-boot-chain.md) | 规格、启动链、32 位引导 64 位内核的机制、分区、三个可用通道 |
| [2. 构建环境](docs/02-build-environment.md) | 目录约定、主机依赖、两套工具链、交叉环境下的 dpkg |
| [3. 内核](docs/03-kernel.md) | 设备树补丁逐行解释、配置要点、编译、模块一致性、待办 |
| [4. 根文件系统](docs/04-rootfs.md) | 装配流程、模块裁剪方法、zram+swap、服务裁剪、空间账本 |
| [5. 启动镜像](docs/05-boot-image.md) | boot.img 结构、DTB 附加、initramfs 处理、体积候选、校验 |
| [6. 刷写与回滚](docs/06-flashing.md) | 刷写命令与理由、回滚、救援通道、lk2nd 风险 |
| [7. 验收](docs/07-verification.md) | 逐条可执行的验收清单与预期输出 |
| [8. 运行维护](docs/08-maintenance.md) | 日常检查、发行版升级、内核更新、凭据、备份、红线 |
| [9. 故障排查](docs/09-troubleshooting.md) | 11 类真实故障的根因、验证命令与修复 |
| [10. 参考](docs/10-reference.md) | 版本、路径、配置摘录、体积账本、产物清单、待办 |

## 关键设计决策

下面几条是这套方案成立的原因，细节在各章展开。

**1. modem 在设备树层面关死，不靠运行期开关。**
删掉 `msm8916-modem.dtsi` 的 include、删掉 85 MiB 的 `mpss_mem` 保留内存、在板级把 `&mpss` / `bam-dmx` / `smd-edge` / `&memshare` 全部 `status = "disabled"`。早期尝试从 `msm8916.dtsi` 基文件删节点，会因标签被其他板级文件引用而让 `dtc` 直接失败 —— 保留节点、覆盖状态才是可维护的做法。

**2. 模块裁剪必须做依赖闭包校验。**
`modinfo -F depends` 逐项检查，冲突就中止。第一版差点因为保留 `v4l2-flash-led-class` 把整个 V4L2 核心拖回来。

**3. 根文件系统从设备导出后加工，而不是 debootstrap 重建。**
`libusbgx.so.2`、`gc`、`adbd` 都不在 dpkg 管理范围内，重建会丢掉唯一的 USB 通道。

**4. 512 MB 内存靠 zram 优先、swapfile 兜底。**
`swappiness=100` + `page-cluster=0` 是配合 zram 的关键：鼓励匿名页尽早压缩进内存，而不是等 eMMC 换页。

**5. 日志只进 tmpfs。**
eMMC 上攒 journal 既占空间又增加写放大，对一台无显示的设备没有收益。

**6. 每个改动都留了回退基准。**
原始 `boot.img`、原始 rootfs 镜像、未改动的内核树全部保留，任何一步坏掉都能 15 分钟内恢复。

## 已知限制

| 限制 | 说明 |
|---|---|
| 无显示输出 | 排障只能靠串口 / USB / WiFi |
| boot 分区真实容量未验证 | 设备离线，`fastboot getvar all` 也看不到；官方镜像头的 `bootsize` 不能作为上限依据 |
| 两个缩小版 boot.img 未上机 | `tiny-rd`（8.6 MB）与 `no-initrd`（6.7 MB）仍待验证 |
| 147 个 `=m` 模块永不发布 | 应在 config 中改为 `=n`，需重编 + WiFi 回归 |
| 重编的 lk2nd 未刷入设备 | 避免写坏 `aboot` 导致只能走 EDL |
| 镜像不可原地扩容 | 设备端无自动扩展机制 |

完整待办见 [10.9](docs/10-reference.md#109-待办)。

## 参与

- 硬件/内核问题请先查 [9. 故障排查](docs/09-troubleshooting.md)，那里覆盖了本项目实际踩过的全部坑。
- 提交补丁请遵循 Linux 内核的 `git format-patch` 格式，DT 改动单独成 commit，并在 commit message 里说明"为什么"（尤其是"为什么不删节点"这类决策）。
- 脚本改动请保持"先打印候选、再执行"的风格，破坏性操作必须可回滚。

## 致谢

内核与引导基于 [OpenStick/linux](https://github.com/OpenStick/linux) 与 [msm8916-mainline/lk2nd](https://github.com/msm8916-mainline/lk2nd)；设备树参考 [msm8916-mainline/linux](https://github.com/msm8916-mainline/linux)。Debian 系统来自 [Mobian](https://salsa.debian.org/Mobian-team) 的 msm8916 移植。

## 许可

[GPL-2.0](LICENSE)。内核补丁按其上游许可（GPL-2.0）分发。

---

[![](https://img.shields.io/badge/powered_by-dsh-4D6BFE?style=flat-square&logo=deepseek&logoColor=white)](https://github.com/deepseek-ai/deepseek-harness)
