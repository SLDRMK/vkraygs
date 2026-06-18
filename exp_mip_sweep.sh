#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCENE="${1:-bicycle}"
CAMERA_JSON="$SCRIPT_DIR/../models/$SCENE/cameras.json"

if [[ ! -f "$CAMERA_JSON" ]]; then
  echo "未找到 cameras.json：$CAMERA_JSON" >&2
  exit 1
fi

mapfile -t CAMERA_IDS < <(python3 "$SCRIPT_DIR/camera_json_to_env.py" --camera-json "$CAMERA_JSON" --list-ids)

echo "开始执行 MIP / MSAA 对比实验，scene=$SCENE ..."

echo "==> RayGS baseline"
for camera_id in "${CAMERA_IDS[@]}"; do
  echo "   -> camera_id: $camera_id"
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
    --camera-json "$CAMERA_JSON" \
    --camera-id "$camera_id" \
    --warmup-sec 5 \
    --capture-sec 12 \
    --auto-exit on
done

for msaa in 2x 4x; do
  echo "==> RayGS + MSAA $msaa"
  for camera_id in "${CAMERA_IDS[@]}"; do
    echo "   -> camera_id: $camera_id"
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
      --camera-json "$CAMERA_JSON" \
      --camera-id "$camera_id" \
      --warmup-sec 5 \
      --capture-sec 12 \
      --auto-exit on
  done
done

for mip_bias in 0.05 0.10 0.20; do
  echo "==> Mip-RayGS bias=$mip_bias"
  for camera_id in "${CAMERA_IDS[@]}"; do
    echo "   -> camera_id: $camera_id"
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
      --camera-json "$CAMERA_JSON" \
      --camera-id "$camera_id" \
      --warmup-sec 5 \
      --capture-sec 12 \
      --auto-exit on
  done
done

echo "MIP / MSAA 对比实验完成。"
