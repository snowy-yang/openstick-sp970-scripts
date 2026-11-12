# 5. 启动镜像

`boot.img` 是 Android boot image 格式，`abootimg` 负责解包与生成。它由三部分组成：内核 + DT B + initramfs。

## 5.1 结构

```
偏移 0       ┌──────────────────────────┐
             │ boot image header (2048)  │   magic "ANDROID!"
             │  pagesize 2048            │   cmdline、kernel/ramdisk 大小与地址
             ├──────────────────────────┤
             │ kernel (zImage)           │   gzip -9 压缩的 arm64 Image + 附加 DTB
             ├──────────────────────────┤
             │ ramdisk (initrd.img)      │   gzip 压缩的 newc cpio
             ├──────────────────────────┤
             │ second stage              │   本项目为空
             ├──────────────────────────┤
             │ dtb                        │   本项目把 DTB 直接附在内核尾部
             └──────────────────────────┘
```

设备树不用 image 的 dtb 段，而是**追在内核二进制后面**（Qualcomm 传统做法）：内核解压时在自身尾部找 FDT magic `0xd00dfeed`。

## 5.2 内核：gzip 后的 Image + 附加 DTB

`arch/arm64/boot/Image` 是未压缩的 16 MB 原始镜像，不能直接塞进 boot 分区：

```bash
gzip -9 -c /opt/msm8916/build/arch/arm64/boot/Image > zImage-new
```

然后把 SP970 的 DTB 追加到尾部，**并先剥掉可能已存在的旧 DTB**：

```python
z = open("zImage-new", "rb").read()
i = z.rfind(b"\xd0\x0d\xfe\xed")     # FDT magic
if i > 0:
    z = z[:i]                        # 丢弃旧 DTB
open("zImage-new", "wb").write(z + new_dtb)
```

不剥就会得到"两个 DTB 叠加"，内核取最后一个 —— 表面上也能启动，但一旦两者不一致，排障会非常痛苦。

`abootimg -x` 解出来的内核是官方那个，**不能复用**，必须用自己编的 `Image`。

## 5.3 initramfs

原厂 ramdisk 被复用，但做了两件事：

1. **删掉 modem 相关模块**：`qcom_bam_dmux.ko`、`rpmsg_wwan_ctrl.ko`、`rmnet.ko`。
2. **用新编模块覆盖同名模块**，保证 `vermagic` 与内核一致（只覆盖 ramdisk 里已存在的，不新增）。

然后重建索引并打包：

```bash
depmod -b ramdisk_root 5.15.0-handsomekernel+
find . -not -path "./proc/*" -not -path "./sys/*" -print0 \
    | cpio -o -H newc --quiet --null | gzip -9 > initrd-new.img
```

`depmod` 在缺少 `vmlinux` 时会告警，属正常现象（只影响符号解析的提示，不影响依赖生成）。

ramdisk 内容统计：

| 项目 | 值 |
|---|---|
| 压缩后 | 6.26 MB |
| 解压后 | 16 MB |
| 文件数 | 163 |
| 模块 | 37 个 `.ko` |
| `/init` | initramfs-tools 生成的 POSIX shell 脚本 |
| 主要体积 | `libcrypto.so.1.1` 2.61 MB、`libc-2.31.so` 1.39 MB、`udevadm` 1.01 MB、`btrfs` 0.79 MB、`libzstd` 0.73 MB |

> 注：早期分析曾在 `/opt/msm8916/bootwork/irfsc` 上得出过"lib 9 MB / 解压 28 MB"的错误数字 —— 那是个把 `zImage`、`initrd.img` 也一起塞进去的合并临时目录。精确数据以 `rdcheck/root`（`abootimg -x` 后单独解包 ramdisk）为准。

## 5.4 生成

```bash
abootimg --create boot-sp970-nomodrm.img \
         -f bootimg.cfg \
         -k zImage-new \
         -r initrd-new.img
```

**两个坑：**

- `cmdline` 必须写成 `-c "cmdline=..."`，直接传裸字符串会报 `bad config entry`。
- `-k` 和 `-r` 都是必填，缺一个不生成。

cmdline 全文：

```
earlycon root=PARTUUID=a7ab80e8-e9d1-e8cd-f157-93f69b1d141e \
console=ttyMSM0,115200 no_framebuffer=true rw
```

| 参数 | 作用 |
|---|---|
| `earlycon` | 极早期就开串口控制台，内核崩了也能看到 |
| `root=PARTUUID=...` | 根分区靠这里指定，不靠 fstab |
| `console=ttyMSM0,115200` | 高通 UART |
| `no_framebuffer=true` | 无显示输出，省掉 fb 初始化 |
| `rw` | 根分区可写（fstab 里没有 remount 条目） |

## 5.5 体积现状与候选方案

当前可用镜像：

| 镜像 | 字节 | 组成 |
|---|---|---|
| `boot-sp970-nomodrm.img` | 13,588,480 | 2048 头 + kernel 6,680,576 + ramdisk 6,565,888 + 填充 339,968 |
| `boot-sp970-nomodrm-v2.img` | 13,588,480 | 同上，但尾部 DTB 换成[补丁 2](03-kernel.md#33-补丁-2关掉无用外设并回收预留内存)的版本（kernel 6,678,415 + DTB 47,301） |

两版的 kernel/ramdisk/cmdline 完全一致，唯一差异是追加在 `zImage` 尾部的设备树：`v2` 多关了 GPU / venus / 两套 LPASS / PMIC 模拟 codec / 两个 IOMMU，并把预留内存从 63.00 MB 降到 12.50 MB，**相当于给 512 MB 的机器多出约 50 MB 可用 RAM**（音频在补丁 2 之前就已经在内核层面不存在，见 [3.3](03-kernel.md#音频内核里根本不存在)）。`v2` 与 `boot-sp970-tiny-rd.img`、`boot-sp970-noinitrd.img` 是三个互不包含的候选，可以自由组合（组合时用同一个 DTB 即可）。

官方镜像头里有 `bootsize=0xcf5800`，但这个值**来自官方镜像自身，不能证明 boot 分区上限**。也就是说"分区只剩零余量"这个结论并不成立 —— 分区真实容量未验证（设备离线，`fastboot getvar all` 也看不到）。

为了给未来留余量，做了一组缩小候选（**均未上机验证**）：

| 镜像 | 字节 | 做法 |
|---|---|---|
| `boot-sp970-tiny-rd.img` | 8,658,944 | ramdisk 砍到 1,975,067：删 50 个模块文件、`btrfs`/`fsck.f2fs`/`dmsetup`/`lsblk`/`blkid`，再按 ELF `NEEDED` 闭包删 51 个库（省 8.78 MB）。保留 `/init`、`/scripts`、`/conf`、`sh`、`mount`、`run-init`、`udevadm`、`kmod`、`resize2fs` |
| `boot-sp970-noinitrd.img` | 6,684,672 | 90 字节空 cpio。内核找不到 `/init` 时走 `prepare_namespace()`，直接用 `root=PARTUUID` 挂载 |

两者的内核段与 cmdline 与可用镜像完全一致，唯一变量是 ramdisk。基于以下事实，`noinitrd` 在原理上是可行的：挂载 root 所需的一切都是内置的 —— `EXT4_FS`、`MMC`、`MMC_BLOCK`、`MMC_SDHCI`、`MMC_SDHCI_MSM`、`EFI_PARTITION`、`DEVTMPFS`、`DEVTMPFS_MOUNT`。

产物在 `D:\msm8916\out-boot\`，含 `README.md` 与 `SHA256SUMS.txt`。切换方式与回退方式见 [6. 刷写](06-flashing.md)。

## 5.6 校验

刷之前一定要验，因为刷错 boot.img 就等于砖（还有 lk2nd 的 fsboot 和 EDL 兜底，但不值得赌）：

```bash
scripts/boot/verify-boot-img.sh      # 解包，逐项核对内核/DTB/ramdisk/cmdline
scripts/flash/preflash-verify.sh     # 刷机前严格校验（含大小、magic、DTB 里的 modem 节点）
```

`verify-boot-img.sh` 会做这些检查：

- header magic 与 pagesize
- 内核是否为 gzip、解压后的 `Image` 是否含 `ARMd` magic（`0x644d5241` @ 0x38）
- 尾部 DTB 是否为 `d00dfeed`、`compatible` 是否含 `qcom,msm8916` 与 `handsome-openstick-sp970`
- ramdisk 解开后 `/init` 是否存在、`depmod` 索引里的模块名与内核版本是否匹配
- cmdline 与预期逐字比对

`scripts/kernel/check-modem-status.py` 则反编译 DTB，确认 `mpss`、`bam-dmx`、`smd-edge`、`memshare` 全是 `disabled`。

## 5.7 脚本索引

| 脚本 | 作用 |
|---|---|
| `scripts/boot/build-boot-img.sh` | 完整组装流程（含模块替换与 DTB 附加） |
| `scripts/boot/verify-boot-img.sh` | 解包核对 |
| `scripts/boot/export-artifacts.sh` / `export-final.sh` | 导出到 Windows 侧 |

---

上一步：[4. 根文件系统](04-rootfs.md) · 下一步：[6. 刷写与回滚](06-flashing.md)
