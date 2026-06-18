#include <vkgs/scene/camera.h>

#include <algorithm>

#include <glm/gtc/matrix_transform.hpp>

namespace vkgs {

Camera::Camera() {}

Camera::~Camera() {}

void Camera::SetWindowSize(uint32_t width, uint32_t height) {
  width_ = width;
  height_ = height;
}

void Camera::SetViewOverride(const glm::vec3& eye, const glm::vec3& forward, const glm::vec3& up) {
  eye_override_ = eye;
  forward_override_ = glm::normalize(forward);
  up_override_ = glm::normalize(up);
  use_view_override_ = true;
}

void Camera::ClearViewOverride() { use_view_override_ = false; }

void Camera::SetPerspectiveFromIntrinsics(float fx, float fy, uint32_t image_width, uint32_t image_height) {
  fx_override_ = fx;
  fy_override_ = fy;
  image_width_override_ = image_width;
  image_height_override_ = image_height;
  use_projection_override_ = true;
}

void Camera::ClearPerspectiveOverride() { use_projection_override_ = false; }

void Camera::SetFov(float fov) {
  // dolly zoom
  r_ *= std::tan(fovy_ / 2.f) / std::tan(fov / 2.f);

  fovy_ = fov;
}

glm::mat4 Camera::ProjectionMatrix() const {
  if (use_projection_override_) {
    glm::mat4 projection(0.f);
    projection[0][0] = 2.f * fx_override_ / static_cast<float>(image_width_override_);
    projection[1][1] = 2.f * fy_override_ / static_cast<float>(image_height_override_);
    projection[2][2] = -(far_ + near_) / (far_ - near_);
    projection[2][3] = -1.f;
    projection[3][2] = -(2.f * far_ * near_) / (far_ - near_);

    glm::mat4 conversion = glm::mat4(1.f);
    conversion[1][1] = -1.f;
    conversion[2][2] = 0.5f;
    conversion[3][2] = 0.5f;
    return conversion * projection;
  }

  float aspect = static_cast<float>(width_) / height_;
  glm::mat4 projection = glm::perspective(fovy_, aspect, near_, far_);

  // gl to vulkan projection matrix
  glm::mat4 conversion = glm::mat4(1.f);
  conversion[1][1] = -1.f;
  conversion[2][2] = 0.5f;
  conversion[3][2] = 0.5f;
  return conversion * projection;
}

glm::mat4 Camera::ViewMatrix() const {
  if (use_view_override_) {
    return glm::lookAt(eye_override_, eye_override_ + forward_override_, up_override_);
  }
  return glm::lookAt(Eye(), center_, glm::vec3(0.f, 1.f, 0.f));
}

glm::vec3 Camera::Eye() const {
  if (use_view_override_) return eye_override_;
  const auto sin_phi = std::sin(phi_);
  const auto cos_phi = std::cos(phi_);
  const auto sin_theta = std::sin(theta_);
  const auto cos_theta = std::cos(theta_);
  return center_ + r_ * glm::vec3(sin_phi * sin_theta, cos_phi, sin_phi * cos_theta);
}

void Camera::Rotate(float x, float y) {
  theta_ -= rotation_sensitivity_ * x;
  float eps = glm::radians(0.1f);
  phi_ = std::clamp(phi_ - rotation_sensitivity_ * y, eps, glm::pi<float>() - eps);
}

void Camera::Translate(float x, float y, float z) {
  // camera = center + r (sin phi sin theta, cos phi, sin phi cos theta)
  const auto sin_phi = std::sin(phi_);
  const auto cos_phi = std::cos(phi_);
  const auto sin_theta = std::sin(theta_);
  const auto cos_theta = std::cos(theta_);
  center_ +=
      translation_sensitivity_ * r_ *
      (-x * glm::vec3(cos_theta, 0.f, -sin_theta) + y * glm::vec3(-cos_phi * sin_theta, sin_phi, -cos_phi * cos_theta) +
       -z * glm::vec3(sin_phi * sin_theta, cos_phi, sin_phi * cos_theta));
}

void Camera::Zoom(float x) { r_ /= std::exp(zoom_sensitivity_ * x); }

void Camera::DollyZoom(float scroll) {
  float new_fov = std::clamp(fovy_ - scroll * dolly_zoom_sensitivity_, min_fov(), max_fov());
  SetFov(new_fov);
}

}  // namespace vkgs
