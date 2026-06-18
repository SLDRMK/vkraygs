# VKRayGS 实验复现指南

本文档基于当前 `vkraygs` 仓库源码、README、Viewer UI 与预训练模型 `models.zip` 整理，目标是在**不重新训练模型**的前提下，仅依赖作者提供的 `.ply` 模型和 Viewer，完成 VKRayGS 的主要复现实验与扩展实验。

## 1. 仓库功能结构

```text
vkraygs
├── examples/vkgs_viewer.cc              # 程序入口，命令行参数解析
├── include/vkgs/engine/engine.h         # Engine 公共接口与启动参数
├── src/vkgs/engine/engine.cc            # UI、渲染模式切换、计时、主绘制逻辑
├── src/vkgs/viewer/viewer.cc            # GLFW 窗口、分辨率、拖拽加载、ImGui
├── src/vkgs/scene/camera.cc             # 相机控制
├── src/vkgs/engine/splat_load_thread.cc # PLY 加载与 Gaussian 数统计
├── src/shader/projection.comp           # GS 投影路径
├── src/shader/raygs_projection.comp     # RayGS 投影路径
├── src/shader/splat.vert/.frag          # GS 光栅化路径
├── src/shader/raygs_splat.vert/.frag    # RayGS 光栅化路径
├── src/shader/splat_geom.vert/.geom     # GS 的 Geometry Shader 路径
├── run.sh                               # Vulkan SDK 环境包装脚本
├── all-in-one.sh                        # 一键实验脚本
└── experiment-results/                  # 实验输出目录
```

## 2. 已实现的渲染模式与切换方式

### 2.1 已实现模式

1. `VKGS / GS`
   - 路径：`projection.comp + splat.vert + splat.frag`
   - 切换：`Draw method = Triangles`，`Model Type = GS`

2. `VKRayGS / RayGS`
   - 路径：`raygs_projection.comp + raygs_splat.vert + raygs_splat.frag`
   - 切换：`Draw method = Triangles`，`Model Type = RayGS`
   - 当前默认模式

3. `GS + Geometry Shader`
   - 路径：`splat_geom.vert + splat_geom.geom + splat.frag`
   - 切换：`Draw method = Geom Shader`
   - 注意：该模式会强制回到 `GS`

4. `Mip-GS`
   - 切换：`Model Type = GS`，同时设置 `MIP bias > 0`，`MIP modulation = on`

5. `Mip-RayGS`
   - 切换：`Model Type = RayGS`，同时设置 `MIP bias > 0`，`MIP modulation = on`
   - 说明：UI 没有单独写 “Mip-RayGS”，而是通过参数组合实现

6. `MSAA`
   - 切换：`MSAA = Off / 2x / 4x`
   - 说明：这是叠加型开关，不是独立渲染器

### 2.2 其它 Viewer 相关选项

- `Vsync = on / off`
- `Depth = U16 / F32`
- `Axis = on / off`
- `Grid = on / off`
- `Fov Y`
- `Display Mode = Windowed / Windowed Fullscreen`
- `Resolution` 预设：`640x480`、`800x600`、`1280x720`、`1600x900`、`1920x1080`、`2560x1440`

## 3. 程序入口与操作方法

### 3.1 命令行

当前可执行程序支持：

```bash
./build/vkgs_viewer -i /path/to/model.ply
```

现在也已经补充了实验相关启动参数，可通过 `run.sh` 或 `all-in-one.sh` 自动设置：

```bash
./run.sh \
  --input /path/to/model.ply \
  --width 1920 \
  --height 1080 \
  --display-mode windowed \
  --vsync off \
  --msaa off \
  --depth f32 \
  --draw-method triangles \
  --model-type raygs \
  --mip-bias 0.0 \
  --mip-modulation on \
  --log-p-min -4.0 \
  --axis off \
  --grid off
```

### 3.2 一键实验脚本

推荐直接用：

```bash
cd /home/sldrmk/WorkSpace/ComputerGraphics/vkraygs
./all-in-one.sh --scene truck
```

常用示例：

```bash
./all-in-one.sh --scene bicycle
./all-in-one.sh --scene garden --resolution 1440p
./all-in-one.sh --scene room --model-type gs
./all-in-one.sh --scene bonsai --resolution 4k
./all-in-one.sh --scene truck --msaa 4x --mip-bias 0.1
./all-in-one.sh --input /absolute/path/to/model.ply
```

### 3.3 相机与快捷键

- 左键拖动：旋转
- 右键拖动：平移
- 左右键同时拖动：缩放
- 滚轮：缩放
- `Ctrl + 滚轮`：Dolly zoom / 改变 FOV
- `W/A/S/D/Space`：平移
- `Alt + Enter`：窗口/无边框全屏切换
- 支持将 `.ply` 直接拖进窗口加载

## 4. Viewer 可直接记录的指标

ImGui 面板中可直接读取：

- `total splats`
- `loaded splats`
- `visible splats`
- `fps`
- `1 / FPS (ms)`
- `frame e2e`
- `rank`
- `sort`
- `inverse`
- `projection`
- `rendering`
- `present`
- `size`

## 5. 需要外部工具记录的指标

Viewer 当前**没有内置**以下内容：

- 显存占用
- GPU 利用率
- 功耗
- 温度
- 截图/录屏导出
- 相机轨迹导出
- CSV benchmark 导出

因此建议配合：

- `nvidia-smi`
- `OBS` / 系统录屏
- 手动截图或后续扩展 readback 功能

## 6. 脚本已纳入的自动化输出

`all-in-one.sh` 现在会把实验输出统一放到：

```text
vkraygs/experiment-results/
```

当前自动输出内容：

1. `nvidia-smi` 原始采样 CSV
2. 自动解析后的 GPU 摘要文件

默认采样字段：

- `utilization.gpu`
- `utilization.memory`
- `memory.used`
- `memory.total`
- `power.draw`

运行结束后会生成：

```text
*_gpu.csv
*_gpu_summary.txt
```

摘要中包含：

- 平均 GPU 利用率
- 峰值/平均/最小显存占用
- 平均/峰值功耗
- 采样时间范围

## 7. 可执行实验清单

### 7.1 VKRayGS 性能复现实验

目标：

- 选择 `bicycle`、`garden`、`room`、`bonsai`
- 固定 `1080p`
- 记录 `FPS`、`Frame Time`、`GPU 显存占用`
- 与论文 Table 1 对比

推荐步骤：

1. 使用：

   ```bash
   ./all-in-one.sh --scene bicycle --resolution 1080p --model-type raygs
   ```

2. 确保：
   - `Vsync = off`
   - `MSAA = off`
   - `Model Type = raygs`
   - `MIP bias = 0.0`

3. 等待：
   - `loaded splats = total splats`

4. 记录：
   - `fps`
   - `1/FPS`
   - `frame e2e`
   - `projection`
   - `rendering`
   - `visible splats`
   - `experiment-results/*_gpu_summary.txt` 中的显存与 GPU 利用率

5. 对 `720p / 1080p / 1440p / 4k` 重复测试

### 7.2 VKGS 与 VKRayGS 对比实验

目标：

- 同一场景、同一视角下比较 `GS` 与 `RayGS`
- 比较 FPS 和画质
- 观察近景几何伪影

推荐步骤：

1. 固定视角
2. 保持 `Draw method = triangles`
3. 分别运行：

   ```bash
   ./all-in-one.sh --scene truck --model-type gs
   ./all-in-one.sh --scene truck --model-type raygs
   ```

4. 记录：
   - `fps`
   - `frame e2e`
   - 局部截图
   - 几何伪影现象

关注现象：

- `GS` 更容易出现：
  - spikes
  - 漂浮边缘
  - 厚度不一致
- `RayGS` 近景几何更稳定

### 7.3 MIP Anti-Aliasing 实验

目标：

- 比较 `VKRayGS`、`MSAA`、`Mip-VKRayGS`
- 观察远景高频结构的锯齿与闪烁

建议设置：

1. 无 MIP：

   ```bash
   ./all-in-one.sh --scene bicycle --model-type raygs --mip-bias 0.0 --msaa off
   ```

2. MSAA：

   ```bash
   ./all-in-one.sh --scene bicycle --model-type raygs --mip-bias 0.0 --msaa 4x
   ```

3. Mip-RayGS：

   ```bash
   ./all-in-one.sh --scene bicycle --model-type raygs --mip-bias 0.1 --mip-modulation on
   ```

重点观察：

- 辐条
- 树枝
- 围栏
- 远景细线结构

### 7.4 模型规模与性能关系实验

目标：

- 统计不同场景 Gaussian 数量
- 建立 Gaussian 数量与 FPS 的关系

可直接使用：

- `total splats` 作为 Gaussian 数量

记录：

- `total splats`
- `visible splats`
- `fps`
- `frame e2e`

### 7.5 RTX2080 vs RTX4080 扩展实验

目标：

- 与论文 RTX2080 结果比较
- 分析性能提升来源

记录：

- `fps`
- `frame e2e`
- `GPU utilization`
- `memory.used`
- `power.draw`

分析要点：

- 更高通用计算吞吐
- 更高显存带宽
- 更高 rasterization 吞吐
- 更大缓存与更好的并行调度

### 7.6 近景运动实验

目标：

- 设计相机从远到近接近物体
- 比较 GS 与 RayGS 的几何一致性

建议观察对象：

- 桌角
- 椅子腿
- 墙角
- 围栏
- 花架

当前限制：

- 无内置轨迹录制
- 无内置录像输出

因此建议配合外部录屏工具完成

## 8. 建议记录的数据指标

### 8.1 定量指标

- Scene
- Resolution
- Model Type
- Draw Method
- MSAA
- MIP bias
- FPS
- 1/FPS
- frame e2e
- projection
- rendering
- total splats
- visible splats
- GPU utilization
- memory.used
- power.draw

### 8.2 定性指标

- 边缘稳定性
- spikes 程度
- 几何一致性
- 细节保持程度
- 远景闪烁
- 抗锯齿效果

## 9. 建议生成的表格和图表

### 表格

1. 场景 vs FPS / Frame Time / VRAM / GPU 利用率
2. GS vs RayGS 近景主观对比表
3. 不同 `MIP bias / MSAA` 下的画质-性能表

### 图表

1. 分辨率 vs FPS 折线图
2. Gaussian 数量 vs FPS 散点图
3. GS / RayGS / Mip-RayGS 局部放大图
4. RTX2080 vs RTX4080 柱状对比图

## 10. 可直接写进课程报告的分析要点

1. 当前仓库已实现 GS 与 RayGS 两条主渲染路径，并支持 MIP 相关参数与 2x/4x MSAA。
2. RayGS 相比 GS 在近景观察下通常具有更好的几何一致性，更少的尖刺和漂浮边缘。
3. MIP-RayGS 适合改善远景高频结构的闪烁与锯齿，但会带来一定模糊与性能开销。
4. 分辨率升高会降低 FPS，但下降不完全由排序阶段决定，更多体现在最终光栅与混合阶段。
5. 模型规模对性能有显著影响，但 `visible splats` 往往比 `total splats` 更能解释实时性能差异。
6. RTX4080 相比 RTX2080 的性能优势不仅来自更高 FLOPS，还来自更高带宽、更大缓存和更强的硬件图形管线吞吐。

## 11. 当前限制与后续建议

当前仍未自动化的部分：

- Viewer 内部 FPS / frame e2e 自动写文件
- 截图导出
- 视频导出
- 相机轨迹记录与回放

建议下一步扩展：

1. 将 Viewer 面板中的性能指标写入 CSV
2. 增加截图导出接口
3. 增加相机路径录制/回放
4. 增加批量多场景跑实验脚本

---

## 结果输出约定

后续实验结果请统一放在本仓库目录下：

```text
vkraygs/experiment-results/
```

建议按如下结构组织：

```text
experiment-results/
├── gpu/           # nvidia-smi 原始日志与摘要
├── screenshots/   # 截图
├── videos/        # 录屏
├── tables/        # 统计表
└── notes/         # 实验记录与观察结论
```

如果后续继续扩展脚本，建议也遵守这个目录结构，便于课程报告整理。
