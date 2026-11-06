#!/bin/bash
# 下载 iproute2 及其缺失依赖的 arm64 deb
set -uo pipefail
D=/opt/msm8916/debs
mkdir -p "$D"
cd "$D"

BASE=http://ftp.debian.org/debian/pool/main

fetch() {
    local url="$1" out="$2"
    if [ -f "$out" ]; then echo "  已存在: $out"; return; fi
    code=$(curl -sL -o "$out" -w '%{http_code}' "$url")
    if [ "$code" = "200" ]; then
        echo "  OK   $out ($(stat -c%s "$out") bytes)"
    else
        echo "  FAIL $out (HTTP $code) <- $url"
        rm -f "$out"
    fi
}

echo "=== 下载 ==="
fetch "$BASE/i/iproute2/iproute2_5.10.0-4_arm64.deb"                 iproute2_5.10.0-4_arm64.deb
fetch "$BASE/d/debconf/debconf_1.5.77_all.deb"                        debconf_1.5.77_all.deb
fetch "$BASE/libb/libbpf/libbpf0_0.3-2_arm64.deb"                     libbpf0_0.3-2_arm64.deb
fetch "$BASE/libe/libelf/libelf1_0.183-1_arm64.deb"                   libelf1_0.183-1_arm64.deb

echo
echo "=== 结果 ==="
ls -lh
