# 1. 硬件与启动链

理解启动链是改内核和刷机的前提。SP970 的启动路径比普通 x86 机器多两级、且跨越 32/64 位边界，这一节先把这条路径讲清楚。

## 1.1 设备规格

| 项目 | 参数 |
|---|---|
| 型号 | OpenStick SP970（U 盘形态的 ARM 主机） |
| SoC | Qualcomm MSM8916（4 × ARM Cortex-A53，64 位） |
| 内存 | **512 MB** LPDDR3 |
| 存储 | eMMC，其中根文件系统分区 3.3 GB |
| 无线 | WCN36xx（`wcnss` / `pronto` 固件），SDIO 接口 |
| 显示 | 无。`no_framebuffer=true`，无 HDMI/DSI 输出 |
| 有线 | 单个 USB 口，同时作为**供电 + 数据**，以 USB gadget 形式枚举成网卡 + ADB |
| 电源指示 | 心跳红灯常亮、蓝灯闪烁 —— 判断系统是否存活的第一手依据 |
| Cellular | 硬件有 modem 子系统（MSS），**本项目不使用**，见 [3. 内核](03-kernel.md) |

内存只有 512 MB 是所有取舍的根源：zram + swapfile 不是可选项而是默认配置（见 [4. 根文件系统](04-rootfs.md#44-内存与交换zram--swapfile)）。

## 1.2 启动链

```
 上电
  │
  ├─ PBL / SBL（SoC 内部 ROM + 高通签名二级引导，不可改）
  │
  ├─ aboot 分区  ──►  lk2nd（开源二级引导，32 位 ARM 代码）
  │                     │
  │                     ├─ 读 /mnt/lk2nd_rproc_mode（OpenStick 分支特性）
  │                     │     all / no-modem / none → 启动时改 DTB、删 rmem
  │                     │
  │                     └─ 选内核来源
  │                           ① fsboot：扫描标签为 system/cache/userdata 的分区，
  │                              找其上的 boot.img（优先）
  │                           ② 回退：读 boot 分区里的 boot.img
  │
  ├─ 32 位 → 64 位交接（关键，见 1.3）
  │
  ├─ Linux arm64 内核 + boot.img 里附加的 DTB
  │     cmdline: earlycon root=PARTUUID=... console=ttyMSM0,115200 \
  │              no_framebuffer=true rw
  │
  ├─ initramfs（initramfs-tools 生成，提供 /init、udev、模块加载）
  │
  └─ switch_root → /dev/mmcblk0pN 上的 Debian 12
```

`boot.img` 是 Android boot image 格式（v0 头 + 内核 + ramdisk + dtb 段），由 `abootimg` 组装，详见 [5. 启动镜像](05-boot-image.md)。

## 1.3 32 位引导加载 64 位内核

产物 `lk2nd.img` 是 **32 位 ARM**（`ELF 32-bit LSB executable, ARM, EABI5`），而被引导的内核是 **AArch64**。这不是配置错误，而是高通平台的软件遗产：lk2nd 派生自 Qualcomm LK/aboot，其 `arch/` 只有 `arm` 与 `x86` 两个目录。

跨位宽的交接由 EL3 安全监控器完成。`app/aboot/aboot.c` 中的分支：

```c
if (IS_ARM64(kptr))
        scm_elexec_call((paddr_t)kernel, tags_phys);   /* 交给 monitor */
else
        entry(0, machtype, tags);                      /* 直接跳 32 位入口 */
```

`platform/msm_shared/scm.c:1022` 的 `scm_elexec_call()` 把 `param.el1_x0 = dtb_offset; param.el1_elr = kernel_entry` 通过 SCM 调用送进 monitor，随后串口打印 `Jumping to kernel via monitor`。monitor 自己完成 EL2/EL1 的建立并跳入 AArch64 内核。

补充两点：

- 该路径的前提是 `is_scm_armv8_support()` 为真。若固件是纯 32 位，`target/msm8916/qhypstub_loader.c` 会打印 `32-bit firmware, cannot load qhypstub. Sad :(`，此时无法加载 qhypstub（AArch64 EL2 stub），SMP bring-up 会退化。
- `lk2nd/smp/spin-table.c` 中的 `qhypstub_set_state_aarch64()` 负责让各 CPU 通过 qhypstub 进入同一状态。

实践含义：**改内核不需要动 lk2nd**，两侧的 ABI 只有 boot image 格式 + DTB + cmdline。本项目因此把 lk2nd 保持为原厂/上游构建，只重编内核与 rootfs。

## 1.4 分区

设备上与本项目相关的分区只有三个：

| 分区 | 内容 | 本项目是否修改 |
|---|---|---|
| `aboot` | lk2nd 引导程序 | 不改（使用设备既有 lk2nd） |
| `boot` | Android boot image：内核 + DTB + initramfs | **重写** |
| 根文件系统分区（3.3 GB，GPT 标签以 `fastboot getvar all` / 设备上 `sgdisk -p` 为准） | ext4，Debian 12 | **重写** |

根分区**不靠 fstab 挂载**，而是由内核 cmdline 的 `root=PARTUUID=a7ab80e8-e9d1-e8cd-f157-93f69b1d141e` 指定；fstab 里除 swapfile 外没有任何条目。修改镜像文件系统 UUID 会导致无法启动 —— 本项目沿用原镜像的 UUID，见 [4.4](04-rootfs.md)。

`modem` 分区在硬件上存在，但本项目在设备树层面关闭了对应子系统，既不加载固件也不挂载，属于"存在但不使用"。

## 1.5 三个可用通道

| 通道 | 地址 | 用途 | 风险 |
|---|---|---|---|
| USB gadget 网卡（RNDIS） | `192.168.68.1` | SSH、ADB、文件传输 | **任何操作 gadget 的动作都会中断它**，见 [9.1](09-troubleshooting.md#91-usb-设备整机消失gadget-被拆除) |
| WiFi | DHCP，历史记录为 `192.168.1.48` | 与 USB 完全独立的主通道 | 需要已配置 WiFi 并记住 MAC 策略 |
| 串口 | `ttyMSM0`，115200 8N1 | 内核早期日志、救援 | 需要拆机引出 UART |

**WiFi 与 USB 的独立性是整套运维流程的安全带**：USB gadget 被误拆时，只能靠 WiFi 登录回去修。这也是 `scripts/device/ssh-rebuild*.sh` 系列脚本存在的原因。

---

下一步：[2. 构建环境](02-build-environment.md)
