#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCENE="${1:-truck}"

echo "开始执行 GS vs RayGS 对比实验，scene=$SCENE ..."

for model in gs raygs; do
  echo "==> model-type: $model"
  ./all-in-one.sh \
    --scene "$SCENE" \
    --resolution 1080p \
    --model-type "$model" \
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

echo "GS vs RayGS 对比实验完成。"
