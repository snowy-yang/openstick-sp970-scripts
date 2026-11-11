#!/usr/bin/env python3
"""检查反编译后的 dts 中各 modem 节点的 status"""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/sp970-final.dts"
s = open(path).read()

targets = [
    ("mpss (MSS remoteproc)", r"remoteproc@4080000"),
    ("bam-dmux", r"bam-dmux"),
    ("smd-edge", r"smd-edge"),
    ("memshare", r"memshare"),
    ("pronto (WiFi, keep on)", r"remoteproc@a21b000"),
]
for name, needle in targets:
    found = False
    for m in re.finditer(r"\n(\t*)" + needle + r"\s*\{", s):
        found = True
        i = m.end()
        depth, k = 1, i
        while k < len(s) and depth:
            if s[k] == "{":
                depth += 1
            elif s[k] == "}":
                depth -= 1
            k += 1
        body = s[i:k]
        st = re.search(r'status\s*=\s*"(\w+)"', body)
        status = st.group(1) if st else "(no status prop)"
        print(f"{name:12s} -> {status}")
    if not found:
        print(f"{name:12s} -> NOT PRESENT")
