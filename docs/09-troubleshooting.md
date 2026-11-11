# 9. 故障排查

按"现象"查。每条都给出根因、验证命令、修复步骤。这些坑都是真实踩过的，包括两条判断错了才找到真因的。

## 9.1 USB 设备整机消失（gadget 被拆除）

**现象**：宿主机枚举不到任何 USB 设备，`adb devices` 空，但设备**红灯心跳、蓝灯闪烁** —— 系统还在跑。

**第一反应（错的）**：以为是 `apt-get autoremove --purge` 删了 `libgudev-1.0-0` 导致 gadget 失效。实测推翻：`apt-cache rdepends libgudev-1.0-0` 的反向依赖为空；`libusbgx`（gadget 核心库）根本不在 dpkg 管理里；后来重复执行同样的 autoremove，gadget 毫发无损。

**真因**：USB gadget 由 `mobian-usb-gadget.service`（属 `mobian-tweaks-common`）装配。其脚本执行 `gc -c`（删除 gadget）后需要重建，**而删除 gadget 会同时断开 ADB**。操作链依赖 ADB，一旦断开就无法执行后续 `setup`，gadget 就永久停在"已删除"状态 —— 自锁。

**验证**：

```bash
# Windows 侧
Get-PnpDevice -Class Net | Where-Object { $_.FriendlyName -match 'RNDIS|USB' }
# 没有任何新设备 → 确认是 gadget 侧问题，不是驱动问题

# 设备侧（靠 WiFi 或串口进去）
systemctl status mobian-usb-gadget --no-pager
ls /sys/class/udc/
gc -l        # 列出当前配置的 gadget，空说明被删了
```

**修复**（从 WiFi 通道进）：

```bash
ssh user@<wifi-ip>
sudo /usr/sbin/mobian-usb-gadget setup
```

若 adbd 端口冲突：

```bash
sudo pkill -9 adbd
sudo umount /dev/usb-ffs/adb 2>/dev/null
sudo gc -c; sleep 1
sudo /usr/sbin/mobian-usb-gadget setup
```

**教训**：

1. **不要在有线通道上执行会拆掉该通道的操作**，除非确认有独立备用通道（本例是 WiFi）。
2. `autoremove` 前先 `apt-cache rdepends` 核实，不要靠包名猜。
3. 判断系统是否存活优先看 LED，避免误判为硬件损坏。

## 9.2 WiFi 连不上：`ASSOC-REJECT status_code=31`

**现象**：重刷后 WiFi 连不上，`wpa_supplicant` 日志刷 `ASSOC-REJECT status_code=31`。

**根因**：`status_code=31` 是"关联被拒绝"。本例是**MAC 地址变化被路由器拒绝**（路由器开了 MAC 白名单/绑定）。重刷系统后 MAC 变了，与路由器记录的旧 MAC 不符。

**验证**：

```bash
journalctl -u wpa_supplicant -b | grep -i assoc-reject
ip link show wlan0 | grep ether          # 与路由器白名单里的地址比对
```

**修复**：

```bash
nmcli con modify <连接名> 802-11-wireless.cloned-mac-address stable
nmcli con up <连接名>
```

`stable` 表示"按连接名生成稳定 MAC"，重装系统/重启后保持一致。可选值还有 `random`、`permanent`（用硬件 MAC）。

## 9.3 `wlan0` 不存在 / 模块加载失败

**现象**：`ip link` 里没有 `wlan0`，`dmesg` 报 `Unknown symbol` 或 `version magic ... should be ...`。

**根因**（两类）：

1. **内核与模块不是同一次编译**：`vermagic` 不匹配，`insmod` 直接拒绝。改内核后没同步更新 rootfs 的 `/lib/modules/<ver>` 就会这样。
2. **模块被误删**：精简模块时删了 `wcn36xx` 或其依赖链（`mac80211`、`cfg80211`、`qcom_wcnss_pil`、`wcnss_ctrl`、`qcom_q6v5`、`mdt_loader`、`apr`、`pdr_interface`）。

**验证**：

```bash
uname -r
ls /lib/modules/
modinfo wcn36xx | head -5           # 看 vermagic 与 uname -r 是否一致
dmesg | grep -iE 'wcnss|wcn36xx|pronto'
modprobe wcn36xx && echo LOAD_OK
```

**修复**：

- vermagic 不匹配 → 更新 rootfs 模块目录到同一版本，或用 `scripts/rootfs/verify-rootfs-match.sh` 定位差异。
- 模块缺失 → 从 `make modules_install` 的输出（`/opt/msm8916/modinst`）取回对应 `.ko`，`depmod` 后 `modprobe`。
- 别忘固件：`/lib/firmware/wcnss.*` 共 9 个文件，删了同样起不来。

## 9.4 `apt update` 报 404 或 `NO_PUBKEY`

**404**：`repo.mobian-project.org` 已归档，返回 404。禁用该源：

```bash
sudo sed -i 's|^deb .*mobian.*|# &|' /etc/apt/sources.list.d/*.list
```

**NO_PUBKEY**：缺 bookworm 签名密钥。装 `debian-archive-keyring 2025.1`：

```bash
# 宿主机侧下载（设备可能没有 wget/curl）
scripts/upgrade/get-keyring.sh
# 设备侧安装后
sudo apt update
```

设备上没有 `curl`/`wget` 时，用 `scripts/upgrade/test-src-apt.sh` 借 `apt` 自身测镜像源连通性，用 `scripts/upgrade/test-mirrors.sh` 批量测。

## 9.5 开机后 NetworkManager 反复重试某个连接

**现象**：`journalctl` 里某个连接反复 `Activation: failed`；`nmcli con` 里有一条永远起不来的连接。

**根因**：硬件被移除、配置没删。本项目实测的真 bug：`/usr/sbin/mobian-setup-usb-network` 里有

```bash
nmcli con add con-name "modem" type gsm ifname "wwan0qmi0"
```

modem 移除后 `wwan0qmi0` 永不存在，NetworkManager 每次开机都尝试连这个死设备。

**验证**：

```bash
nmcli -f NAME,TYPE,DEVICE con show
nmcli device status                     # 有没有 device 显示 unavailable
journalctl -u NetworkManager -b | grep -i 'activation.*failed'
```

**修复**：

```bash
nmcli con delete modem
# 并删掉配置文件
sudo rm -f /etc/NetworkManager/system-connections/modem.nmconnection
# 以及产生它的脚本行
grep -n 'wwan0qmi0' /usr/sbin/mobian-setup-usb-network
```

**通用原则**：重构移除硬件后，必须同时清理 ① 设备树节点 ② 内核模块 ③ 固件 ④ systemd 单元 ⑤ NetworkManager 连接 ⑥ `/etc/modules*` 引用。漏掉任何一层都会留下"看不见的错误"。

## 9.6 `dpkg` 报 postinst 失败（amd64 宿主装 arm64 包）

**现象**：`dpkg --root` 装包时报 `postinst ... returned error exit status`，`dpkg -C` 列出半配置包。

**根因**：`postinst` 是 arm64 ELF 或调用 arm64 二进制，宿主机没开 binfmt 就执行不了。

**验证**：

```bash
file /usr/bin/qemu-aarch64-static
ls /proc/sys/fs/binfmt_misc/            # 有没有 aarch64 条目
```

**修复**：

```bash
sudo apt install qemu-user-static binfmt-support
sudo systemctl restart systemd-binfmt
```

仍失败则用 `scripts/rootfs/fix-dpkg-state.sh` 把状态拉回 `installed`。注意脚本名修正点：`info/` 下的脚本**不带架构后缀**（是 `info/<pkg>.postinst`，不是 `info/<pkg>:arm64.postinst`）。

## 9.7 刷机后进不了系统

**先判断卡在哪一层**：

| 现象 | 卡在 | 下一步 |
|---|---|---|
| 完全无反应、电脑认不出 9008 | PBL/供电 | 换线换口 |
| 9008 枚举 | 引导损坏 | EDL 恢复 |
| fastboot 能进，重启后回到 fastboot | 内核没起来 | 回退 boot.img（[6.4](06-flashing.md#64-回滚)） |
| 蓝灯闪、USB 无网卡 | 内核起来了，gadget 没起来 | 靠 WiFi 进去看 journal（9.1） |
| 能 SSH 但 `uname -r` 是旧的 | lk2nd 走了 fsboot，加载了别处的 boot.img | 见下 |

**"刷了新的却还是旧内核"**：lk2nd 启动时**优先 fsboot** —— 扫描标签为 `system`/`cache`/`userdata` 的分区，找其上的 `boot.img` 文件；失败才读 boot 分区。所以某个数据分区里留着的旧 `boot.img` 会覆盖你刚刷的 boot 分区。

排查：设备上有文件系统的分区挂载后 `find / -maxdepth 2 -name boot.img`。

## 9.8 磁盘满

**根因**：设备端**不会自动扩容**。镜像做多大就是多大，`resize2fs` 不会在首次启动时执行。

**验证**：

```bash
df -h /
du -xh --max-depth=1 / | sort -h | tail
```

**常见占用大户**：`/swapfile`（固定 256 MB，别动）、journal（应 ≤16 MB）、apt 缓存、`/usr/share/doc`、`/usr/share/locale`。

**修复顺序**：先 `journalctl --vacuum-size=8M`、`apt-get clean`，再考虑换更大的镜像（改 `resize-1g.sh` 里的尺寸后重做镜像）。**不要在设备上原地扩容** —— 分区表在 boot 之前就固定了。

## 9.9 `depmod` 之后内置模块"消失"

**现象**：`modinfo ext4` 报 `Module not found`，但 ext4 明明是内置的。

**根因**：`depmod` **只生成** `modules.dep`、`modules.alias`、`modules.symbols`；`modules.builtin`、`modules.order`、`modules.builtin.modinfo` 它不重建。这些文件被删/被覆盖后，`modprobe` 就不知道内置驱动存在。

**验证**：

```bash
ls -l /lib/modules/$(uname -r)/ | grep -E 'builtin|order'
wc -l /lib/modules/$(uname -r)/modules.builtin    # 预期 303 行
```

**修复**：从原始 rootfs tarball 恢复这三个文件。**注意路径**：tarball 里是 `usr/lib/modules/<ver>/`（usrmerge 之后 `lib` 是符号链接），不是 `lib/modules/`。恢复后 `modinfo ext4` 应显示 `(builtin)`。

## 9.10 模块索引里残留已删模块

**现象**：`modprobe <已删模块>` 报错；`modules.dep` 里有指向不存在 `.ko` 的行；`depmod -a` 有告警。

**根因**：手工删了 `.ko` 但没重建索引，或 `modules.order` 里还留着记录。

**修复**：

```bash
depmod -b <root> <version>
# 再清理 modules.order 中已不存在的模块名
scripts/rootfs/fix-modindex2.sh   # 用 host depmod 重建索引
scripts/rootfs/fix-modindex3.sh   # 清 modules.order 并做最终一致性校验
```

## 9.11 一张速查表

| 现象 | 最可能原因 | 一条命令定位 |
|---|---|---|
| USB 整机消失、灯还闪 | gadget 被 `gc -c` 拆除 | 连 WiFi 跑 `gc -l` |
| WiFi 关联被拒 code 31 | MAC 变化被路由器拒 | `ip link show wlan0` |
| 无 `wlan0` | vermagic 不匹配 / 模块缺失 | `modinfo wcn36xx \| head -5` |
| `apt update` 404 | mobian 源已归档 | `grep -r mobian /etc/apt/` |
| `apt update` NO_PUBKEY | 缺 bookworm keyring | `apt list --installed \| grep keyring` |
| 开机反复重试连接 | 硬件已移除、配置未删 | `nmcli con show` |
| `postinst` 失败 | 宿主没开 binfmt | `ls /proc/sys/fs/binfmt_misc/` |
| 刷了新内核还是旧的 | lk2nd 走了 fsboot | `find / -maxdepth 2 -name boot.img` |
| 磁盘满 | 无自动扩容 | `df -h /` |
| `modinfo` 说内置模块不存在 | `modules.builtin` 丢了 | `wc -l .../modules.builtin` |

---

上一步：[8. 运行维护](08-maintenance.md) · 下一步：[10. 参考](10-reference.md)
