# 6. 刷写与回滚

刷机只碰两个分区：`boot` 和根文件系统分区。`aboot`（lk2nd）不动 —— 动它是唯一会把设备变成真砖的操作。

## 6.1 前置条件

| 条件 | 说明 |
|---|---|
| Windows 侧有 `adb` + `fastboot` | 或用 WSL 里的 linux 版（需 `usbipd` 转发 USB） |
| 设备能进 fastboot | `adb reboot bootloader` |
| 目标镜像已校验 | 见 [5.6](05-boot-image.md#56-校验) |
| 备用 boot.img 在手 | `boot-sp970-current.img`（原样回退基准） |
| 心里有退路 | 见 [6.5](#65-救援通道) |

## 6.2 刷写流程

```bash
adb devices                      # 确认设备在线
adb reboot bootloader
fastboot devices                 # 确认进的是 fastboot，不是 EDL
```

先刷 boot，再刷 rootfs：

```bash
fastboot flash boot   boot-sp970-nomodrm.img
fastboot -S 200M flash rootfs rootfs-sp970-debian12-slim.img
fastboot reboot
```

**为什么 rootfs 要加 `-S 200M`**：这是 fastboot 的分块发送上限。大镜像一次发完容易在传输中途失败，分块后失败可重试，且不易撞上设备端缓冲区限制。

**为什么先 boot 后 rootfs**：boot.img 小、失败概率低。如果 boot 刷成功而 rootfs 失败，设备至少还能进系统看日志；反过来则可能两者都不对。

## 6.3 首次启动预期

1. 红灯心跳、蓝灯闪烁 —— 系统活着。
2. USB 口在 Windows 上枚举出新的 RNDIS 网卡，地址 `192.168.68.1`。
3. `ssh user@192.168.68.1` 登录（凭据是镜像内预置的，**首次登录后立即改密码并改用密钥**，见 [8.4](08-maintenance.md#84-凭据)）。
4. `uname -r` 应输出 `5.15.0-handsomekernel+`。

完整验收清单见 [7. 验收](07-verification.md)。

## 6.4 回滚

内核/根文件系统任意一个出问题，都可以单独回退。

**回退内核**（最常见，因为内核改动风险最高）：

```bash
fastboot flash boot boot-sp970-current.img
fastboot reboot
```

**回退根文件系统**：

```bash
fastboot -S 200M flash rootfs rootfs-sp970-debian12.img
fastboot reboot
```

原始镜像保留在：

| 文件 | 用途 |
|---|---|
| `D:\msm8916\out\boot-sp970-nomodrm.img` | 首个可用的去 modem boot.img |
| `D:\msm8916\out\rootfs-sp970-debian12.img` | 首个可用的 Debian 12 rootfs（306 MB，未精简） |
| `D:\msm8916\out-boot\boot-sp970-current.img` | 与当前可用系统配套的 boot.img（13,588,480 字节） |

**不要**在回退时顺便改 cmdline 里的 `PARTUUID`：镜像之间的分区 UUID 是同一个，改了必砖。

## 6.5 救援通道

按可靠性排序：

| 通道 | 前提 | 用途 |
|---|---|---|
| fastboot（lk2nd） | `aboot` 分区完好 | 刷 boot / rootfs，正常救援 |
| lk2nd fsboot | 某个分区上有文件系统且含 `boot.img` | lk2nd 会先扫标签为 `system`/`cache`/`userdata` 的分区找文件形式的 boot.img |
| WiFi SSH | 系统起来了但 USB 挂了 | 修 gadget、看 journal |
| 串口 `ttyMSM0` | 拆机引出 UART | 早期日志、shell |
| EDL（9008） | 高通 USB 描述符 | 最后手段，需要 QFIL/qdl + 签名 firehose |

**关键认知**：lk2nd 优先走 fsboot（文件系统里的 `boot.img`），失败才读 boot 分区。这意味着如果 boot 分区刷坏了，而某个数据分区里恰好留着一份可用 `boot.img`，设备仍可能起来 —— 但也意味着"我明明刷了新内核，怎么还是旧的"这类困惑，要先确认 lk2nd 到底从哪加载的。

## 6.6 关于 lk2nd（`aboot` 分区）

本项目的 lk2nd 用 ARM GNU Toolchain 13.3.rel1 编译（详见 [2.3](02-build-environment.md#23-两套工具链不要混用)），产物在 `D:\msm8916\out-gcc13\`：

| 文件 | 大小 |
|---|---|
| `lk2nd.img` | 397,328 |
| `lk.bin` | 303,124 |
| `lk2nd.tar` | 399,360 |
| `emmc_appsboot.mbn` | 375,564 |

**本项目没有把重编的 lk2nd 刷进设备** —— 设备当前的 lk2nd 已够用，而刷 `aboot` 一旦写坏就只能走 EDL。若确实要换：

```bash
fastboot flash aboot lk2nd.img
```

风险自负，且必须**先确认设备上现有 lk2nd 的可恢复映像**。

顺带说明一个容易误解的点：`lk2nd.img` 是 **32 位 ARM** 二进制，这不是错误，原因见 [1.3](01-hardware-and-boot-chain.md#13-32-位引导加载-64-位内核)。

## 6.7 OpenStick 分支的 rproc 开关

设备上的 lk2nd 若来自 OpenStick 分支，会读 `/mnt/lk2nd_rproc_mode` 文件（值 `all` / `no-modem` / `none`），在启动时改 DTB 禁用对应 remoteproc 并删 rmem 节点。

注意它的作用范围：**只在 fsboot 路径生效**，且是"运行期改 DTB"。本项目的做法是在设备树源码层面把 modem 关死（见 [3.2](03-kernel.md#32-补丁做了什么)），因此**不依赖**这个开关，也不建议两者同时用 —— 出问题时无法判断是谁起的作用。

## 6.8 脚本索引

| 脚本 | 作用 |
|---|---|
| `scripts/flash/preflash-verify.sh` | 刷前严格校验（镜像内容、大小、DTB 节点） |
| `scripts/flash/post-flash-verify.ps1` | 刷后验证（rmtfs 移除、iproute2、WiFi、网络） |
| `scripts/flash/postboot-verify.sh` | 重启后完整验证 |
| `scripts/flash/final-verify.sh` / `final-check.ps1` | 最终完整验证 |

---

上一步：[5. 启动镜像](05-boot-image.md) · 下一步：[7. 验收](07-verification.md)
