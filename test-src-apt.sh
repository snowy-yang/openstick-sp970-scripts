#!/bin/bash
# 用 apt 自身测试镜像源（设备无 curl/wget）
set -u
test_src() {
    local url="$1"
    local tmpd=$(mktemp -d)
    echo "deb $url bookworm main" > "$tmpd/s.list"
    out=$(apt-get -o Dir::Etc::sourcelist="$tmpd/s.list" \
                  -o Dir::Etc::sourceparts="/dev/null" \
                  -o APT::Get::List-Cleanup="0" \
                  update 2>&1)
    if echo "$out" | grep -qE "^E:|W: Failed"; then
        echo "FAIL  $url"
        echo "$out" | grep -E "^E:|W: Failed" | head -2 | sed 's/^/        /'
    else
        echo "OK    $url"
    fi
    rm -rf "$tmpd"
}

for u in \
  "http://deb.debian.org/debian" \
  "http://mirrors.163.com/debian" \
  "http://mirrors.aliyun.com/debian" \
  "http://mirrors.tuna.tsinghua.edu.cn/debian" \
  "http://mirrors.ustc.edu.cn/debian" ; do
    test_src "$u"
done
