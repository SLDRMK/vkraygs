#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCENE="${1:-truck}"
CAMERA_JSON="$SCRIPT_DIR/../models/$SCENE/cameras.json"

if [[ ! -f "$CAMERA_JSON" ]]; then
  echo "未找到 cameras.json：$CAMERA_JSON" >&2
  exit 1
fi

mapfile -t CAMERA_IDS < <(python3 "$SCRIPT_DIR/camera_json_to_env.py" --camera-json "$CAMERA_JSON" --list-ids)

echo "开始执行 GS vs RayGS 对比实验，scene=$SCENE ..."

for model in gs raygs; do
  echo "==> model-type: $model"
  for camera_id in "${CAMERA_IDS[@]}"; do
    echo "   -> camera_id: $camera_id"
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
      --camera-json "$CAMERA_JSON" \
      --camera-id "$camera_id" \
      --warmup-sec 5 \
      --capture-sec 12 \
      --auto-exit on
  done
done

echo "GS vs RayGS 对比实验完成。"
