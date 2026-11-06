#!/bin/bash
# 为 Debian 打包的 arm-none-eabi 工具链建立 lk2nd 期望的 arm-eabi-* 软链接
set -e
cd /usr/bin
for f in arm-none-eabi-*; do
    n="arm-eabi-${f#arm-none-eabi-}"
    if [ ! -e "$n" ]; then
        ln -sf "/usr/bin/$f" "$n"
    fi
done
echo "linked:"
ls -1 arm-eabi-* | tr '\n' ' '
echo
for t in gcc objdump nm size strip ld as ar objcopy; do
    printf '%-16s %s\n' "arm-eabi-$t" "$(command -v arm-eabi-$t || echo MISSING)"
done
