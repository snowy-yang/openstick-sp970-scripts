#!/bin/bash
echo "=== gc（gadget 配置工具）==="
which gc; gc --help 2>&1 | head -3
echo "--- 归属包 ---"
dpkg -S "$(which gc 2>/dev/null)" 2>/dev/null || echo "  (未找到归属)"

echo
echo "=== adbd ==="
which adbd
dpkg -S "$(which adbd 2>/dev/null)" 2>/dev/null || echo "  (未找到归属)"
echo "--- adbd 进程 ---"
ps aux | grep '[a]dbd' | head -2

echo
echo "=== mobian 相关包 ==="
dpkg -l | grep -i mobian

echo
echo "=== 这两个工具的动态依赖是否完好 ==="
for b in $(which gc) $(which adbd); do
    echo "--- $b ---"
    ldd "$b" 2>&1 | grep -i "not found" || echo "  ✅ 依赖完整"
done

echo
echo "=== 结论 ==="
if [ -x "$(which gc 2>/dev/null)" ] && [ -x "$(which adbd 2>/dev/null)" ]; then
    echo "  gc 与 adbd 都在，gadget 应可重建"
else
    echo "  ⚠ 有工具缺失"
fi
