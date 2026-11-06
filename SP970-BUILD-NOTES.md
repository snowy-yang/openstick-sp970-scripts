# OpenStick SP970 — Debian 12 去 Modem 固件

内核 **Linux 5.15.0** (`5.15.0-handsomekernel+`，自编译)，**已移除 modem，保留 WiFi**。
系统：**Debian 12.15 bookworm**，systemd 252，libc 2.36。

## 当前设备实测状态（2026-11-05）

| 项目 | 状态 |
|---|---|
| 系统版本 | ✅ Debian 12.15 bookworm |
| 内核 | ✅ 5.15.0-handsomekernel+（自编译 gcc 15.2.0） |
| systemd | ✅ 252.39 |
| USB gadget | ✅ UDC=ci_hdrc.0，usb0=192.168.68.1 |
| WiFi | ✅ wlan0=192.168.1.48，可上网 |
| 失败单元 | ✅ 0 个 |
| dpkg 一致性 | ✅ 无异常 |
| 磁盘 | 345 MB / 3.3 GB（11%） |
| 已装包 | 234 个 |

## 产物

| 文件 | 大小 | 说明 |
|---|---|---|
| `boot-sp970-nomodrm.img` | 13 MB | 内核 + SP970 dtb + initramfs |
| `rootfs-sp970-debian12.img` | 292 MB | **Debian 12.15**，从实机导出 |
| `rootfs-sp970-nomodrm.img` | 243 MB | Debian 11（旧版，备用） |
| `lk2nd.img` | 387 KB | 引导程序 |

## 刷机

```bash
adb reboot bootloader
fastboot flash boot boot-sp970-nomodrm.img
fastboot -S 200M flash rootfs rootfs-sp970-debian12.img
fastboot reboot
```

启动后 `ssh user@192.168.68.1`（USB）或 WiFi IP，密码 `1`。

---

# 重要记录：一次 USB 掉线故障的排查

## 现象

执行 `apt-get autoremove --purge` 后，设备从 USB 总线完全消失，电脑枚举不到任何设备。
但**红灯心跳、蓝灯闪烁**——说明系统仍在运行。

## 根因（与最初判断不同）

最初以为是 autoremove 删了 `libgudev-1.0-0` 导致 gadget 失效。**实测证明这个判断是错的**：

- `apt-cache rdepends libgudev-1.0-0` 的 Reverse Depends **为空**
- `libusbgx`（gadget 核心库）**从未纳入 dpkg 包管理**，是手动放在 `/lib/` 的
- 后来重复执行同样的 autoremove，**gadget 毫发无损**

真正原因：USB gadget 由 `mobian-usb-gadget.service`（属于 `mobian-tweaks-common` 包）配置，
其脚本执行 `gc -c`（删除 gadget）后需要重建。**删除 gadget 会断开 ADB，而我的操作链依赖 ADB**，
一旦断开就无法执行后续的 `setup`，gadget 永久停留在删除状态。

## 恢复方法（已验证有效）

WiFi 通道保留是关键——**WiFi 与 USB 独立**，USB 挂了 WiFi 仍在：

```bash
ssh user@<wifi-ip>          # 通过 WiFi 进入
sudo /usr/sbin/mobian-usb-gadget setup
```

若 adbd 端口冲突，先清理：
```bash
sudo pkill -9 adbd
sudo umount /dev/usb-ffs/adb 2>/dev/null
sudo gc -c; sleep 1
sudo /usr/sbin/mobian-usb-gadget setup
```

## 教训

1. **不要在有线通道（ADB/USB）上执行会拆除该通道的操作**，除非有独立备用通道（本例是 WiFi）
2. 执行 `autoremove` 前应先 `apt-cache rdepends` 核实依赖，不能只看包名猜测
3. 故障时优先看 **LED 指示灯**判断系统是否存活，避免误判为硬件损坏

---

## 本轮其他变更

### Debian 11 → 12 升级

- 186 个包升级，34 个新增
- 需要先安装 `debian-archive-keyring 2025.1`（bookworm 新密钥）
- 禁用失效的 `repo.mobian-project.org`（返回 404）

### 清理

| 项目 | 节省 |
|---|---|
| `/usr/share/locale`（保留 en/zh） | 44 MB |
| `/usr/share/doc` + `man` | 27 MB |
| apt 缓存与索引 | ~50 MB |
| rc 状态包（python3/dhcpcd5 等） | 少量 |
| 升级残留日志 | 少量 |

磁盘 655 MB → **345 MB**。

### WiFi 连接问题（MAC 地址限制）

重刷后 WiFi 连不上，wpa_supplicant 报 `ASSOC-REJECT status_code=31`（路由器拒绝关联）。
原因：**MAC 地址变化被路由器拒绝**。解决：

```bash
nmcli con modify WU 802-11-wireless.cloned-mac-address stable
```

## 保留的关键组件

- `libusbgx.so.2`（手动放置，gadget 核心，**不在包管理中**）
- `/usr/bin/gc`、`/usr/bin/adbd`（同上）
- `/usr/sbin/mobian-usb-gadget` + `mobian-usb-gadget.service`
- `wcnss.*` WiFi 固件 9 个文件

## 环境

- 构建：WSL2 Ubuntu 26.04，`gcc-aarch64-linux-gnu` 15.2.0
- 交叉工具链：`arm-none-eabi-gcc` 14.2.1（lk2nd）
- 镜像制作：宿主机 `qemu-user` + binfmt（执行 arm64 postinst）
