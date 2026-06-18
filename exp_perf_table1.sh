#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -gt 0 ]]; then
  SCENES=("$@")
else
  SCENES=(bicycle garden room bonsai)
fi

echo "开始执行 Table 1 风格性能实验..."
for scene in "${SCENES[@]}"; do
  echo "==> scene: $scene"
  ./all-in-one.sh \
    --scene "$scene" \
    --resolution 1080p \
    --model-type raygs \
    --draw-method triangles \
    --msaa off \
    --mip-bias 0.0 \
    --mip-modulation on \
    --vsync off \
    --axis off \
    --grid off \
    --warmup-sec 5 \
    --capture-sec 12 \
    --auto-exit on
done

echo "Table 1 风格性能实验完成。结果请查看 experiment-results/gpu 与 experiment-results/metrics。"
