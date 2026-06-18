#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCENE="${1:-bicycle}"

echo "开始执行 MIP / MSAA 对比实验，scene=$SCENE ..."

echo "==> RayGS baseline"
./all-in-one.sh \
  --scene "$SCENE" \
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

for msaa in 2x 4x; do
  echo "==> RayGS + MSAA $msaa"
  ./all-in-one.sh \
    --scene "$SCENE" \
    --resolution 1080p \
    --model-type raygs \
    --draw-method triangles \
    --msaa "$msaa" \
    --mip-bias 0.0 \
    --mip-modulation on \
    --vsync off \
    --axis off \
    --grid off \
    --warmup-sec 5 \
    --capture-sec 12 \
    --auto-exit on
done

for mip_bias in 0.05 0.10 0.20; do
  echo "==> Mip-RayGS bias=$mip_bias"
  ./all-in-one.sh \
    --scene "$SCENE" \
    --resolution 1080p \
    --model-type raygs \
    --draw-method triangles \
    --msaa off \
    --mip-bias "$mip_bias" \
    --mip-modulation on \
    --vsync off \
    --axis off \
    --grid off \
    --warmup-sec 5 \
    --capture-sec 12 \
    --auto-exit on
done

echo "MIP / MSAA 对比实验完成。"
