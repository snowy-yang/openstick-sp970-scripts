#!/bin/bash
# 从 msm8916.dtsi 基文件中彻底移除 modem 相关节点：
#   - mpss@smp2p-hexagon / hexagon_smp2p_{in,out} / hexagon_smsm  (modem 通信后端)
#   - memshare 节点
#   - mpss: remoteproc@4080000 (含子节点 bam-dmux / smd-edge，MSS PIL modem 处理器)
set -euo pipefail
BASE=/opt/msm8916/linux/arch/arm64/boot/dts/qcom/msm8916.dtsi
[ -f "$BASE.orig" ] || cp "$BASE" "$BASE.orig"

python3 - "$BASE" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
orig_len = len(s)

def drop_node(text, start_marker, note):
    """删除以 start_marker 开头的整个节点块（按大括号配平）。"""
    i = text.find(start_marker)
    if i < 0:
        print(f"  {note}: marker not found, skip")
        return text
    # 从 start_marker 起找第一个 '{'
    j = text.index("{", i)
    depth, k = 0, j
    while k < len(text):
        c = text[k]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        k += 1
    end = k + 1
    # 吃掉后续分号
    while end < len(text) and text[end] in " \t\r\n":
        end += 1
    if end < len(text) and text[end] == ";":
        end += 1
    print(f"  {note}: removed {end - i} bytes")
    return text[:i] + text[end:]

s = drop_node(s, "\tsmp2p-hexagon {", "smp2p-hexagon")
s = drop_node(s, "\t\tmpss_mem: mpss@86800000 {", "mpss_mem")
s = drop_node(s, "\tmemshare: memshare {", "memshare")
s = drop_node(s, "\t\tmpss: remoteproc@4080000 {", "mpss remoteproc (+bam-dmux/smd-edge)")
s = drop_node(s, "\t\thexagon_smsm: hexagon@1 {", "hexagon_smsm")

open(p, "w").write(s)
print(f"size: {orig_len} -> {len(s)}")
PY

echo "=== remaining modem refs in msm8916.dtsi ==="
grep -nE "mpss|memshare|hexagon|bam-dmux|remoteproc" "$BASE" || echo NONE
