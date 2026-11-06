#!/bin/bash
# 统计候选裁剪项的体积收益
set -uo pipefail
CFG=/opt/msm8916/build/.config
M=/opt/msm8916/modinst/lib/modules/5.15.0-handsomekernel+/kernel

echo "=== [A] 40 个网卡厂商 NET_VENDOR_* 内建项 ==="
grep -E "^CONFIG_NET_VENDOR_[A-Z0-9_]+=y" "$CFG" | sed 's/^CONFIG_NET_VENDOR_//;s/=y//' | tr '\n' ' '
echo

echo
echo "=== [B] 这些厂商下的具体网卡驱动（内建 y）==="
grep -E "^CONFIG_(E1000|E1000E|IGB|IXGBE|I40E|ICE|R8169|8139CP|8139TOO|PCNET32|NE2K_PCI|TULIP|VIA_RHINE|SIS900|ATL1|ATL2|ALX|BNX2|CNIC|TG3|TIGON3|SKY2|SKGE|ACENIC|SUNDANCE|DL2K|HAMACHI|YELLOWFIN|ENC28J60|SMC91X|DNET|AX88796|AMD8111_ETH|PASEMI_MAC|MACB|KSZ884X_PCI|STMMAC_ETH|B44|BGMAC|TSE|CPMAC|MVMDIO|MVNETA|MVPP2_SKB|MVPP2X|AQUANTIA|NFP|QLCNIC|QEDE|SFC|EHEA|IBM_EMAC|JME|NS8390|PCMCIA_NET|FEALNX|BNA|S2IO|NIU|OCTEON|THUNDER_NIC|NETXEN|DP83867)" "$CFG" | sort | tr '\n' ' '
echo

echo
echo "=== [C] KVM/虚拟化 ==="
grep -E "^CONFIG_(KVM|VIRTUALIZATION|VHOST|VIRTIO)" "$CFG" | grep "=y" | tr '\n' ' '
echo

echo
echo "=== [D] 声音 ==="
grep -E "^CONFIG_(SOUND|SND)(=|_|[A-Z])" "$CFG" | grep "=y" | wc -l
echo "  模块体积: $(du -sh $M/sound 2>/dev/null | cut -f1)"

echo
echo "=== [E] 摄像头 (CAMSS/VENUS/UVC) ==="
grep -E "CAMSS|VENUS|USB_VIDEO|VIDEO_" "$CFG" | grep -v "^#" | tr '\n' ' '
echo
echo "  模块体积: $(du -sh $M/drivers/media 2>/dev/null | cut -f1)"

echo
echo "=== [F] 蓝牙 ==="
grep -E "^CONFIG_BT" "$CFG" | grep -v "^#" | wc -l
echo "  模块体积: $(du -sh $M/drivers/bluetooth 2>/dev/null | cut -f1)"

echo
echo "=== [G] 其他文件系统模块 ==="
for f in f2fs exfat ntfs ntfs3 btrfs xfs nfs cifs; do
    [ -d "$M/fs/$f" ] && printf "  %-8s %s\n" "$f" "$(du -sh $M/fs/$f 2>/dev/null | cut -f1)"
done

echo
echo "=== [H] 无线/WiFi 模块（必须保留 wcn36xx）==="
du -sh "$M/drivers/net/wireless" 2>/dev/null
ls "$M/drivers/net/wireless" 2>/dev/null

echo
echo "=== [I] 触屏/输入（棒子无屏）==="
du -sh "$M/drivers/input" 2>/dev/null
ls "$M/drivers/input/touchscreen" 2>/dev/null | head

echo
echo "=== [J] DRM 显示（棒子无屏）==="
grep -cE "^CONFIG_DRM.*=y" "$CFG"
