# VKRayGS 实验复现指南

本文档基于当前 `vkraygs` 仓库源码、README、Viewer UI、预训练模型 `models.zip` 以及本地新增的实验脚本整理，目标是在**不重新训练模型**的前提下，仅依赖作者提供的 `.ply` 模型和 Viewer，完成 VKRayGS 的主要复现实验与扩展实验。

本文档反映的是**当前已经完成修改后的真实状态**，包括：

- 已补充命令行实验参数
- 已支持 Viewer 性能指标导出 CSV
- 已支持 `nvidia-smi` 自动采样和摘要生成
- 已支持从 `models/<scene>/cameras.json` 读取训练相机参数
- 已支持除近景运动实验外，从 `cameras.json` 中**按随机种子稳定抽样 10 个视角**进行运行
- 已支持近景实验基于某个训练相机做 `dolly` 拉近/拉远

## 1. 仓库功能结构

```text
vkraygs
├── examples/vkgs_viewer.cc              # 程序入口，命令行参数解析
├── include/vkgs/engine/engine.h         # Engine 公共接口与启动参数
├── include/vkgs/scene/camera.h          # 相机接口，支持外部视图/投影覆盖
├── src/vkgs/engine/engine.cc            # UI、渲染模式切换、计时、主绘制逻辑、CSV 指标导出
├── src/vkgs/scene/camera.cc             # 相机控制、训练相机姿态/内参覆盖
├── src/vkgs/viewer/viewer.cc            # GLFW 窗口、分辨率、拖拽加载、ImGui
├── src/vkgs/engine/splat_load_thread.cc # PLY 加载与 Gaussian 数统计
├── src/vkgs/vulkan/swapchain.cc         # swapchain / vsync / present mode 选择
├── src/shader/projection.comp           # GS 投影路径
├── src/shader/raygs_projection.comp     # RayGS 投影路径
├── src/shader/splat.vert/.frag          # GS 光栅化路径
├── src/shader/raygs_splat.vert/.frag    # RayGS 光栅化路径
├── src/shader/splat_geom.vert/.geom     # GS 的 Geometry Shader 路径
├── run.sh                               # Vulkan SDK 环境包装脚本
├── all-in-one.sh                        # 单次实验一键脚本
├── camera_json_to_env.py                # 将 cameras.json 某一帧转为 Viewer 启动参数
├── exp_perf_table1.sh                   # Table 1 风格性能实验
├── exp_resolution_sweep.sh              # 分辨率扫描实验
├── exp_gs_vs_raygs.sh                   # GS vs RayGS 对比实验
├── exp_mip_sweep.sh                     # MIP / MSAA 对比实验
├── exp_nearfield_manual.sh              # 近景手动实验
├── run_all_experiments.sh               # 自动化实验总入口
├── build_tables.py                      # 汇总 metrics/gpu CSV 为总表
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
   - 注意：该模式会回到 `GS`

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

## 3. 程序入口、参数与相机控制

### 3.1 基础启动

```bash
./build/vkgs_viewer -i /path/to/model.ply
```

推荐正式实验时走 `run.sh` 或 `all-in-one.sh`，因为它们会自动设置 Vulkan 运行环境并整理输出文件。

### 3.2 已补充的实验参数

当前 Viewer 已支持以下实验相关参数：

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
  --grid off \
  --metrics-csv /tmp/viewer_metrics.csv \
  --warmup-sec 5 \
  --capture-sec 10 \
  --auto-exit on
```

### 3.3 训练相机参数覆盖

现在 Viewer 已支持把 `cameras.json` 中的相机姿态和内参直接覆盖到启动视角中。相关参数为：

```bash
--camera-position
--camera-forward
--camera-up
--camera-fx
--camera-fy
--camera-image-width
--camera-image-height
```

通常不需要手写这些值，而是通过：

```bash
./all-in-one.sh --scene bicycle --camera-json ../models/bicycle/cameras.json --camera-id 0
```

或者：

```bash
python3 ./camera_json_to_env.py --camera-json ../models/bicycle/cameras.json --camera-id 0
```

自动完成。

### 3.4 当前相机策略

根据当前实验要求，推荐策略如下：

1. **除近景运动实验外**
   - 使用各场景自己的 `models/<scene>/cameras.json`
   - 默认从中**随机抽样 10 个 `camera id`**
   - 抽样由固定随机种子控制，保证重跑时视角集合一致
   - 这样既能接近训练/数据集视角，又不会让实验量爆炸

2. **近景运动实验**
   - 从 `cameras.json` 中选一帧或数帧作为起点
   - 在该帧基础上做 `dolly` 拉近/拉远
   - 近景实验不自动退出，方便你手动观察和录屏

### 3.5 相机与快捷键

- 左键拖动：旋转
- 右键拖动：平移
- 左右键同时拖动：缩放
- 滚轮：缩放
- `Ctrl + 滚轮`：Dolly zoom / 改变 FOV
- `W/A/S/D/Space`：平移
- `Alt + Enter`：窗口/无边框全屏切换
- 支持将 `.ply` 直接拖进窗口加载

## 4. 一键实验脚本

### 4.1 单次实验入口

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
./all-in-one.sh --scene bicycle --camera-json ../models/bicycle/cameras.json --camera-id 0
./all-in-one.sh --scene bicycle --camera-json ../models/bicycle/cameras.json --camera-id 0 --camera-dolly 0.2
./all-in-one.sh --input /absolute/path/to/model.ply
```

### 4.2 批处理脚本

当前已有：

- `./exp_perf_table1.sh`
- `./exp_resolution_sweep.sh`
- `./exp_gs_vs_raygs.sh`
- `./exp_mip_sweep.sh`
- `./exp_nearfield_manual.sh`
- `./run_all_experiments.sh`

### 4.2.1 全部自动化实验启动命令

推荐直接使用：

```bash
cd /home/sldrmk/WorkSpace/ComputerGraphics/vkraygs
bash ./run_all_experiments.sh
```

说明：

- 这条命令会启动**全部自动化实验**
- 不包含近景运动手动录屏实验
- 推荐显式写成 `bash ./xxx.sh`，比直接 `./xxx.sh` 更稳一些

### 4.3 当前批处理脚本默认行为

当前脚本策略已经调整为：

1. `exp_perf_table1.sh`
   - 对 `bicycle / garden / room / bonsai` 的 `cameras.json` 中随机抽样 10 个视角进行测试

2. `exp_resolution_sweep.sh`
   - 对指定场景的 `cameras.json` 中随机抽样 10 个视角，在多分辨率下测试

3. `exp_gs_vs_raygs.sh`
   - 对指定场景的 `cameras.json` 中随机抽样 10 个视角，分别跑 `GS` 和 `RayGS`

4. `exp_mip_sweep.sh`
   - 对指定场景的 `cameras.json` 中随机抽样 10 个视角，分别跑 baseline / MSAA / Mip-RayGS

5. `exp_nearfield_manual.sh`
   - 读取某个 `camera_id`
   - 在该帧基础上支持 `dolly`
   - `auto-exit=off`
   - 适合你手动观察、录屏、截图

### 4.4 相机抽样参数

批处理脚本默认使用：

- `CAMERA_SAMPLE_COUNT=10`
- `CAMERA_SAMPLE_SEED=20250618`

如果你想改抽样数量或随机种子，可以在命令前临时指定：

```bash
CAMERA_SAMPLE_COUNT=10 CAMERA_SAMPLE_SEED=42 bash ./run_all_experiments.sh
```

或者：

```bash
CAMERA_SAMPLE_COUNT=5 CAMERA_SAMPLE_SEED=123 bash ./exp_gs_vs_raygs.sh truck
```

同一个场景、同一个随机种子、同一个抽样数量，会稳定得到同一组 `camera id`。

### 4.5 当前默认实验规模

按当前默认设置：

- 每个场景随机抽样 `10` 个视角
- 随机种子默认是 `20250618`

因此当前自动化实验不再是“全视角穷举”，而是“**每个场景固定 10 视角的可重现实验**”。

这意味着：

- 实验量已经从“几千次运行”降到了更可控的规模
- 不同实验之间仍然可以共享同一组抽样视角
- 重跑时结果具有可比性

## 5. Viewer 与脚本可直接记录的指标

### 5.1 Viewer 面板中可直接看到

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

### 5.2 现已支持自动写入 CSV 的指标

现在 Viewer 已支持通过 `--metrics-csv` 自动导出逐帧 CSV。当前会记录：

- 分辨率
- `model_type`
- `draw_method`
- `msaa`
- `vsync`
- `mip_bias`
- `mip_modulation`
- `log_p_min`
- `fps`
- `frame_time_ms`
- `frame_e2e_ms`
- `projection_ms`
- `rendering_ms`
- `visible_ratio`
- `total_splats`

`all-in-one.sh` 已自动接入：

- `--metrics-csv`
- `--warmup-sec`
- `--capture-sec`
- `--auto-exit`

所以正式性能实验不需要手抄 FPS。

### 5.3 仍需外部工具记录的指标

Viewer 当前仍**没有内置**以下内容：

- 显存占用
- GPU 利用率
- 功耗
- 温度
- 截图导出
- 录像导出
- 连续相机轨迹录制/回放

因此建议配合：

- `nvidia-smi`
- `OBS` / 系统录屏
- 手动截图

## 6. 脚本已纳入的自动化输出

`all-in-one.sh` 会把实验输出统一放到：

```text
vkraygs/experiment-results/
```

### 6.1 GPU 日志

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

### 6.2 Viewer 指标日志

运行结束后会生成：

```text
*_viewer_metrics.csv
*_viewer_metrics_summary.txt
```

摘要中包含：

- 平均/峰值 FPS
- 平均 frame time
- 平均 frame e2e
- 平均 projection / rendering 耗时
- 平均 visible ratio
- `total splats`

### 6.3 汇总表

`build_tables.py` 会扫描：

- `experiment-results/metrics`
- `experiment-results/gpu`

并生成：

```text
experiment-results/tables/run_summary.csv
```

当前汇总表已包含：

- `scene`
- `resolution`
- `model_type`
- `draw_method`
- `msaa`
- `vsync`
- `mip_bias`
- `fps_avg`
- `fps_max`
- `frame_time_avg_ms`
- `frame_e2e_avg_ms`
- `projection_avg_ms`
- `rendering_avg_ms`
- `visible_ratio_avg`
- `total_splats`
- `gpu_util_avg`
- `gpu_util_max`
- `vram_used_avg_mib`
- `vram_used_max_mib`
- `power_avg_w`
- `power_max_w`

## 7. 实验执行原则：性能与录屏分两遍

这是当前实验整理中非常重要的一点。

### 7.1 为什么要分两遍

录屏通常会导致 FPS 下降，因为它会额外占用：

- GPU 编码器资源
- 显存带宽
- 桌面合成与拷贝带宽
- 额外 CPU / I/O 开销

因此：

- **性能统计结果不要在录屏时采集**
- **录屏结果不要当作正式 FPS 数据**

### 7.2 推荐执行方式

1. **第一遍：纯性能采集**
   - 不录屏
   - 跑自动化脚本
   - 记录 `FPS / frame time / GPU util / VRAM`
   - 用于表格、曲线、定量分析

2. **第二遍：纯效果观察**
   - 单独开 Viewer
   - 配合录屏与截图
   - 只做主观现象分析
   - 不把这遍 FPS 写入正式性能结果

### 7.3 哪些实验需要录屏

建议录屏的实验：

1. **近景运动实验**
   - 最需要录屏
   - 观察 `GS` 与 `RayGS` 在接近物体过程中的几何一致性差异

2. **MIP / MSAA / RayGS 效果对比**
   - 远景高频结构更适合录视频观察闪烁与锯齿

3. **GS vs RayGS 近景局部对比**
   - 如果某些固定视角容易出现明显伪影，建议录短视频做补充

通常不需要录屏的实验：

- Table 1 风格性能实验
- 分辨率扫描实验
- Gaussian 数量 vs FPS
- RTX2080 vs RTX4080 扩展性能实验

## 8. 可执行实验清单

### 8.1 VKRayGS 性能复现实验

目标：

- 选择 `bicycle`、`garden`、`room`、`bonsai`
- 固定 `1080p`
- 记录 `FPS`、`Frame Time`、`GPU 显存占用`
- 与论文 Table 1 对比

当前建议：

- 使用各场景自己的 `cameras.json`
- 默认随机抽样 10 个固定视角
- 不录屏

推荐命令：

```bash
./exp_perf_table1.sh
```

需要记录：

- `run_summary.csv` 或 `*_viewer_metrics_summary.txt` 中的平均 FPS / frame time
- `*_gpu_summary.txt` 中的显存 / GPU 利用率 / 功耗

### 8.2 分辨率扫描实验

目标：

- 比较 `720p / 1080p / 1440p / 4k`
- 分析分辨率对 FPS 的影响

当前建议：

- 固定场景，例如 `bicycle`
- 使用该场景 `cameras.json` 中随机抽样 10 个固定视角
- 不录屏

推荐命令：

```bash
./exp_resolution_sweep.sh bicycle
```

### 8.3 VKGS 与 VKRayGS 对比实验

目标：

- 同一场景、同一视角下比较 `GS` 与 `RayGS`
- 比较 FPS 和画质
- 观察近景几何伪影

当前建议：

- 用 `cameras.json` 的同一组抽样视角做两次运行
- 第一遍不录屏，拿定量数据
- 第二遍挑选典型视角录屏和截图

推荐命令：

```bash
./exp_gs_vs_raygs.sh truck
```

重点关注：

- `GS` 更容易出现 `spikes`
- 漂浮边缘
- 细杆和边缘厚度不一致
- `RayGS` 在近景几何上更稳定

### 8.4 MIP Anti-Aliasing 实验

目标：

- 比较 `VKRayGS`、`MSAA`、`Mip-RayGS`
- 观察远景高频结构的锯齿与闪烁

当前建议：

- 第一遍不录屏，拿性能结果
- 第二遍录屏观察细节闪烁

推荐命令：

```bash
./exp_mip_sweep.sh bicycle
```

重点观察：

- 辐条
- 树枝
- 围栏
- 远景细线结构

### 8.5 模型规模与性能关系实验

目标：

- 统计不同场景 Gaussian 数量
- 建立 Gaussian 数量与 FPS 的关系

可直接使用：

- `total splats` 作为 Gaussian 数量

记录：

- `total_splats`
- `visible_ratio`
- `fps_avg`
- `frame_e2e_avg_ms`

### 8.6 RTX2080 vs RTX4080 扩展实验

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

### 8.7 近景运动实验

目标：

- 设计相机从远到近接近物体
- 比较 `GS` 与 `RayGS` 的几何一致性

建议观察对象：

- 桌角
- 椅子腿
- 墙角
- 围栏
- 花架

当前推荐方法：

1. 从 `cameras.json` 中选择一帧作为起点
2. 用 `--camera-dolly` 做前后偏移
3. 进入 Viewer 后继续手动微调
4. 配合录屏完成主观对比

推荐命令：

```bash
./exp_nearfield_manual.sh bicycle gs 1080p 0 0.0
./exp_nearfield_manual.sh bicycle raygs 1080p 0 0.0
./exp_nearfield_manual.sh bicycle raygs 1080p 0 0.2
./exp_nearfield_manual.sh bicycle raygs 1080p 0 -0.2
```

## 9. 建议记录的数据指标

### 9.1 定量指标

- Scene
- Camera ID
- Resolution
- Model Type
- Draw Method
- MSAA
- MIP bias
- FPS
- frame time
- frame e2e
- projection
- rendering
- total splats
- visible ratio
- GPU utilization
- memory.used
- power.draw

### 9.2 定性指标

- 边缘稳定性
- spikes 程度
- 几何一致性
- 细节保持程度
- 远景闪烁
- 抗锯齿效果
- 近景厚度一致性

## 10. 建议生成的表格和图表

### 表格

1. 场景 vs FPS / Frame Time / VRAM / GPU 利用率
2. 分辨率 vs FPS / Frame Time 表
3. GS vs RayGS 近景主观对比表
4. 不同 `MIP bias / MSAA` 下的画质-性能表

### 图表

1. 分辨率 vs FPS 折线图
2. Gaussian 数量 vs FPS 散点图
3. GS / RayGS / Mip-RayGS 局部放大图
4. RTX2080 vs RTX4080 柱状对比图

## 11. 可直接写进课程报告的分析要点

1. 当前仓库已实现 `GS` 与 `RayGS` 两条主渲染路径，并支持 `MIP` 相关参数与 `2x/4x MSAA`。
2. `RayGS` 相比 `GS` 在近景观察下通常具有更好的几何一致性，更少的尖刺和漂浮边缘。
3. `Mip-RayGS` 适合改善远景高频结构的闪烁与锯齿，但会带来一定模糊与性能开销。
4. 分辨率升高会降低 FPS，但下降不完全由排序阶段决定，更多体现在最终光栅与混合阶段。
5. 模型规模对性能有显著影响，但 `visible splats` 或 `visible ratio` 往往比 `total splats` 更能解释实时性能差异。
6. RTX4080 相比 RTX2080 的性能优势不仅来自更高 FLOPS，还来自更高带宽、更大缓存和更强的硬件图形管线吞吐。
7. 使用 `cameras.json` 的训练相机序列可以减少默认视角偏差，使复现实验中的视角控制更稳定、更可比。
8. 性能实验应在**不录屏**条件下采集；录屏应单独作为效果观察流程，不纳入正式性能统计。

## 12. 当前限制与后续建议

当前仍未自动化的部分：

- Viewer 内置截图导出
- Viewer 内置视频导出
- 连续相机轨迹录制与回放
- 在单次启动中自动连续播放整段相机路径

当前已经完成自动化的部分：

- Viewer 指标写入 CSV
- GPU 指标自动采样与摘要
- 批量实验脚本
- 训练相机视角覆盖

建议后续扩展：

1. 增加截图导出接口
2. 增加相机路径连续回放
3. 增加序列采样控制，例如 `camera step / limit / subset`
4. 在汇总表中显式加入 `camera_id`

---

## 结果输出约定

后续实验结果统一放在：

```text
vkraygs/experiment-results/
```

推荐目录结构：

```text
experiment-results/
├── gpu/           # nvidia-smi 原始日志与摘要
├── metrics/       # Viewer 逐帧 CSV 与摘要
├── screenshots/   # 截图
├── videos/        # 录屏
├── tables/        # 汇总表
└── notes/         # 实验记录与观察结论
```

### 当前建议的整理方式

1. 自动化脚本先跑一遍，不录屏，生成 `gpu/`、`metrics/`、`tables/`
2. 再单独跑一遍主观效果实验，生成 `screenshots/`、`videos/`、`notes/`
3. 课程报告优先引用第一遍的定量结果，第二遍只用于展示现象和局部细节
