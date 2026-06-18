#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/experiment-results"

mkdir -p \
  "$RESULTS_DIR/gpu" \
  "$RESULTS_DIR/metrics" \
  "$RESULTS_DIR/screenshots" \
  "$RESULTS_DIR/videos" \
  "$RESULTS_DIR/tables" \
  "$RESULTS_DIR/notes"

cd "$SCRIPT_DIR"

echo "========== 1) Table 1 风格性能实验 =========="
./exp_perf_table1.sh

echo "========== 2) 分辨率扫描实验 =========="
./exp_resolution_sweep.sh bicycle

echo "========== 3) GS vs RayGS 对比实验 =========="
./exp_gs_vs_raygs.sh truck

echo "========== 4) MIP / MSAA 对比实验 =========="
./exp_mip_sweep.sh bicycle

echo "========== 5) 汇总表 =========="
./build_tables.py

cat <<'EOF'

自动化部分已完成。

接下来建议手动完成的部分：
1. 近景运动实验：使用 truck / room / bonsai 等场景，分别以 GS 和 RayGS 模式录屏。
2. Figure 4 / Figure 5 风格截图：将截图保存到 experiment-results/screenshots/
3. 视频保存到 experiment-results/videos/
4. 主观观察记录写到 experiment-results/notes/

参考启动命令：
  ./exp_nearfield_manual.sh truck gs 1080p
  ./exp_nearfield_manual.sh truck raygs 1080p

EOF
