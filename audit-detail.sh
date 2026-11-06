#!/bin/bash
# 深入分析哪些内建驱动可以关闭
set -uo pipefail
CFG=/opt/msm8916/build/.config

echo "=== 网卡厂商驱动（内建）==="
grep -E "^CONFIG_NET_VENDOR_[A-Z0-9_]+=y" "$CFG" | wc -l | sed 's/^/  厂商数: /'
grep -E "^CONFIG_[A-Z0-9_]+=y" "$CFG" | grep -E "_ETHERNET|_NET_|_NIC" | wc -l | sed 's/^/  以太网类驱动: /'

echo
echo "=== 内建以太网/网卡驱动清单（前40）==="
grep -E "^CONFIG_(E1000|E1000E|IGB|IXGBE|R8169|8139|PCNET|NE2K|TULIP|VIA_RHINE|SIS900|ATL1|ATL2|ALX|BNX2|TG3|SKY2|ACENIC|SUNDANCE|DL2K|HAMACHI|YELLOWFIN|ENC28J60|SMC91X|DNET|AX88796)"
    "$CFG" 2>/dev/null | head -40

echo
echo "=== 无用文件系统（内建 y）==="
grep -E "^CONFIG_(BTRFS|F2FS|XFS|NFS|NFSD|CIFS|9P|CEPH|OCFS2|GFS2|REISERFS|JFS|NILFS2|HFS|HFSPLUS|UDF|ISO9660|NTFS|EXFAT|FAT)" "$CFG" | head -30

echo
echo "=== 虚拟化 / 容器 ==="
grep -E "^CONFIG_(KVM|VIRTUALIZATION|XEN|HYPERV|VHOST|VSOCKETS|VDPA)" "$CFG" | head -20

echo
echo "=== 无用总线/接口 ==="
grep -E "^CONFIG_(CAN|ISDN|HAMRADIO|IEEE802154|NFC|RDS|DVB|MEDIA_|SND_|SOUND_|IIO|HID_)" "$CFG" | grep "=y" | wc -l | sed 's/^/  内建项数: /'

echo
echo "=== 声音子系统 ==="
grep -E "^CONFIG_SOUND=|^CONFIG_SND=|^CONFIG_SND_SOC=" "$CFG"
echo "  模块: $(du -sh /opt/msm8916/modinst/lib/modules/5.15.0-handsomekernel+/kernel/sound 2>/dev/null | cut -f1)"

echo
echo "=== DRM / 图形 ==="
grep -E "^CONFIG_DRM" "$CFG" | grep -v "^#" | head -15

echo
echo "=== 摄像头/CAMSS ==="
grep -E "CAMSS|VIDEO_" "$CFG" | grep -v "^#" | head -10
