#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex shader

struct QuadVertexIn {
  float2 position  [[attribute(0)]];
  float2 texCoords [[attribute(1)]];
};

struct QuadVertexOut {
  float4 position [[position]];
  float2 texCoords;
};

[[vertex]] QuadVertexOut secondPassVertex(
  QuadVertexIn in [[stage_in]]
) {
  return QuadVertexOut {
    .position = float4(in.position, 0, 1),
    .texCoords = in.texCoords
  };
}

// MARK: - Fragment shaders

// Texture coordinates range [0, 1].
// X-positive values go from the top-left to the top-right;
// Y-positive go from top-left to bottom-left.
constexpr sampler sampler2d(coord::normalized,filter::linear);

/// Makes no changes onto the framebuffer.
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
[[fragment]] half4 second_passthrough(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  float4 const color = texture.sample(sampler2d, in.texCoords);
  return half4(half3(color.rgb), 1);
}

/// Flips the framebuffer vertically.
///
/// Notice that the Y-axis goes positive downwards. Thus, when fragCoords.y is negated, the image is reflected over the X-axis.
/// Since the coordinates range is [0,1], the reflection is translated a full height (i.e.: 1).
[[fragment]] half4 second_mirror(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  float2 const result = float2(in.texCoords.x, 1.0f - in.texCoords.y);
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}

/// Mirrors the framebuffer over the X-axis from the y values at the 0.5 value.
[[fragment]] half4 second_symmetry(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  float2 const result = float2(in.texCoords.x, 0.5f - abs(in.texCoords.y - 0.5));
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}

/// Rotates the framebuffer by `rotationAngle`, which in this case is 𝝉/8 (i.e. 45°).
[[fragment]] half4 second_rotation(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  /// Size of the drawing area in pixel numbers.
  float2 const screenSize = float2(texture.get_width(), texture.get_height());
  float2 const centered = in.texCoords - 0.5f;
  // The fragment coordinates are normalized (range [0,1]). However the viewport is range [w,h].
  // If when rotating, the aspect ratio is not accounted for, we will get a distorted image.
  float2 const absoluteCoords = centered * screenSize;

  float2 const polarCoords = float2(length(absoluteCoords), atan2(absoluteCoords.y, absoluteCoords.x));
  float const rotationAngle = M_PI_F / 4.0f;       // 𝝉/8 == 45°
  float const 𝛂 = polarCoords[1] - rotationAngle;

  float2 const rotatedCoords = polarCoords[0] * float2(cos(𝛂), sin(𝛂));
  float2 const normalizedCoords = rotatedCoords / screenSize;

  float2 const result = normalizedCoords + 0.5;
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}

/// Zooms-in on the center of the texture.
[[fragment]] half4 second_zoom(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  float2 const centered = in.texCoords - 0.5f;
  float2 const blowCoords = 0.5 * centered;
  float2 const result = blowCoords + 0.5f;
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}

/// Zoom-lens distorion around the center of the texture.
[[fragment]] half4 second_zoomDistortion(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  float2 const centered = in.texCoords - 0.5f;
  // Smoothstep(min,max,v) returns 0 if v<=min and 1 if v>=max and performs a smooth Hermite interpolation between 0 and 1 when v€(min,max)
  float2 const distortion = smoothstep(0.0f, 0.5f, length(centered)) * centered;
  float2 const result = distortion + 0.5;
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}

/// Repetes the texture a given amount of times (both in X- and Y-direction.
[[fragment]] half4 second_repetitions(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  /// Number of repetitions on the X- and Y-axes.
  float2 const repetitions = float2(4);
  float2 const result = fmod(in.texCoords, 1.0f/repetitions) * repetitions;
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}

/// Rotates the framebuffer depending on the polar coordinates length. The farther away from pikachu's center, the more rotated it is.
[[fragment]] half4 second_spiral(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  float2 const centered = in.texCoords - 0.5f;
  float2 const polarCoords = float2(length(centered), atan2(centered.y, centered.x));

  float const lmax = length(float2(0.5f)), anglemax = -M_PI_F;
  float const 𝛂 = polarCoords[1] + smoothstep(0.25*lmax,lmax,polarCoords[0]) * anglemax;

  float2 const rotatedCoords = polarCoords[0] * float2(cos(𝛂), sin(𝛂));
  float2 const result = rotatedCoords + 0.5;
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}

/// ...
[[fragment]] half4 second_thunder(
  QuadVertexOut in [[stage_in]],
  texture2d<float,access::sample> texture [[texture(0)]]
) {
  float2 const screenSize = float2(texture.get_width(), texture.get_height());
  float const repetitions = 8;
  float2 const centered = in.texCoords - float2(0.5f, 1.0f);
  float2 const absoluteCoords = centered * screenSize;
  float2 const polarCoords = float2(length(absoluteCoords), atan2(absoluteCoords.y, absoluteCoords.x));

  float const l = polarCoords[0];
  float const 𝛂 = //polarCoords[1];
  fmod(polarCoords[1], 2.0f*M_PI_F/repetitions)*repetitions;
  float2 const rotatedCoords = l * float2(cos(𝛂), sin(𝛂));

  float2 const normalizedCoords = rotatedCoords / screenSize;
  float2 const result = normalizedCoords + float2(0.5f, 1.0f);
  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);

  //    float2 const centered = fragCoords - 0.5f;
  //    float const 𝝉 = 2.0*M_PI_F;
  //
  //    float const aspect = (float)screenSize.x / (float)screenSize.y;
  //    float2 const absoluteCoords = float2(centered.x * aspect, centered.y);
  //    float2 const polarCoords = float2(length(absoluteCoords), atan2(absoluteCoords.y, absoluteCoords.x));
  //
  //    float2 const transCoords = float2(exp(polarCoords[0] + 1.0f), polarCoords[1]/(𝝉/repetitions));
  //    float2 const result = abs(float2(transCoords[1], transCoords[0]));
  //    return fmod(result + 0.5f, 1.0f);
}
