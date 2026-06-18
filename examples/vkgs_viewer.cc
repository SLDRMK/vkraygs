#include <algorithm>
#include <array>
#include <cctype>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

#include <argparse/argparse.hpp>

#include <vkgs/engine/engine.h>

namespace {

std::string ToLower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return value;
}

bool ParseOnOff(const std::string& value, const std::string& name) {
  const auto normalized = ToLower(value);
  if (normalized == "on" || normalized == "true" || normalized == "1") return true;
  if (normalized == "off" || normalized == "false" || normalized == "0") return false;
  throw std::invalid_argument("Invalid value for --" + name + ": " + value);
}

vkgs::Engine::DisplayMode ParseDisplayMode(const std::string& value) {
  const auto normalized = ToLower(value);
  if (normalized == "windowed") return vkgs::Engine::DisplayMode::Windowed;
  if (normalized == "fullscreen" || normalized == "windowed-fullscreen") {
    return vkgs::Engine::DisplayMode::WindowedFullscreen;
  }
  throw std::invalid_argument("Invalid value for --display-mode: " + value);
}

vkgs::Engine::Msaa ParseMsaa(const std::string& value) {
  const auto normalized = ToLower(value);
  if (normalized == "off" || normalized == "1x") return vkgs::Engine::Msaa::Off;
  if (normalized == "2x" || normalized == "2") return vkgs::Engine::Msaa::X2;
  if (normalized == "4x" || normalized == "4") return vkgs::Engine::Msaa::X4;
  throw std::invalid_argument("Invalid value for --msaa: " + value);
}

vkgs::Engine::DepthFormat ParseDepthFormat(const std::string& value) {
  const auto normalized = ToLower(value);
  if (normalized == "u16") return vkgs::Engine::DepthFormat::U16;
  if (normalized == "f32") return vkgs::Engine::DepthFormat::F32;
  throw std::invalid_argument("Invalid value for --depth: " + value);
}

vkgs::Engine::DrawMethod ParseDrawMethod(const std::string& value) {
  const auto normalized = ToLower(value);
  if (normalized == "triangles" || normalized == "triangle") return vkgs::Engine::DrawMethod::Triangles;
  if (normalized == "geom" || normalized == "geometry" || normalized == "geometry-shader") {
    return vkgs::Engine::DrawMethod::GeometryShader;
  }
  throw std::invalid_argument("Invalid value for --draw-method: " + value);
}

vkgs::Engine::ModelType ParseModelType(const std::string& value) {
  const auto normalized = ToLower(value);
  if (normalized == "gs" || normalized == "vkgs") return vkgs::Engine::ModelType::GS;
  if (normalized == "raygs" || normalized == "vkraygs") return vkgs::Engine::ModelType::RayGS;
  throw std::invalid_argument("Invalid value for --model-type: " + value);
}

glm::vec3 ParseVec3(const std::string& value, const std::string& name) {
  const auto normalized = value.rfind("v:", 0) == 0 ? value.substr(2) : value;
  std::array<float, 3> out = {};
  std::stringstream ss(normalized);
  std::string item;
  for (size_t i = 0; i < out.size(); ++i) {
    if (!std::getline(ss, item, ',')) {
      throw std::invalid_argument("Invalid value for --" + name + ": " + value);
    }
    out[i] = std::stof(item);
  }
  if (std::getline(ss, item, ',')) {
    throw std::invalid_argument("Invalid value for --" + name + ": " + value);
  }
  return {out[0], out[1], out[2]};
}

}  // namespace

int main(int argc, char** argv) {
  argparse::ArgumentParser parser("vkgs");
  parser.add_argument("-i", "--input").help("input ply file.");
  parser.add_argument("--width").default_value(std::string("1600")).help("initial window width");
  parser.add_argument("--height").default_value(std::string("900")).help("initial window height");
  parser.add_argument("--display-mode").default_value(std::string("windowed")).help("windowed or fullscreen");
  parser.add_argument("--vsync").default_value(std::string("on")).help("on/off");
  parser.add_argument("--msaa").default_value(std::string("off")).help("off, 2x, 4x");
  parser.add_argument("--depth").default_value(std::string("f32")).help("u16 or f32");
  parser.add_argument("--draw-method").default_value(std::string("triangles")).help("triangles or geom");
  parser.add_argument("--model-type").default_value(std::string("raygs")).help("gs or raygs");
  parser.add_argument("--mip-bias").default_value(std::string("0.1")).help("mip bias");
  parser.add_argument("--mip-modulation").default_value(std::string("on")).help("on/off");
  parser.add_argument("--log-p-min").default_value(std::string("-4.0")).help("log p min");
  parser.add_argument("--axis").default_value(std::string("on")).help("on/off");
  parser.add_argument("--grid").default_value(std::string("on")).help("on/off");
  parser.add_argument("--metrics-csv").default_value(std::string("")).help("metrics csv output path");
  parser.add_argument("--warmup-sec").default_value(std::string("5")).help("warmup seconds before sampling");
  parser.add_argument("--capture-sec").default_value(std::string("10")).help("capture seconds for metrics");
  parser.add_argument("--auto-exit").default_value(std::string("off")).help("on/off");
  parser.add_argument("--camera-position").default_value(std::string("")).help("camera eye as x,y,z");
  parser.add_argument("--camera-forward").default_value(std::string("")).help("camera forward as x,y,z");
  parser.add_argument("--camera-up").default_value(std::string("")).help("camera up as x,y,z");
  parser.add_argument("--camera-fx").default_value(std::string("")).help("camera fx from cameras.json");
  parser.add_argument("--camera-fy").default_value(std::string("")).help("camera fy from cameras.json");
  parser.add_argument("--camera-image-width").default_value(std::string("")).help("camera calibration image width");
  parser.add_argument("--camera-image-height").default_value(std::string("")).help("camera calibration image height");
  try {
    parser.parse_args(argc, argv);
  } catch (const std::exception& err) {
    std::cerr << err.what() << std::endl;
    std::cerr << parser;
    return 1;
  }

  try {
    vkgs::Engine engine;
    vkgs::Engine::StartupOptions options;
    options.width = std::stoi(parser.get<std::string>("width"));
    options.height = std::stoi(parser.get<std::string>("height"));
    options.display_mode = ParseDisplayMode(parser.get<std::string>("display-mode"));
    options.vsync = ParseOnOff(parser.get<std::string>("vsync"), "vsync");
    options.msaa = ParseMsaa(parser.get<std::string>("msaa"));
    options.depth_format = ParseDepthFormat(parser.get<std::string>("depth"));
    options.draw_method = ParseDrawMethod(parser.get<std::string>("draw-method"));
    options.model_type = ParseModelType(parser.get<std::string>("model-type"));
    options.mip_bias = std::stof(parser.get<std::string>("mip-bias"));
    options.mip_modulation = ParseOnOff(parser.get<std::string>("mip-modulation"), "mip-modulation");
    options.log_p_min = std::stof(parser.get<std::string>("log-p-min"));
    options.show_axis = ParseOnOff(parser.get<std::string>("axis"), "axis");
    options.show_grid = ParseOnOff(parser.get<std::string>("grid"), "grid");
    options.metrics_csv_path = parser.get<std::string>("metrics-csv");
    options.warmup_seconds = std::stod(parser.get<std::string>("warmup-sec"));
    options.capture_seconds = std::stod(parser.get<std::string>("capture-sec"));
    options.auto_close = ParseOnOff(parser.get<std::string>("auto-exit"), "auto-exit");

    const auto camera_position = parser.get<std::string>("camera-position");
    const auto camera_forward = parser.get<std::string>("camera-forward");
    const auto camera_up = parser.get<std::string>("camera-up");
    if (!camera_position.empty() || !camera_forward.empty() || !camera_up.empty()) {
      if (camera_position.empty() || camera_forward.empty() || camera_up.empty()) {
        throw std::invalid_argument(
            "--camera-position, --camera-forward and --camera-up must be provided together");
      }
      options.use_camera_override = true;
      options.camera_position = ParseVec3(camera_position, "camera-position");
      options.camera_forward = ParseVec3(camera_forward, "camera-forward");
      options.camera_up = ParseVec3(camera_up, "camera-up");
    }

    const auto camera_fx = parser.get<std::string>("camera-fx");
    const auto camera_fy = parser.get<std::string>("camera-fy");
    const auto camera_image_width = parser.get<std::string>("camera-image-width");
    const auto camera_image_height = parser.get<std::string>("camera-image-height");
    if (!camera_fx.empty() || !camera_fy.empty() || !camera_image_width.empty() || !camera_image_height.empty()) {
      if (camera_fx.empty() || camera_fy.empty() || camera_image_width.empty() || camera_image_height.empty()) {
        throw std::invalid_argument(
            "--camera-fx, --camera-fy, --camera-image-width and --camera-image-height must be provided together");
      }
      options.use_camera_intrinsics = true;
      options.camera_fx = std::stof(camera_fx);
      options.camera_fy = std::stof(camera_fy);
      options.camera_image_width = std::stoi(camera_image_width);
      options.camera_image_height = std::stoi(camera_image_height);
    }

    engine.SetStartupOptions(options);

    if (parser.is_used("input")) {
      auto ply_filepath = parser.get<std::string>("input");
      engine.LoadSplats(ply_filepath);
    }

    engine.Run();
  } catch (const std::exception& e) {
    std::cerr << e.what() << std::endl;
    return 1;
  }

  return 0;
}
