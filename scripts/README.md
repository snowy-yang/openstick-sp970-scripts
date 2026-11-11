# 脚本索引

按流程阶段分组，与文档章节对应。每个脚本都是独立可执行的 bash / PowerShell / Python 脚本，不做安装、不改动仓库外的东西（除非脚本内明确说明）。

```
scripts/
├── kernel/    内核源码层：设备树、配置、模块
├── rootfs/    根文件系统层：装配、瘦身、装包
├── boot/      启动镜像层：组装 boot.img
├── flash/     刷写与上机验证
├── upgrade/   发行版升级
└── device/    设备侧运维与诊断
```

## 环境变量

| 变量 | 用途 |
|---|---|
| `WIFI_PSK` | WiFi 预共享密钥，脚本不硬编码 |
| `DEVICE_PASS` | 设备 SSH/sudo 口令，脚本不硬编码 |

```bash
export WIFI_PSK='...'
export DEVICE_PASS='...'
```

PowerShell 版本读 `$env:WIFI_PSK` / `$env:DEVICE_PASS`。

## kernel — 内核：DTS 修改、配置裁剪、模块一致性

| 脚本 | 说明 |
|---|---|
| `audit-candidates.sh` | 统计候选裁剪项的体积收益 |
| `audit-detail.sh` | 深入分析哪些内建驱动可以关闭 |
| `audit-gains.sh` | 量化裁剪收益：Image 体积占比分析 |
| `audit-size.sh` | 盘点当前内核配置中体积大/对 SP970 无用的子系统 |
| `build-lk2nd-gcc13.sh` | Build lk2nd with an ISOLATED ARM GNU Toolchain (GCC 13.3), leaving the |
| `check-depmod.sh` | 挂载 rootfs.raw，用 `depmod -n` 空运行自检模块索引（不写盘） |
| `check-modem-status.py` | 检查反编译后的 dts 中各 modem 节点的 status""" |
| `compare-modules.py` | 对比 ramdisk 中官方模块与本地新编模块，列出缺失项""" |
| `drop-memshare.sh` | 移除 common dtsi 中残留的 &memshare 覆盖块（modem 相关） |
| `find-libelf.sh` | 查找 libelf1 的可用 arm64 包 |
| `fix-modindex.sh` | 清理 rootfs 中 modules.dep 等索引对已删除 modem 模块的残留引用 |
| `fix-modindex2.sh` | 用 host depmod 重建 rootfs 内模块索引（清理已删 modem 模块的残留条目） |
| `fix-modindex3.sh` | 清理 modules.order 中的已删模块记录，并做最终一致性校验 |
| `kernel-trim.sh` | 保守内核精简：仅关闭 SP970 上确定不存在的硬件对应驱动 |
| `link-eabi.sh` | 为 Debian 打包的 arm-none-eabi 工具链建立 lk2nd 期望的 arm-eabi-* 软链接 |
| `modem-disable-clean.sh` | 还原 msm8916.dtsi 基文件，改用正确方案： |
| `strip-modem-dtsi.sh` | 从 msm8916.dtsi 基文件中彻底移除 modem 相关节点： |
| `strip-modem.sh` | 为 SP970 构建去 modem 固件： |
| `verify-trim.sh` | 校验内核裁剪结果 |

## rootfs — 根文件系统：装配、瘦身、软件包、模块索引

| 脚本 | 说明 |
|---|---|
| `apply-rmtfs-iproute2.sh` | 在 rootfs 镜像中：purge rmtfs + 离线安装 iproute2 及其依赖 |
| `audit-rootfs-pkgs.sh` | 统计 rootfs 中具体可清理项 |
| `build-newrootfs.sh` | 用设备导出的 tar 构建新的 rootfs 镜像（Debian 12） |
| `check-iproute2-deb.sh` | 检查 iproute2 deb 的元信息与依赖 |
| `check-resize.sh` | 挂载镜像检查 fstab 与 resize2fs 相关单元，确认设备端无自动扩容 |
| `clean-apt-cache.sh` | 清 apt lists 缓存并禁用已 404 的 mobian 源（设备上执行） |
| `cleanup-analyze.sh` | 安全清理：先分析，不直接删 |
| `cleanup-final2.sh` | 第二轮清理：文档/locale/缓存 + 确认 libusbgx 完好 |
| `cleanup-mounts.sh` | 清理所有测试用 loop 挂载点 |
| `cleanup-run.sh` | 清理无用包与配置 |
| `cleanup-safe.sh` | 受控清理：删除候选包后立即验证 gadget，失败则自动回滚 |
| `cleanup-survey.sh` | 清理无用包与配置（升级后） |
| `compare-debian-pkgs.py` | SP970 rootfs vs Debian 12 (bookworm) arm64 archive — useful server |
| `dump-rootfs.sh` | 通过 ADB 从设备导出 rootfs 并打包成可刷镜像 |
| `export-tar.sh` | 从设备导出当前根文件系统为 tar（排除虚拟文件系统） |
| `fetch-deps.sh` | 下载 iproute2 及其缺失依赖的 arm64 deb |
| `finalize-iproute2.sh` | 在 QEMU 支持下正确完成 iproute2 |
| `finalize.sh` | 最终阶段：卸载 rootfs、重新稀疏化、验证、导出 |
| `fix-apt-source.ps1` | 修复 apt 源与时区，为升级 Debian 12 做准备 |
| `fix-dpkg-state.sh` | 修复 arm64 包在 amd64 宿主上的 postinst 执行失败，令 dpkg 状态回到正常 |
| `fix-dpkg-state2.sh` | 修正：postinst 文件实际名为 info/<pkg>.postinst（不带架构后缀） |
| `install-iproute2-force.sh` | 用 dpkg --root + --force-architecture 离线安装 arm64 包 |
| `purge-modem-pkgs.sh` | 挂载 rootfs.raw 并用 dpkg --root 清除 modem 相关软件包（arm64，无法 chroot） |
| `resize-1g.sh` | 将 rootfs 文件系统扩到合理余量（1GB），避免设备端空间告急且无自动扩展 |
| `rootfs-final-clean.sh` | 最终残留清理：polkit 策略、systemd mask 记录、headers 中的 modem 配置项 |
| `rootfs-rmtfs-iproute2.sh` | 在 rootfs 镜像中：1) purge rmtfs  2) 安装 iproute2 |
| `rootfs-slim.sh` | rootfs 瘦身：删除错装内核、headers、apt 缓存、locale/doc/man |
| `rootfs-slim2.sh` | 二次瘦身：/boot 与 package 数据库缓存 |
| `rootfs-strip-modem.sh` | 阶段1：以读写方式挂载 rootfs，删除所有 modem 相关固件/软件/服务 |
| `rootfs-verify-modem.sh` | rootfs 最终清理与校验 |
| `shrink-fs.sh` | 收缩 ext4 文件系统，使稀疏镜像真正变小 |
| `verify-iproute2-rmtfs.sh` | 验证 iproute2 与 rmtfs 移除结果 |
| `verify-rootfs-match.sh` | 校验 rootfs 内的模块目录与内核 ABI 一致性，并检查 modem 模块是否已移除 |

## boot — 启动镜像：组装与验证

| 脚本 | 说明 |
|---|---|
| `build-boot-img.sh` | 阶段2：构建去 modem 的 SP970 boot.img |
| `export-artifacts.sh` | 导出 SP970 去 modem 固件产物到 Windows 侧 D:\msm8916\out |
| `export-final.sh` | 导出最终 SP970 去 modem 固件包到 Windows 侧 |
| `verify-boot-img.sh` | 最终验证 boot.img 内容正确性 |

## flash — 刷写前后验证

| 脚本 | 说明 |
|---|---|
| `final-check.ps1` | 最终完整验证 |
| `final-verify.sh` | 最终完整验证 |
| `post-flash-verify.ps1` | 刷机后最终验证：rmtfs 移除、iproute2 安装、WiFi 与网络 |
| `postboot-verify.sh` | 重启后完整验证 |
| `preflash-verify.sh` | 刷机前严格校验 boot.img 内容 |

## upgrade — Debian 11 → 12 升级

| 脚本 | 说明 |
|---|---|
| `check-release-date.sh` | 从 InRelease 文件判断镜像源快照日期，排查"源过期" |
| `check-release2.sh` | 直接查看 apt 缓存中的 InRelease 文件日期 |
| `diag-mirror.sh` | 用 wget 直连测试 deb.debian.org 与 163 镜像可用性（设备上执行） |
| `get-keyring.sh` | 在宿主机下载 bookworm 的 debian-archive-keyring 包 |
| `post-upgrade-check.sh` | 升级后检查 |
| `pre-upgrade-harden.sh` | 升级前加固：确保 gadget 不会在升级/重启中丢失 |
| `step1-keys.sh` | 步骤1：安装 Debian 12 (bookworm) 签名密钥 |
| `test-mirrors.sh` | 在设备上测试各个 Debian 镜像源可用性 |
| `test-src-apt.sh` | 用 apt 自身测试镜像源（设备无 curl/wget） |
| `upgrade-assess.sh` | 升级前评估：查看将要变更的规模 |
| `upgrade-main.sh` | Debian 11 -> 12 主升级流程（后台执行，日志落盘） |
| `upgrade-precheck.sh` | 升级前详细检查：将被移除的包、内核相关包、下载体积 |
| `upgrade-safe.sh` | Debian 12 升级（安全版）：升级后自动校验并修复 USB gadget |
| `upgrade-safety-check.sh` | 升级前关键检查：确认 autoremove 不会误删 USB gadget 依赖 |
| `upgrade-step1-keys.sh` | Debian 11 -> 12 升级 步骤1：安装 bookworm 密钥、切换 apt 源 |

## device — 设备侧运维：USB gadget、WiFi、SSH、诊断

| 脚本 | 说明 |
|---|---|
| `check-gadget-tools.sh` | 检查 `gc` / `adbd` 是否存在、归属包与进程状态 |
| `check-wifi-mods.sh` | 挂载镜像，检查 WiFi 与 USB gadget 模块是否在 rootfs 内 |
| `detect-device.ps1` | 换线后检测设备是否出现 |
| `device-func-test.ps1` | 功能验证：网络、WiFi、SSH、软件包状态 |
| `device-net-diag.ps1` | 诊断 USB 网卡与 iproute2 |
| `device-qrtr-diag.ps1` | 诊断 qrtr 与 wifi 依赖（避免 PowerShell 变量展开） |
| `device-verify.ps1` | 设备端验证：内核版本、设备树、modem 节点、模块加载 |
| `diag-usb0.ps1` | 诊断 usb0 丢失 IPv4 地址 |
| `fix-qrtr-wifi.sh` | 修正：恢复 WiFi 所需的 QRTR |
| `gadget-source.sh` | 查清 USB gadget 配置机制 |
| `mobian-gadget.sh` | 打印 `mobian-usb-gadget.service` 内容及其调用的装配脚本 |
| `rebuild-qrtr.sh` | 重编内核并装入 strip 模块（QRTR 相关实验） |
| `serial-capture.py` | 抓取所有可用串口的输出，找启动日志/shell |
| `serial-probe.py` | 尝试各 COM 口，抓取是否有 Linux 控制台输出 |
| `ssh-fix-gadget.sh` | 通过 SSH 修复 USB gadget（设备当前 gadget 已被 reset 移除） |
| `ssh-quickcheck.sh` | 快速检查设备当前状态（超时保护） |
| `ssh-rebuild-gadget.sh` | 通过 SSH 重建 USB gadget |
| `ssh-rebuild2.sh` | 通过 SSH 重建 USB gadget（修正 sudo 提权方式） |
| `ssh-rebuild3.sh` | 方案：先把脚本写到设备，再用 sudo 执行 |
| `ssh-rebuild4.sh` | 清理残留 adbd 与 gadget 状态，然后重建 |
| `ssh-test.ps1` | 通过 SSH 做最终确认（不依赖 ADB） |
| `test-gadget-rebuild.sh` | 测试 gadget 重建流程（不重启，直接 stop/start 验证） |
| `verify-wifi-fix.ps1` | 验证 QRTR 恢复后 WiFi 是否工作 |
| `verify-wifi-rootfs.sh` | 确认 rootfs 中 WiFi/USB gadget 模块完好，且与新内核 vermagic 一致 |
| `watch-usb.ps1` | 实时监控 USB 插拔事件（监听 60 秒） |
| `wifi-connect.ps1` | 通过 nmcli 连接 WiFi（分步执行，避免密码在命令行被解析） |
| `wifi-diag2.sh` | wpa_supplicant / NetworkManager 日志诊断，并用 heredoc 传 PSK 激活 |
| `wifi-fix.sh` | 修复 NetworkManager WiFi 密码存储问题并激活 |
| `wifi-live-test.ps1` | WiFi 实际联网测试 |
| `wifi-nowps.sh` | 关闭 WPS，清理 PMKSA 缓存，重新连接 |
| `wifi-perm.sh` | 检查并修复 nmconnection 文件权限（必须 600 root） |
| `wifi-retry.sh` | 重新扫描 AP 并重连指定 SSID，输出信号强度 |
| `wifi-setup.sh` | 用 nmcli 写文件方式配置 WiFi，避免 shell 引号问题 |
| `wifi-stablemac.sh` | 使用稳定 MAC 地址策略重连 WiFi |

## 约定

- 脚本里的路径以 `/opt/msm8916/...`、`/mnt/d/msm8916/...` 为默认值，盘符不同时改文件头变量。
- 同名前缀带数字的是**迭代版本**（如 `fix-modindex.sh` / `2` / `3`、`ssh-rebuild2.sh` / `3` / `4`），后者覆盖前者，保留是为了保留当时的排查过程。
- 涉及删除的操作脚本（`cleanup-*`、`rootfs-slim*`、`purge-*`）都会先打印候选再执行，`cleanup-safe.sh` 还有失败自动回滚。

