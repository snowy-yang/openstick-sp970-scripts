#!/bin/bash
set -uo pipefail
cd /opt/msm8916/linux
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/opt/msm8916/build -j12 Image dtbs modules > /opt/msm8916/build-qrtrfix.log 2>&1
rc=$?
echo "EXIT=$rc"
echo "errors: $(grep -cE ' error:' /opt/msm8916/build-qrtrfix.log)"
ls -l /opt/msm8916/build/arch/arm64/boot/Image

echo
echo "=== 安装 strip 模块 ==="
rm -rf /opt/msm8916/modinst
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/opt/msm8916/build \
     INSTALL_MOD_PATH=/opt/msm8916/modinst INSTALL_MOD_STRIP=1 -j12 modules_install > /tmp/mi.log 2>&1
echo "  exit=$?"
echo "  模块数: $(find /opt/msm8916/modinst -name '*.ko' | wc -l)"
echo "  qrtr 模块: $(find /opt/msm8916/modinst -name '*qrtr*' | wc -l)"
