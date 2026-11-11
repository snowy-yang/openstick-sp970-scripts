#!/usr/bin/env python3
"""对比 ramdisk 中官方模块与本地新编模块，列出缺失项"""
import os
import sys

INITRD = "/tmp/initrd"
BUILD = "/opt/msm8916/build"
MODVER = "5.15.0-handsomekernel+"

def rel_mods(root):
    """收集 root 下的 .ko，返回 {相对驱动路径(去掉 kernel/ 与前缀): 绝对路径}"""
    out = {}
    for dirpath, _, files in os.walk(root):
        for f in files:
            if not f.endswith(".ko"):
                continue
            full = os.path.join(dirpath, f)
            # 统一成 kernel/drivers/... 形式
            idx = full.find("/kernel/")
            rel = full[idx + 8:] if idx >= 0 else os.path.relpath(full, root)
            out[rel] = full
    return out

off = rel_mods(os.path.join(INITRD, "usr/lib/modules", MODVER))
new = rel_mods(BUILD)

print(f"ramdisk modules : {len(off)}")
print(f"new build modules: {len(new)}")
print()

missing = sorted(set(off) - set(new))
print(f"=== 缺失（本地未编）: {len(missing)} ===")
for m in missing:
    print("  MISSING:", m)

extra_modem = sorted(p for p in new if any(k in p for k in
    ("wwan", "bam_dmux", "rmnet", "qrtr", "qmi")))
print()
print(f"=== 本地仍存在的 modem 类模块: {len(extra_modem)} ===")
for m in extra_modem:
    print("  MODEM:", m)

common = set(off) & set(new)
print()
print(f"=== 可直接替换: {len(common)} ===")
