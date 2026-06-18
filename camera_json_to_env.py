#!/usr/bin/env python3

import argparse
import json
import random
from pathlib import Path


def fmt_vec3(values):
    return ",".join(f"{value:.9f}" for value in values)


def load_cameras(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def find_camera(cameras, camera_id):
    for camera in cameras:
        if int(camera["id"]) == camera_id:
            return camera
    raise SystemExit(f"camera id {camera_id} not found in {len(cameras)} cameras")


def select_camera_ids(cameras, sample_count: int | None, sample_seed: int):
    ids = [int(camera["id"]) for camera in cameras]
    if sample_count is None or sample_count <= 0 or sample_count >= len(ids):
        return ids
    return sorted(random.Random(sample_seed).sample(ids, sample_count))


def main():
    parser = argparse.ArgumentParser(description="Convert 3DGS cameras.json entry to Viewer env vars.")
    parser.add_argument("--camera-json", required=True, help="path to cameras.json")
    parser.add_argument("--camera-id", type=int, help="camera id to export")
    parser.add_argument("--list-ids", action="store_true", help="print all camera ids")
    parser.add_argument("--sample-count", type=int, default=0, help="sample N camera ids deterministically")
    parser.add_argument("--sample-seed", type=int, default=0, help="seed for deterministic camera sampling")
    parser.add_argument("--dolly", type=float, default=0.0, help="move along camera forward axis")
    args = parser.parse_args()

    cameras = load_cameras(Path(args.camera_json))
    if args.list_ids:
        for camera_id in select_camera_ids(cameras, args.sample_count, args.sample_seed):
            print(camera_id)
        return

    if args.camera_id is None:
        raise SystemExit("--camera-id is required unless --list-ids is used")

    camera = find_camera(cameras, args.camera_id)
    rotation = camera["rotation"]
    forward = [rotation[0][2], rotation[1][2], rotation[2][2]]
    # 3DGS / COLMAP camera axes are X right, Y down, Z forward.
    # glm::lookAt expects a world-space "up" vector, so we negate the
    # camera's down axis from the C2W rotation matrix.
    up = [-rotation[0][1], -rotation[1][1], -rotation[2][1]]
    eye = list(camera["position"])
    if args.dolly:
        eye = [eye[i] + args.dolly * forward[i] for i in range(3)]

    print(f'CAMERA_POSITION="{fmt_vec3(eye)}"')
    print(f'CAMERA_FORWARD="{fmt_vec3(forward)}"')
    print(f'CAMERA_UP="{fmt_vec3(up)}"')
    print(f'CAMERA_FX="{float(camera["fx"]):.9f}"')
    print(f'CAMERA_FY="{float(camera["fy"]):.9f}"')
    print(f'CAMERA_IMAGE_WIDTH="{int(camera["width"])}"')
    print(f'CAMERA_IMAGE_HEIGHT="{int(camera["height"])}"')
    print(f'CAMERA_IMAGE_NAME="{camera.get("img_name", "")}"')


if __name__ == "__main__":
    main()
