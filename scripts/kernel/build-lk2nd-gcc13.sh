#!/bin/bash
# Build lk2nd with an ISOLATED ARM GNU Toolchain (GCC 13.3), leaving the
# lk2nd source tree completely untouched.
#
# Why: the lk2nd codebase (OpenStick/lk2nd @ c4075dd) is legacy C that GCC 14
# turned into hard errors (-Wimplicit-function-declaration, -Wint-conversion,
# ...). Instead of patching the makefile or the sources, build it with an
# older GCC that only warns. Nothing outside /opt/toolchains and the output
# directory is modified.
#
# Usage:  sudo ./build-lk2nd-gcc13.sh [src_dir] [out_root]
set -uo pipefail

VER=13.3.rel1
NAME=arm-gnu-toolchain-${VER}-x86_64-arm-none-eabi
TCDIR=/opt/toolchains
URL=https://developer.arm.com/-/media/Files/downloads/gnu/${VER}/binrel/${NAME}.tar.xz

SRC=${1:-/opt/msm8916/lk2nd}
OUTROOT=${2:-/opt/msm8916/lk2nd-build-gcc13}
PROJ=lk2nd-msm8916

# Two extra path levels so the makefile's hardcoded '$(BOOTLOADER_OUT)/../..'
# (used to drop emmc_appsboot.mbn) still resolves inside OUTROOT.
OUT=$OUTROOT/iso/out

set -e

# ---------------------------------------------------------------- toolchain
TC=${TCDIR}/${NAME}
if [ ! -x "${TC}/bin/arm-none-eabi-gcc" ]; then
    echo "== fetching isolated toolchain (GCC ${VER}) =="
    mkdir -p "$TCDIR"
    curl -L --retry 3 -C - -o "${TCDIR}/${NAME}.tar.xz" "$URL"
    tar -xJf "${TCDIR}/${NAME}.tar.xz" -C "$TCDIR"
    rm -f "${TCDIR}/${NAME}.tar.xz"
fi
export PATH="${TC}/bin:$PATH"
TCBIN=${TC}/bin/arm-none-eabi-

echo "== toolchain =="
"${TCBIN}gcc" --version | head -1

# ------------------------------------------------------------------- source
cd "$SRC"
echo "== source =="
echo "HEAD: $(git rev-parse --short HEAD)  branch: $(git branch --show-current)"
if [ -n "$(git status --porcelain)" ]; then
    echo "WARNING: source tree is dirty:"; git status --short
fi

# -------------------------------------------------------------------- build
rm -rf "$OUTROOT"
mkdir -p "$OUTROOT"
echo "== building $PROJ =="
make TOOLCHAIN_PREFIX="$TCBIN" BOOTLOADER_OUT="$OUT" "$PROJ" -j"$(nproc)" \
    2>&1 | tee /tmp/lk2nd-gcc13.log | tail -3
rc=${PIPESTATUS[0]}
echo "make exit=$rc  errors=$(grep -c 'error:' /tmp/lk2nd-gcc13.log)  warnings=$(grep -c 'warning:' /tmp/lk2nd-gcc13.log)"
[ "$rc" -ne 0 ] && grep -E 'error:' /tmp/lk2nd-gcc13.log | head -20

echo
echo "== artifacts =="
find "$OUTROOT" -type f \( -name 'lk.bin' -o -name 'lk2nd.img' -o -name 'lk2nd.tar' \
     -o -name 'emmc_appsboot.mbn' \) | sort | while read -r f; do
    printf "  %-56s %9s\n" "${f#$OUTROOT/}" "$(stat -c %s "$f")"
done

echo
echo "== source after build =="
git status --porcelain
git diff --stat origin/master
echo "   (both empty = tree still pristine)"
