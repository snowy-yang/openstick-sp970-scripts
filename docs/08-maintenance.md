# 8. 运行维护

一台没有显示器、靠 USB/WiFi 登录的 512 MB ARM 棒子，维护的重点不是"功能丰富"，而是**别把自己锁在门外**。

## 8.1 日常检查

```bash
# 一眼看健康
uptime; free -h; df -h /; systemctl --failed; zramctl

# 温度与频率
cat /sys/class/thermal/thermal_zone0/temp
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

# 谁在吃内存
ps -eo rss,comm --sort=-rss | head -10
```

内存紧的时候优先看 NetworkManager、wpa_supplicant、systemd-journald 三个进程；日志已改成 tmpfs（[4.6](04-rootfs.md#46-日志策略)），如果 `journalctl --disk-usage` 超过 16 MB，说明配置没生效。

## 8.2 发行版升级

从 Debian 11 升到 12 的完整过程（`scripts/upgrade/` 下按顺序执行）。**顺序不能乱**，尤其第 1 步。

### 步骤 1：装 bookworm 签名密钥

```bash
scripts/upgrade/step1-keys.sh
```

必须装 `debian-archive-keyring 2025.1`。老 keyring 里没有 bookworm 的签名密钥，不先换源+换密钥就 `apt update`，会得到满屏 `NO_PUBKEY`。

宿主机侧下载离线包：`scripts/upgrade/get-keyring.sh`。

### 步骤 2：处理失效的第三方源

`repo.mobian-project.org` 已返回 404（项目归档），必须禁用，否则 `apt update` 永远报错：

```bash
# 注释掉 /etc/apt/sources.list.d/ 里的 mobian 源
scripts/rootfs/fix-apt-source.ps1   # 同时顺手修正时区
```

### 步骤 3：升级前评估与加固

```bash
scripts/upgrade/upgrade-assess.sh        # 看变更规模
scripts/upgrade/upgrade-precheck.sh      # 将被移除的包、下载体积
scripts/upgrade/upgrade-safety-check.sh  # 确认 autoremove 不会误删 gadget 依赖
scripts/upgrade/pre-upgrade-harden.sh    # 确保 gadget 不会在升级/重启中丢失
```

第 3 个脚本是必须的：`apt autoremove` 是**唯一已知能把设备从总线上抹掉的操作**，事故复盘见 [9.1](09-troubleshooting.md#91-usb-设备整机消失gadget-被拆除)。

### 步骤 4：执行升级

```bash
scripts/upgrade/upgrade-main.sh     # 后台执行，日志落盘
# 或
scripts/upgrade/upgrade-safe.sh     # 升级后自动校验并修复 gadget
```

要点：保留现有配置文件（`--force-confold`），避免交互卡死。实测规模：**186 个包升级 + 34 个新增**。

### 步骤 5：升级后

```bash
scripts/upgrade/post-upgrade-check.sh
```

重点确认：gadget 还在、WiFi 还在、`dpkg -C` 干净、`systemctl --failed` 为空。升级会带来新的默认配置（例如 `systemd-networkd` 的 wants 链接可能被重新创建），需要重跑 [4.5](04-rootfs.md#45-systemd-服务裁剪) 的服务裁剪。

## 8.3 内核更新

改内核 → 重编 → 重组 boot.img → 刷。**rootfs 里的模块必须同步更新**，否则 `insmod` 会因为 vermagic 不匹配拒绝加载。

```bash
# 1. 编译（见 3.5）
# 2. 更新 rootfs 里的模块
# 3. 重组 boot.img（会自动用新模块覆盖 ramdisk 内的同名模块）
scripts/boot/build-boot-img.sh
# 4. 校验
scripts/boot/verify-boot-img.sh
# 5. 刷
fastboot flash boot boot-sp970-nomodrm.img && fastboot reboot
```

最小风险做法：**先只刷 boot，rootfs 不动**。但如果内核版本号变了（`5.15.0-handsomekernel+` → 别的），rootfs 里的 `/lib/modules/<ver>` 就找不到匹配目录，WiFi 会起不来 —— 这种情况下必须同时更新 rootfs 的模块目录，或者干脆改成用 `uname -r` 不变的命名。

## 8.4 凭据

- **SSH**：镜像内是预置的简单凭据，首次登录后立刻改密码，并改成密钥登录：

  ```bash
  ssh-keygen -t ed25519 -C sp970
  ssh-copy-id user@192.168.68.1
  # 确认密钥可用后再禁用密码
  sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo systemctl restart ssh.socket
  ```

- **WiFi PSK**：不要在脚本里硬编码。本仓库所有涉及 PSK 的脚本都从环境变量读：

  ```bash
  export WIFI_PSK='...'
  ```

  PowerShell 版本用 `$env:WIFI_PSK`。同理，SSH 密码从 `DEVICE_PASS` 读。

> 历史提醒：本仓库早期提交里曾出现过明文设备口令。若你的设备仍在用那个口令，**立刻改掉**。

## 8.5 备份

没什么可备份的（系统可从镜像重建），需要保住的只有配置：

```bash
# 配置快照
tar czf /tmp/sp970-etc-$(date +%F).tar.gz \
    /etc/NetworkManager /etc/systemd/network /etc/default/zramswap \
    /etc/sysctl.d /etc/fstab /etc/ssh

# 整机快照（体积大，走 WiFi 拉回）
ssh user@192.168.68.1 'sudo tar czf - --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/swapfile /' \
    > sp970-full-$(date +%F).tar.gz
```

宿主机侧保留一份"能启动的最小集合"：可用的 `boot.img` + 可用的 `rootfs.img`。这两样在手，任何软件层故障都能 15 分钟内恢复。

## 8.6 USB gadget 维护

gadget 是由 `mobian-usb-gadget.service` 在开机时"装配"出来的，不是一个常驻进程。装配动作包括 `gc -a rndis`、`gc -a ffs`、mount functionfs、启动 adbd、`gc -e`。

**任何执行 `gc -c`（删除 gadget）的操作都会让 ADB 立刻消失**，而后续重建又依赖 ADB —— 这是自锁。正确姿势：

```bash
# 从 WiFi 通道进入
ssh user@<wifi-ip>
sudo /usr/sbin/mobian-usb-gadget setup
```

若残留 adbd 占用 functionfs：

```bash
sudo pkill -9 adbd
sudo umount /dev/usb-ffs/adb 2>/dev/null
sudo gc -c; sleep 1
sudo /usr/sbin/mobian-usb-gadget setup
```

脚本：`scripts/device/mobian-gadget.sh`、`gadget-source.sh`（查清配置机制）、`test-gadget-rebuild.sh`（stop/start 验证）、`ssh-rebuild*.sh`（远程重建，迭代版本）。

## 8.7 WiFi 维护

换 MAC 会让某些路由器拒绝关联（`ASSOC-REJECT status_code=31`）。固定策略：

```bash
nmcli con modify <连接名> 802-11-wireless.cloned-mac-address stable
```

`scripts/device/wifi-stablemac.sh` 封装了这一步。其它常用：

| 场景 | 脚本 |
|---|---|
| 首次配置（用 `nmcli` 写文件，避免 shell 引号问题） | `wifi-setup.sh` |
| 密码存储异常、profile 建不起来 | `wifi-fix.sh` |
| 反复关联失败 | `wifi-retry.sh`、`wifi-nowps.sh`（关 WPS、清 PMKSA 缓存） |
| 诊断 | `wifi-diag2.sh`、`check-wifi-mods.sh` |

PowerShell 侧：`wifi-connect.ps1`（分步执行，避免密码出现在命令行历史）、`wifi-live-test.ps1`、`verify-wifi-fix.ps1`。

## 8.8 换固件/换工具链时的红线

| 红线 | 原因 |
|---|---|
| 不改根分区 PARTUUID | cmdline 里写死了它，改了必砖 |
| 不改文件系统 UUID | 同理（fstab 里只挂 swapfile） |
| 不删 `libusbgx.so.2` / `gc` / `adbd` | 不在 dpkg 里，删了 USB 通道就没了 |
| 不删 `libcrypto.so.1.1` | adbd 动态依赖 |
| 不刷 `aboot`，除非有 EDL 退路 | 写坏就是砖 |
| 镜像不要超过 1 GiB | 设备端不会自动扩容 |

---

上一步：[7. 验收](07-verification.md) · 下一步：[9. 故障排查](09-troubleshooting.md)
