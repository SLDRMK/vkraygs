#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
MODELS_DIR="$PROJECT_DIR/../models"
RUNNER="$PROJECT_DIR/run.sh"

SCENE=""
INPUT=""
ITERATION="30000"
RESOLUTION="1080p"
WIDTH=""
HEIGHT=""
DISPLAY_MODE="windowed"
VSYNC="off"
MSAA="off"
DEPTH="f32"
DRAW_METHOD="triangles"
MODEL_TYPE="raygs"
MIP_BIAS="0.0"
MIP_MODULATION="on"
LOG_P_MIN="-4.0"
AXIS="off"
GRID="off"
BUILD_FIRST=0
GPU_LOGGING="on"
GPU_INDEX="0"
GPU_INTERVAL_SEC="1"
METRICS_LOGGING="on"
WARMUP_SEC="5"
CAPTURE_SEC="10"
AUTO_EXIT="on"
DRY_RUN=0
RESULTS_DIR="$PROJECT_DIR/experiment-results"
LOG_DIR="$RESULTS_DIR/gpu"
METRICS_DIR="$RESULTS_DIR/metrics"

usage() {
  cat <<'EOF'
用法：
  ./all-in-one.sh --scene truck
  ./all-in-one.sh --scene garden --resolution 1440p --model-type gs
  ./all-in-one.sh --input /path/to/model.ply --msaa 4x --mip-bias 0.1

可选参数：
  --scene NAME                使用 ../models/NAME/point_cloud/iteration_<n>/point_cloud.ply
  --input PATH                直接指定 ply 文件路径
  --iteration N               模型迭代目录，默认 30000
  --resolution VALUE          720p / 1080p / 1440p / 4k / WIDTHxHEIGHT
  --display-mode VALUE        windowed / fullscreen
  --vsync VALUE               on / off
  --msaa VALUE                off / 2x / 4x
  --depth VALUE               u16 / f32
  --draw-method VALUE         triangles / geom
  --model-type VALUE          gs / raygs
  --mip-bias VALUE            默认 0.0
  --mip-modulation VALUE      on / off
  --log-p-min VALUE           默认 -4.0
  --axis VALUE                on / off
  --grid VALUE                on / off
  --build                     启动前重新构建
  --gpu-log VALUE             on / off，默认 on
  --gpu-index N               nvidia-smi 采样的 GPU 编号，默认 0
  --gpu-interval SEC          nvidia-smi 采样间隔秒数，默认 1
  --metrics-log VALUE         on / off，默认 on
  --warmup-sec SEC            指标预热秒数，默认 5
  --capture-sec SEC           指标采样秒数，默认 10
  --auto-exit VALUE           on / off，采样结束后自动退出，默认 on
  --log-dir PATH              GPU 日志目录
  --dry-run                   只打印命令，不实际执行
  -h, --help                  显示帮助
EOF
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '. /' '___'
}

parse_resolution() {
  local value
  value="$(lower "$1")"
  case "$value" in
    720p|hd)
      WIDTH="1280"
      HEIGHT="720"
      ;;
    1080p|fhd)
      WIDTH="1920"
      HEIGHT="1080"
      ;;
    1440p|2k|qhd)
      WIDTH="2560"
      HEIGHT="1440"
      ;;
    4k|2160p|uhd)
      WIDTH="3840"
      HEIGHT="2160"
      ;;
    *x*)
      WIDTH="${value%x*}"
      HEIGHT="${value#*x}"
      ;;
    *)
      echo "不支持的分辨率：$1" >&2
      exit 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scene)
      SCENE="$2"
      shift 2
      ;;
    --input)
      INPUT="$2"
      shift 2
      ;;
    --iteration)
      ITERATION="$2"
      shift 2
      ;;
    --resolution)
      RESOLUTION="$2"
      shift 2
      ;;
    --display-mode)
      DISPLAY_MODE="$2"
      shift 2
      ;;
    --vsync)
      VSYNC="$2"
      shift 2
      ;;
    --msaa)
      MSAA="$2"
      shift 2
      ;;
    --depth)
      DEPTH="$2"
      shift 2
      ;;
    --draw-method)
      DRAW_METHOD="$2"
      shift 2
      ;;
    --model-type)
      MODEL_TYPE="$2"
      shift 2
      ;;
    --mip-bias)
      MIP_BIAS="$2"
      shift 2
      ;;
    --mip-modulation)
      MIP_MODULATION="$2"
      shift 2
      ;;
    --log-p-min)
      LOG_P_MIN="$2"
      shift 2
      ;;
    --axis)
      AXIS="$2"
      shift 2
      ;;
    --grid)
      GRID="$2"
      shift 2
      ;;
    --build)
      BUILD_FIRST=1
      shift
      ;;
    --gpu-log)
      GPU_LOGGING="$2"
      shift 2
      ;;
    --gpu-index)
      GPU_INDEX="$2"
      shift 2
      ;;
    --gpu-interval)
      GPU_INTERVAL_SEC="$2"
      shift 2
      ;;
    --metrics-log)
      METRICS_LOGGING="$2"
      shift 2
      ;;
    --warmup-sec)
      WARMUP_SEC="$2"
      shift 2
      ;;
    --capture-sec)
      CAPTURE_SEC="$2"
      shift 2
      ;;
    --auto-exit)
      AUTO_EXIT="$2"
      shift 2
      ;;
    --log-dir)
      LOG_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage
      exit 1
      ;;
  esac
done

parse_resolution "$RESOLUTION"

if [[ -z "$INPUT" ]]; then
  if [[ -z "$SCENE" ]]; then
    echo "请至少提供 --scene 或 --input。" >&2
    exit 1
  fi
  INPUT="$MODELS_DIR/$SCENE/point_cloud/iteration_$ITERATION/point_cloud.ply"
fi

if [[ ! -f "$INPUT" ]]; then
  echo "未找到模型文件：$INPUT" >&2
  exit 1
fi

if [[ ! -x "$RUNNER" ]]; then
  echo "未找到启动脚本：$RUNNER" >&2
  exit 1
fi

echo "实验配置："
echo "  模型文件   : $INPUT"
echo "  分辨率     : ${WIDTH}x${HEIGHT}"
echo "  显示模式   : $DISPLAY_MODE"
echo "  Vsync      : $VSYNC"
echo "  MSAA       : $MSAA"
echo "  Depth      : $DEPTH"
echo "  Draw       : $DRAW_METHOD"
echo "  Model Type : $MODEL_TYPE"
echo "  MIP bias   : $MIP_BIAS"
echo "  MIP mod    : $MIP_MODULATION"
echo "  log p_min  : $LOG_P_MIN"
echo "  Axis/Grid  : $AXIS / $GRID"
if [[ "$(lower "$GPU_LOGGING")" == "on" ]]; then
  echo "  GPU 采样   : on (gpu=$GPU_INDEX, interval=${GPU_INTERVAL_SEC}s)"
else
  echo "  GPU 采样   : off"
fi
if [[ "$(lower "$METRICS_LOGGING")" == "on" ]]; then
  echo "  Viewer 指标 : on (warmup=${WARMUP_SEC}s, capture=${CAPTURE_SEC}s, auto-exit=$AUTO_EXIT)"
else
  echo "  Viewer 指标 : off"
fi

if [[ $BUILD_FIRST -eq 1 ]]; then
  echo "先重新构建项目..."
  cmake "$PROJECT_DIR" -B "$PROJECT_DIR/build" -DCMAKE_BUILD_TYPE=Release -DGLFW_BUILD_WAYLAND=OFF
  cmake --build "$PROJECT_DIR/build" --config Release -j
fi

GPU_PID=""
GPU_LOG_FILE=""
GPU_SUMMARY_FILE=""
METRICS_FILE=""
METRICS_SUMMARY_FILE=""
RUN_TAG=""
GPU_SUMMARY_DONE=0
cleanup() {
  if [[ -n "$GPU_PID" ]] && kill -0 "$GPU_PID" >/dev/null 2>&1; then
    kill "$GPU_PID" >/dev/null 2>&1 || true
    wait "$GPU_PID" 2>/dev/null || true
  fi
}

summarize_gpu_log() {
  if [[ -z "$GPU_LOG_FILE" || ! -f "$GPU_LOG_FILE" ]]; then
    return
  fi

  GPU_SUMMARY_FILE="${GPU_LOG_FILE%.csv}_summary.txt"
  python3 - "$GPU_LOG_FILE" "$GPU_SUMMARY_FILE" <<'PY'
import csv
import math
import statistics
import sys
from pathlib import Path

csv_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])

rows = []
with csv_path.open("r", encoding="utf-8") as f:
    reader = csv.reader(f)
    for row in reader:
        if not row:
            continue
        rows.append([cell.strip() for cell in row])

if not rows:
    summary_path.write_text("GPU log is empty.\n", encoding="utf-8")
    print(f"GPU 摘要已写入：{summary_path}")
    sys.exit(0)

def to_float(value: str):
    v = value.strip()
    if not v or v.upper() in {"N/A", "[N/A]"}:
        return None
    try:
        return float(v)
    except ValueError:
        return None

timestamps = []
gpu_utils = []
mem_utils = []
mem_used = []
mem_total = []
power = []

for row in rows:
    if len(row) < 6:
        continue
    timestamps.append(row[0])
    if (v := to_float(row[1])) is not None:
        gpu_utils.append(v)
    if (v := to_float(row[2])) is not None:
        mem_utils.append(v)
    if (v := to_float(row[3])) is not None:
        mem_used.append(v)
    if (v := to_float(row[4])) is not None:
        mem_total.append(v)
    if (v := to_float(row[5])) is not None:
        power.append(v)

def fmt_stats(values, unit):
    if not values:
        return f"N/A {unit}".strip()
    mean = statistics.fmean(values)
    peak = max(values)
    low = min(values)
    return f"avg={mean:.2f}{unit}, max={peak:.2f}{unit}, min={low:.2f}{unit}"

lines = []
lines.append(f"GPU log file: {csv_path}")
lines.append(f"Samples: {len(rows)}")
if len(timestamps) >= 2:
    lines.append(f"Time range: {timestamps[0]} -> {timestamps[-1]}")
elif len(timestamps) == 1:
    lines.append(f"Time range: {timestamps[0]}")
lines.append("")
lines.append(f"GPU utilization: {fmt_stats(gpu_utils, '%')}")
lines.append(f"Memory utilization: {fmt_stats(mem_utils, '%')}")
lines.append(f"VRAM used: {fmt_stats(mem_used, ' MiB')}")
if mem_total:
    lines.append(f"VRAM total: {mem_total[0]:.0f} MiB")
lines.append(f"Power draw: {fmt_stats(power, ' W')}")
lines.append("")

if gpu_utils and mem_used:
    lines.append("Report-ready note:")
    lines.append(
        f"平均 GPU 利用率约 {statistics.fmean(gpu_utils):.1f}%，峰值显存约 {max(mem_used):.0f} MiB。"
    )

summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
print(f"\nGPU 摘要已写入：{summary_path}")
PY
}

summarize_metrics_log() {
  if [[ -z "$METRICS_FILE" || ! -f "$METRICS_FILE" ]]; then
    return
  fi

  METRICS_SUMMARY_FILE="${METRICS_FILE%.csv}_summary.txt"
  python3 - "$METRICS_FILE" "$METRICS_SUMMARY_FILE" <<'PY'
import csv
import statistics
import sys
from pathlib import Path

csv_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])

with csv_path.open("r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

if not rows:
    summary_path.write_text("Metrics log is empty.\n", encoding="utf-8")
    print(f"Viewer 指标摘要已写入：{summary_path}")
    sys.exit(0)

def values(key):
    out = []
    for row in rows:
        try:
            out.append(float(row[key]))
        except Exception:
            pass
    return out

fps = values("fps")
frame_time = values("frame_time_ms")
frame_e2e = values("frame_e2e_ms")
projection = values("projection_ms")
rendering = values("rendering_ms")
visible_ratio = values("visible_ratio")
total_splats = values("total_splats")

def fmt_avg_max(values_, unit):
    if not values_:
        return f"N/A {unit}".strip()
    return f"avg={statistics.fmean(values_):.3f}{unit}, max={max(values_):.3f}{unit}"

lines = []
lines.append(f"Metrics file: {csv_path}")
lines.append(f"Samples: {len(rows)}")
if rows:
    lines.append(f"Measurement range: {rows[0].get('measurement_elapsed_ms', '0')}ms -> {rows[-1].get('measurement_elapsed_ms', '0')}ms")
lines.append("")
lines.append(f"FPS: {fmt_avg_max(fps, '')}")
lines.append(f"Frame time: {fmt_avg_max(frame_time, ' ms')}")
lines.append(f"Frame e2e: {fmt_avg_max(frame_e2e, ' ms')}")
lines.append(f"Projection: {fmt_avg_max(projection, ' ms')}")
lines.append(f"Rendering: {fmt_avg_max(rendering, ' ms')}")
lines.append(f"Visible ratio: {fmt_avg_max(visible_ratio, ' %')}")
if total_splats:
    lines.append(f"Total splats: {int(total_splats[-1])}")
lines.append("")
if fps and frame_e2e:
    lines.append("Report-ready note:")
    lines.append(f"平均 FPS 约 {statistics.fmean(fps):.2f}，平均 frame e2e 约 {statistics.fmean(frame_e2e):.3f} ms。")

summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
print(f"\nViewer 指标摘要已写入：{summary_path}")
PY
}

on_exit() {
  cleanup
  if [[ "$GPU_SUMMARY_DONE" -eq 0 ]]; then
    summarize_gpu_log
    summarize_metrics_log
  fi
}

trap on_exit EXIT

RUN_TAG="$(date +%Y%m%d-%H%M%S)"
CONFIG_TAG="$(slugify "${DRAW_METHOD}_${MODEL_TYPE}_${WIDTH}x${HEIGHT}_msaa-${MSAA}_mip-${MIP_BIAS}")"
if [[ -n "$SCENE" ]]; then
  RUN_TAG="${SCENE}_${CONFIG_TAG}_${RUN_TAG}"
else
  RUN_TAG="custom_${CONFIG_TAG}_${RUN_TAG}"
fi

if [[ "$(lower "$METRICS_LOGGING")" == "on" ]]; then
  mkdir -p "$METRICS_DIR"
  METRICS_FILE="$METRICS_DIR/${RUN_TAG}_viewer_metrics.csv"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "启动命令："
  VIEWER_ARGS=(
    --input "$INPUT"
    --width "$WIDTH"
    --height "$HEIGHT"
    --display-mode "$DISPLAY_MODE"
    --vsync "$VSYNC"
    --msaa "$MSAA"
    --depth "$DEPTH"
    --draw-method "$DRAW_METHOD"
    --model-type "$MODEL_TYPE"
    --mip-bias "$MIP_BIAS"
    --mip-modulation "$MIP_MODULATION"
    --log-p-min "$LOG_P_MIN"
    --axis "$AXIS"
    --grid "$GRID"
  )
  if [[ -n "$METRICS_FILE" ]]; then
    VIEWER_ARGS+=(--metrics-csv "$METRICS_FILE" --warmup-sec "$WARMUP_SEC" --capture-sec "$CAPTURE_SEC" --auto-exit "$AUTO_EXIT")
  fi
  printf '  %q' "$RUNNER" "${VIEWER_ARGS[@]}"
  printf '\n'
  exit 0
fi

if [[ "$(lower "$GPU_LOGGING")" == "on" ]]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    mkdir -p "$LOG_DIR"
    GPU_LOG_FILE="$LOG_DIR/${RUN_TAG}_gpu.csv"
    echo "开始记录 GPU 采样到：$GPU_LOG_FILE"
    nvidia-smi \
      -i "$GPU_INDEX" \
      --query-gpu=timestamp,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw \
      --format=csv,noheader,nounits -l "$GPU_INTERVAL_SEC" >"$GPU_LOG_FILE" &
    GPU_PID="$!"
  else
    echo "未找到 nvidia-smi，跳过 GPU 日志采样。"
  fi
fi

VIEWER_ARGS=(
  --input "$INPUT"
  --width "$WIDTH"
  --height "$HEIGHT"
  --display-mode "$DISPLAY_MODE"
  --vsync "$VSYNC"
  --msaa "$MSAA"
  --depth "$DEPTH"
  --draw-method "$DRAW_METHOD"
  --model-type "$MODEL_TYPE"
  --mip-bias "$MIP_BIAS"
  --mip-modulation "$MIP_MODULATION"
  --log-p-min "$LOG_P_MIN"
  --axis "$AXIS"
  --grid "$GRID"
)

if [[ -n "$METRICS_FILE" ]]; then
  VIEWER_ARGS+=(--metrics-csv "$METRICS_FILE" --warmup-sec "$WARMUP_SEC" --capture-sec "$CAPTURE_SEC" --auto-exit "$AUTO_EXIT")
fi

echo "启动命令："
printf '  %q' "$RUNNER" "${VIEWER_ARGS[@]}"
printf '\n'

"$RUNNER" "${VIEWER_ARGS[@]}"
cleanup
GPU_PID=""
summarize_gpu_log
summarize_metrics_log
GPU_SUMMARY_DONE=1
