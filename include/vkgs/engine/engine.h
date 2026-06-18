#ifndef VKGS_ENGINE_ENGINE_H
#define VKGS_ENGINE_ENGINE_H

#include <memory>
#include <string>

namespace vkgs {

class Splats;

class Engine {
 public:
  enum class ModelType {
    GS,
    RayGS,
  };

  enum class DrawMethod {
    Triangles,
    GeometryShader,
  };

  enum class DisplayMode {
    Windowed,
    WindowedFullscreen,
  };

  enum class Msaa {
    Off,
    X2,
    X4,
  };

  enum class DepthFormat {
    U16,
    F32,
  };

  struct StartupOptions {
    int width = 1600;
    int height = 900;
    DisplayMode display_mode = DisplayMode::Windowed;
    bool vsync = true;
    Msaa msaa = Msaa::Off;
    DepthFormat depth_format = DepthFormat::F32;
    DrawMethod draw_method = DrawMethod::Triangles;
    ModelType model_type = ModelType::RayGS;
    float mip_bias = 0.1f;
    bool mip_modulation = true;
    float log_p_min = -4.0f;
    bool show_axis = true;
    bool show_grid = true;
    std::string metrics_csv_path;
    double warmup_seconds = 5.0;
    double capture_seconds = 10.0;
    bool auto_close = false;
  };

  Engine();
  ~Engine();

  void LoadSplats(const std::string& ply_filepath);
  void LoadSplatsAsync(const std::string& ply_filepath);
  void SetStartupOptions(const StartupOptions& options);

  void Run();

  void Close();

 private:
  class Impl;
  std::shared_ptr<Impl> impl_;
};

}  // namespace vkgs

#endif  // VKGS_ENGINE_ENGINE_H
