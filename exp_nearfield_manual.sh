#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCENE="${1:-truck}"
MODEL_TYPE="${2:-raygs}"
RESOLUTION="${3:-1080p}"
CAMERA_ID="${4:-0}"
DOLLY="${5:-0.0}"
CAMERA_JSON="$SCRIPT_DIR/../models/$SCENE/cameras.json"

if [[ ! -f "$CAMERA_JSON" ]]; then
  echo "未找到 cameras.json：$CAMERA_JSON" >&2
  exit 1
fi

cat <<EOF
即将启动近景手动实验：
  scene      = $SCENE
  model_type = $MODEL_TYPE
  resolution = $RESOLUTION
  camera_id  = $CAMERA_ID
  dolly      = $DOLLY

建议你手动录屏并保存到：
  experiment-results/videos/

建议观察：
  桌角、椅子腿、墙角、围栏、细杆、边缘厚度一致性
EOF

./all-in-one.sh \
  --scene "$SCENE" \
  --resolution "$RESOLUTION" \
  --model-type "$MODEL_TYPE" \
  --draw-method triangles \
  --msaa off \
  --mip-bias 0.0 \
  --mip-modulation on \
  --vsync off \
  --axis off \
  --grid off \
  --camera-json "$CAMERA_JSON" \
  --camera-id "$CAMERA_ID" \
  --camera-dolly "$DOLLY" \
  --metrics-log off \
  --auto-exit off
