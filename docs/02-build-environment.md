# 2. 构建环境

所有构建都在 WSL2 (Ubuntu) 里完成。Windows 侧只承担产物存放与刷机。本文档里的路径按这个约定书写。

## 2.1 目录约定

WSL 侧：

```
/opt/msm8916/
├── linux/                内核源码（OpenStick/linux 的克隆，含 DTS 补丁）
├── build/                内核 out-of-tree 构建目录（.config、Image、dtb、.ko）
├── modinst/              内核模块安装暂存目录（make modules_install 的输出）
├── rootfs-slim/root/     待写入镜像的根文件系统（解包后的目录树）
├── bootwork/             boot.img 解包/组装的工作区
├── rdcheck/root/         initramfs 精确解包（分析用）
├── toolchains/           独立工具链（lk2nd 专用）
└── dump/                 从设备导出的 rootfs tar
```

Windows 侧（`D:\msm8916`，WSL 里是 `/mnt/d/msm8916`）：

```
D:\msm8916\
├── out\          原始产物：boot-sp970-nomodrm.img、rootfs-sp970-debian12.img、lk2nd.img
├── out-slim\     精简后的 rootfs 镜像 + tar + SHA256SUMS.txt
├── out-boot\     boot.img 候选镜像 + README + SHA256SUMS.txt
├── out-gcc13\    GCC 13.3 编出的 lk2nd 产物
├── debs\         离线 arm64 deb 包
└── openstick-sp970-scripts\   本仓库
```

脚本不硬编码 `D:`，一律用 `/mnt/d/msm8916/out` 这种 WSL 路径。若你的盘符不同，复制脚本后改表头变量即可。

## 2.2 主机依赖

```bash
sudo apt install -y \
    build-essential bc bison flex libssl-dev libelf-dev \
    gcc-aarch64-linux-gnu \
    qemu-user-static binfmt-support \
    e2fsprogs android-sdk-libsparse-utils abootimg \
    cpio gzip xz-utils python3 rsync
```

| 包 | 用途 |
|---|---|
| `gcc-aarch64-linux-gnu` | 交叉编译内核（本项目实测 15.2.0） |
| `qemu-user-static` + `binfmt-support` | 在 amd64 宿主机上执行 arm64 的 `postinst`/`dpkg`，是离线装配 rootfs 的关键 |
| `android-sdk-libsparse-utils` | `img2simg` / `simg2img`，生成 Android sparse 镜像 |
| `abootimg` | 解包与生成 Android boot image |
| `e2fsprogs` | `mke2fs`、`resize2fs`、`e2fsck`、`tune2fs` |

## 2.3 两套工具链，不要混用

内核用 Debian 打包的 `aarch64-linux-gnu-*`；lk2nd 用 ARM 官方 GNU Toolchain。**两者不可互换**。

### 内核：`aarch64-linux-gnu-gcc`

```
$ aarch64-linux-gnu-gcc --version
aarch64-linux-gnu-gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0
```

### lk2nd：ARM GNU Toolchain 13.3.rel1

系统自带的 `arm-none-eabi-gcc 14.2.1` **编不出 lk2nd**：GCC 14 把下面几个警告提升为默认错误，而 lk2nd 是老代码，实测 **47 errors**（44 个 `implicit-function-declaration`、3 个 `int-conversion`）。

```
-Wimplicit-function-declaration -Wimplicit-int -Wint-conversion
-Wincompatible-pointer-types -Wreturn-mismatch
```

因此改用 ARM 官方 13.3.rel1（GCC 13.3.1，解压约 994 MB），**不改一行源码**：

```bash
cd /opt/toolchains
curl -LO https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/\
arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz
tar -xf arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz
```

`scripts/kernel/link-eabi.sh` 是为 Debian 打包版 `arm-none-eabi-*` 建 `arm-eabi-*` 软链接用的；用 ARM 官方包时不需要。

## 2.4 编译 lk2nd 的两个坑

**坑 1：project 名必须是 `lk2nd-msm8916`，不是 `msm8916`。**
`msm8916` 是原厂 aboot 的 target，编出来是 `emmc_appsboot.mbn`，不产出 `lk2nd.img`。用错名字会得到"编译成功但没有 lk2nd.img"的假象。

**坑 2：产物会写到输出目录的上两级。**
`target/msm8226/tools/makefile` 系列里有：

```make
APPSBOOTHEADER_DIR := $(BOOTLOADER_OUT)/../..
```

所以 `BOOTLOADER_OUT` 必须把输出目录**再加深两级**才能完全隔离，否则 `emmc_appsboot.mbn` 会掉到别的目录里。

正确命令：

```bash
make TOOLCHAIN_PREFIX=/opt/toolchains/arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi/bin/arm-none-eabi- \
     BOOTLOADER_OUT=/opt/msm8916/lk2nd-build-gcc13/iso/out \
     lk2nd-msm8916 -j"$(nproc)"
# 0 error / 345 warnings
```

产物：`lk2nd.img`、`lk.bin`、`lk2nd.tar`、`emmc_appsboot.mbn`。导出见 `D:\msm8916\out-gcc13\`。

> 封装好的脚本：`scripts/kernel/build-lk2nd-gcc13.sh`（工具链缺失时自动下载，编完自检源码树是否干净）。

## 2.5 交叉环境下的 dpkg

rootfs 是 arm64，宿主机是 amd64，装包时 `postinst` 无法直接执行。本项目用 binfmt 透明执行 arm64 ELF：

```bash
sudo systemctl restart systemd-binfmt
# 验证
file /usr/bin/qemu-aarch64-static
echo ':aarch64:M::\x7fELF\x02\x01\x01\x00::/usr/bin/qemu-aarch64-static:' | \
    sudo tee /proc/sys/fs/binfmt_misc/register
```

在此之上用 `dpkg --root=/mnt/rootfs_rw --force-architecture ...` 离线安装 deb。若某包 `postinst` 仍然失败，`scripts/rootfs/fix-dpkg-state*.sh` 会把 dpkg 状态从异常拉回 `installed`（注意：`info/` 下的脚本名**不带架构后缀**）。

## 2.6 版本基线

| 组件 | 版本 |
|---|---|
| 构建主机 | WSL2，Ubuntu |
| 内核交叉编译器 | `aarch64-linux-gnu-gcc` 15.2.0 |
| lk2nd 交叉编译器 | ARM GNU Toolchain 13.3.rel1 (GCC 13.3.1) |
| 内核 | 5.15.0-handsomekernel+ |
| 目标系统 | Debian 12.15 bookworm，systemd 252.39，glibc 2.36 |

---

上一步：[1. 硬件与启动链](01-hardware-and-boot-chain.md) · 下一步：[3. 内核](03-kernel.md)
