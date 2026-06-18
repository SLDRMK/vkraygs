#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_VULKAN_SDK="$SCRIPT_DIR/../1.4.350.1/x86_64"
VULKAN_SDK="${VULKAN_SDK:-$DEFAULT_VULKAN_SDK}"
VIEWER_BIN="$SCRIPT_DIR/build/vkgs_viewer"

if [[ ! -d "$VULKAN_SDK" ]]; then
  echo "未找到 Vulkan SDK 目录: $VULKAN_SDK" >&2
  echo "请先确认 SDK 已解压，或手动设置 VULKAN_SDK 环境变量。" >&2
  exit 1
fi

if [[ ! -x "$VIEWER_BIN" ]]; then
  echo "未找到可执行文件: $VIEWER_BIN" >&2
  echo "请先在项目目录完成构建。" >&2
  exit 1
fi

export VULKAN_SDK
export PATH="$VULKAN_SDK/bin:$PATH"
export LD_LIBRARY_PATH="$VULKAN_SDK/lib/VulkanLoader/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export VK_ADD_LAYER_PATH="$VULKAN_SDK/share/vulkan/explicit_layer.d${VK_ADD_LAYER_PATH:+:$VK_ADD_LAYER_PATH}"
export PKG_CONFIG_PATH="$VULKAN_SDK/lib/VulkanLoader/lib/pkgconfig:$VULKAN_SDK/share/pkgconfig:$VULKAN_SDK/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CMAKE_PREFIX_PATH="$VULKAN_SDK:$VULKAN_SDK/lib/VulkanLoader${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"

exec "$VIEWER_BIN" "$@"
