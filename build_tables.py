#!/usr/bin/env python3

from __future__ import annotations

import csv
import statistics
from pathlib import Path


ROOT = Path(__file__).resolve().parent
METRICS_DIR = ROOT / "experiment-results" / "metrics"
GPU_DIR = ROOT / "experiment-results" / "gpu"
TABLES_DIR = ROOT / "experiment-results" / "tables"
OUTPUT = TABLES_DIR / "run_summary.csv"


def read_csv_rows(path: Path):
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def read_gpu_rows(path: Path):
    if not path.exists():
        return []
    rows = []
    with path.open("r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            if row:
                rows.append([cell.strip() for cell in row])
    return rows


def mean_of(rows, key):
    values = []
    for row in rows:
        try:
            values.append(float(row[key]))
        except Exception:
            pass
    return statistics.fmean(values) if values else None


def max_of(rows, key):
    values = []
    for row in rows:
        try:
            values.append(float(row[key]))
        except Exception:
            pass
    return max(values) if values else None


def gpu_stats(rows):
    if not rows:
      return {}
    gpu_util = []
    mem_used = []
    power = []
    for row in rows:
        if len(row) < 6:
            continue
        try:
            gpu_util.append(float(row[1]))
        except Exception:
            pass
        try:
            mem_used.append(float(row[3]))
        except Exception:
            pass
        try:
            power.append(float(row[5]))
        except Exception:
            pass
    return {
        "gpu_util_avg": statistics.fmean(gpu_util) if gpu_util else None,
        "gpu_util_max": max(gpu_util) if gpu_util else None,
        "vram_used_avg_mib": statistics.fmean(mem_used) if mem_used else None,
        "vram_used_max_mib": max(mem_used) if mem_used else None,
        "power_avg_w": statistics.fmean(power) if power else None,
        "power_max_w": max(power) if power else None,
    }


def fmt(value):
    if value is None:
        return ""
    if isinstance(value, float):
        return f"{value:.4f}"
    return str(value)


def main():
    TABLES_DIR.mkdir(parents=True, exist_ok=True)

    metric_files = sorted(METRICS_DIR.glob("*_viewer_metrics.csv"))
    rows_out = []
    for metrics_file in metric_files:
        run_id = metrics_file.name.replace("_viewer_metrics.csv", "")
        metrics_rows = read_csv_rows(metrics_file)
        if not metrics_rows:
            continue

        first = metrics_rows[0]
        gpu_file = GPU_DIR / f"{run_id}_gpu.csv"
        gpu = gpu_stats(read_gpu_rows(gpu_file))

        scene = run_id.split("_")[0]
        rows_out.append(
            {
                "run_id": run_id,
                "scene": scene,
                "resolution": f"{first.get('width', '')}x{first.get('height', '')}",
                "model_type": first.get("model_type", ""),
                "draw_method": first.get("draw_method", ""),
                "msaa": first.get("msaa", ""),
                "vsync": first.get("vsync", ""),
                "mip_bias": first.get("mip_bias", ""),
                "mip_modulation": first.get("mip_modulation", ""),
                "log_p_min": first.get("log_p_min", ""),
                "fps_avg": mean_of(metrics_rows, "fps"),
                "fps_max": max_of(metrics_rows, "fps"),
                "frame_time_avg_ms": mean_of(metrics_rows, "frame_time_ms"),
                "frame_e2e_avg_ms": mean_of(metrics_rows, "frame_e2e_ms"),
                "projection_avg_ms": mean_of(metrics_rows, "projection_ms"),
                "rendering_avg_ms": mean_of(metrics_rows, "rendering_ms"),
                "visible_ratio_avg": mean_of(metrics_rows, "visible_ratio"),
                "total_splats": first.get("total_splats", ""),
                "gpu_util_avg": gpu.get("gpu_util_avg"),
                "gpu_util_max": gpu.get("gpu_util_max"),
                "vram_used_avg_mib": gpu.get("vram_used_avg_mib"),
                "vram_used_max_mib": gpu.get("vram_used_max_mib"),
                "power_avg_w": gpu.get("power_avg_w"),
                "power_max_w": gpu.get("power_max_w"),
            }
        )

    fieldnames = [
        "run_id",
        "scene",
        "resolution",
        "model_type",
        "draw_method",
        "msaa",
        "vsync",
        "mip_bias",
        "mip_modulation",
        "log_p_min",
        "fps_avg",
        "fps_max",
        "frame_time_avg_ms",
        "frame_e2e_avg_ms",
        "projection_avg_ms",
        "rendering_avg_ms",
        "visible_ratio_avg",
        "total_splats",
        "gpu_util_avg",
        "gpu_util_max",
        "vram_used_avg_mib",
        "vram_used_max_mib",
        "power_avg_w",
        "power_max_w",
    ]

    with OUTPUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows_out:
            writer.writerow({k: fmt(v) for k, v in row.items()})

    print(f"已生成汇总表：{OUTPUT}")


if __name__ == "__main__":
    main()
