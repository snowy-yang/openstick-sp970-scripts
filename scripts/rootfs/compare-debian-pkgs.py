#!/usr/bin/env python3
"""SP970 rootfs vs Debian 12 (bookworm) arm64 archive — useful server / CLI-TUI packages.

Data: official bookworm main/updates/security arm64 Packages indexes.
"""
import os
import re
from collections import OrderedDict

META = "/opt/msm8916/debmeta"
ROOT = "/opt/msm8916/rootfs-slim/root"
STATUS = os.path.join(ROOT, "var/lib/dpkg/status")


def parse_packages(path, pkgs):
    with open(path, encoding="utf-8", errors="replace") as f:
        cur, key = {}, None
        for line in f:
            if not line.strip():
                if cur.get("Package") and cur["Package"] not in pkgs:
                    pkgs[cur["Package"]] = cur
                cur, key = {}, None
                continue
            if line[0] in " \t" and key:
                cur[key] += " " + line.strip()
                continue
            if ":" in line:
                key, _, val = line.partition(":")
                key = key.strip()
                cur[key] = val.strip()


def installed_set():
    out = set()
    with open(STATUS, encoding="utf-8", errors="replace") as f:
        pkg = None
        for line in f:
            if line.startswith("Package:"):
                pkg = line.split(":", 1)[1].strip()
            elif line.startswith("Status:") and pkg:
                if "install ok installed" in line:
                    out.add(pkg)
                pkg = None
    return out


GROUPS = OrderedDict([
    ("① 编辑器 / 分页 / 归档", [
        "vim-tiny", "vim", "nano", "less", "file", "tree", "mc", "nnn",
        "unzip", "zip", "p7zip-full", "xz-utils", "squashfs-tools",
    ]),
    ("② 终端复用（USB/WiFi 断线保活）", [
        "tmux", "screen", "dtach",
    ]),
    ("③ 监控 / 性能 TUI", [
        "htop", "btop", "atop", "iotop-c", "iftop", "nethogs", "ncdu",
        "sysstat", "ioping", "bmon", "glances",
    ]),
    ("④ 网络诊断", [
        "curl", "wget", "tcpdump", "nmap", "socat", "netcat-openbsd",
        "traceroute", "mtr-tiny", "iperf3", "bind9-dnsutils", "whois",
        "ethtool", "conntrack", "arping", "bridge-utils", "ipcalc",
    ]),
    ("⑤ 硬件 / 设备工具", [
        "pciutils", "usbutils", "i2c-tools", "mmc-utils", "smartmontools",
        "hdparm", "rfkill", "iw", "wireless-regdb", "cpufrequtils",
        "irqbalance", "rng-tools5", "watchdog", "lrzsz", "picocom",
        "dfu-util", "adb", "fastboot",
    ]),
    ("⑥ 系统排障", [
        "psmisc", "lsof", "strace", "sysfsutils", "moreutils", "time",
        "pv", "parallel", "entr", "lshw", "parted", "gdisk", "mdadm", "lvm2",
    ]),
    ("⑦ Shell / 现代 CLI", [
        "bash-completion", "zsh", "fish", "fzf", "ripgrep", "fd-find", "bat",
        "silversearcher-ag", "jq", "yq", "git", "rsync", "man-db", "plocate",
    ]),
    ("⑧ 服务器：文件共享", [
        "samba", "nfs-kernel-server", "vsftpd", "cifs-utils", "sshfs",
        "ntfs-3g", "exfatprogs", "rclone", "syncthing",
    ]),
    ("⑨ 服务器：Web / 应用", [
        "nginx-light", "nginx", "lighttpd", "mosquitto", "mosquitto-clients",
        "aria2", "transmission-daemon", "rtorrent", "minidlna", "caddy",
    ]),
    ("⑩ 服务器：网络 / 安全", [
        "hostapd", "isc-dhcp-server", "avahi-daemon", "wireguard-tools",
        "openvpn", "fail2ban", "ufw", "nftables", "haproxy", "chrony",
        "ntpsec", "unattended-upgrades", "prometheus-node-exporter",
    ]),
    ("⑪ 运行时 / 开发", [
        "python3", "python3-pip", "nodejs", "gcc", "make", "gdb", "tshark",
        "docker.io", "podman",
    ]),
])

# lightweight bundle recommended for a 512MB-1GB headless dongle
BUNDLE = [
    # 必备可用性
    "vim-tiny", "less", "tmux", "curl", "wget", "rsync", "jq", "file",
    "bash-completion", "psmisc", "lsof",
    # 网络排障
    "tcpdump", "socat", "netcat-openbsd", "bind9-dnsutils", "mtr-tiny",
    "iperf3", "ethtool",
    # 硬件
    "usbutils", "pciutils", "iw", "rfkill", "mmc-utils", "i2c-tools",
    "picocom",
    # 监控
    "ncdu", "sysstat", "iotop-c",
    # WiFi 热点
    "hostapd",
]


def main():
    pkgs = {}
    for name in ("bookworm-main-Packages", "bookworm-updates-Packages",
                 "bookworm-security-Packages"):
        p = os.path.join(META, name)
        if os.path.exists(p):
            parse_packages(p, pkgs)
    inst = installed_set()
    print(f"Debian 12 bookworm arm64 索引: {len(pkgs)} 个包   |   SP970 rootfs 已装: {len(inst)} 个\n")

    for title, names in GROUPS.items():
        rows = []
        for n in names:
            if n not in pkgs:
                continue
            m = pkgs[n]
            size = int(m.get("Installed-Size", "0") or 0) / 1024
            desc = re.sub(r"\s+", " ", m.get("Description", "").split("\n")[0])[:60]
            rows.append((n, n in inst, size, m.get("Section", ""), desc))
        avail = [r for r in rows if not r[1]]
        mb = sum(r[2] for r in avail)
        print(f"### {title}   已装 {len(rows)-len(avail)}/{len(rows)}，可加 {len(avail)} 个共 {mb:.0f} MB")
        print(f"{'包名':<22}{'':<4}{'MB':>6}  {'区域':<12}说明")
        print("-" * 100)
        for n, done, size, sec, desc in rows:
            print(f"{n:<22}{'✅' if done else '  ': <4}{size:>6.1f}  {sec:<12}{desc}")
        print()

    total = 0.0
    missing = []
    for n in BUNDLE:
        if n in pkgs:
            sz = int(pkgs[n].get("Installed-Size", "0") or 0) / 1024
            if n not in inst:
                total += sz
                missing.append(n)
        else:
            missing.append(f"{n}(无)")
    print("=" * 100)
    print(f"### 推荐轻量组合（{len(missing)} 个未装，约 {total:.0f} MB 安装占用）")
    print("  " + " ".join(missing))
    print()
    print("### 已装的相关包（当前就有）")
    have = sorted(x for x in inst if x in pkgs and pkgs[x].get("Section", "").split("/")[0]
                  in ("admin", "net", "utils", "shells", "web", "comm", "editors",
                      "text", "misc", "otherosfs", "vcs", "doc"))
    print("  " + " ".join(have))


if __name__ == "__main__":
    main()
