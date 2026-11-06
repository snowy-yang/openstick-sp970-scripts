#!/bin/bash
# 移除 common dtsi 中残留的 &memshare 覆盖块（modem 相关）
set -euo pipefail
COMMON=/opt/msm8916/linux/arch/arm64/boot/dts/qcom/msm8916-handsome-openstick-common.dtsi
python3 - "$COMMON" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
# 删除注释块 + &memshare 节点覆盖
s = s.replace("""/*
 * The modem firmware sends a "query_size" memshare request for client ID 1,
 * but basically does not do anything with it. GPS works only if:
 *   - Memshare is not present or
 *   - Memshare replies to the request with an error
 * Overall it seems pointless to enable memshare for this device.
 */
 
&memshare {
	status = "disabled";
};

""", "")
open(p, "w").write(s)
print("memshare refs left:", s.count("memshare"))
PY
