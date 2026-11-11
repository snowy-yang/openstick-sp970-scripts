#!/bin/bash
# 还原 msm8916.dtsi 基文件，改用正确方案：
#   节点必须保留（&mpss 等标签被 pm8916.dtsi/apq8016-sbc 等大量引用，删除会导致 dtc 失败并影响其他板）
#   真正的移除在内核侧：驱动配置全部关闭。
#   另外在 OpenStick common dtsi 中显式确保 modem 节点 disabled。
set -euo pipefail
DTS_QCOM=/opt/msm8916/linux/arch/arm64/boot/dts/qcom
BASE="$DTS_QCOM/msm8916.dtsi"
COMMON="$DTS_QCOM/msm8916-handsome-openstick-common.dtsi"

echo "=== restore msm8916.dtsi from backup ==="
if [ -f "$BASE.orig" ]; then
    cp "$BASE.orig" "$BASE"
    echo "restored"
else
    echo "no backup!"; exit 1
fi
grep -c "mpss: remoteproc@4080000" "$BASE" | sed 's/^/mpss node present: /'

echo "=== append explicit modem-disabled overrides to common dtsi ==="
python3 - "$COMMON" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
block = """
/*
 * Modem disabled build: ensure the MSS remote processor and all its
 * modem-transport sub-nodes stay disabled so that no modem driver or
 * firmware is ever loaded on this board.
 */
&mpss {
	status = "disabled";

	bam-dmux {
		status = "disabled";
	};

	smd-edge {
		status = "disabled";
	};
};

&memshare {
	status = "disabled";
};
"""
if "Modem disabled build" not in s:
    if not s.endswith("\n"):
        s += "\n"
    s += block
    open(p, "w").write(s)
    print("appended modem-disabled overrides")
else:
    print("already present, skip")
PY

echo "=== done ==="
