#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCENE="${1:-bicycle}"
RESOLUTIONS=(720p 1080p 1440p 4k)

echo "开始执行分辨率扫描实验，scene=$SCENE ..."
for resolution in "${RESOLUTIONS[@]}"; do
  echo "==> resolution: $resolution"
  ./all-in-one.sh \
    --scene "$SCENE" \
    --resolution "$resolution" \
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

echo "分辨率扫描实验完成。"
