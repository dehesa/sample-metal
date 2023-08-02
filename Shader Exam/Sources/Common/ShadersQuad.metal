#include <metal_stdlib>
using namespace metal;

struct QuadVertexIn {
  float2 position  [[attribute(0)]];
  float2 texCoords [[attribute(1)]];
};

struct QuadVertexOut {
  float4 position [[position]];
  float2 texCoords;
};

vertex QuadVertexOut vertex_post(QuadVertexIn in [[stage_in]]) {
  return QuadVertexOut {
    .position = float4(in.position, 0, 1),
    .texCoords = in.texCoords
  };
}

// Page 1 shaders
float2 shaderPass(float2 const fragCoords);
float2 shaderMirror(float2 const fragCoords);
float2 shaderSymmetry(float2 const fragCoords);
float2 shaderRotation(float2 const fragCoords, float2 const screenSize);
float2 shaderZoom(float2 const fragCoords);
float2 shaderZoomDistortion(float2 const fragCoords);
float2 shaderRepetition(float2 const fragCoords, float2 const repetitions);
float2 shaderSpiral(float2 const fragCoords);
float2 shaderThunder(float2 const fragCoords, float2 const screenSize, float const repetitions);
// Page 2 shaders
half4 shaderClamp(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPli(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderColorDirection(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPixelation(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderVague(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderColonne(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderCrash(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderScanline(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderDoubleFrequency(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
// Page 3 shaders
half4 shaderBlackAndWhite(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderThreshold(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderThresholds(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderSonar(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderGrid(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderStamp(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderLocalNegative(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderChromaticAberration(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderChromaKey(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
// Page 4 shaders
half4 shaderVague2(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderChubby(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderSkinny(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderTwist(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderGlitch(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderGlitchVoxel(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderBasicShading(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderToonShading(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderCellShading(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
// Page 5 shaders
half4 shaderSphere(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderSphereRepeat(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPyramid(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPolarModulo(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderTubeTwist(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderTubeWeb(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderVolumetricCloud(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderStranglerFig(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderKirby(float2 const uv, texture2d<float,access::sample> texture, sampler s);   // TODO

fragment half4 fragment_post(QuadVertexOut in [[stage_in]], texture2d<float,access::sample> texture [[texture(0)]]) {
  // Constant sampler for the texture.
  constexpr sampler sampler2d(coord::normalized,filter::linear);
  // Texture coordinates range from 0 to 1. X-positive values go from the top-left to the top-right; while Y-positive go from top-left to bottom-left.

  float2 const result =
  // Page 1
  //shaderPass(in.texCoords);
  //shaderMirror(in.texCoords);
  //shaderSymmetry(in.texCoords);
  //shaderRotation(in.texCoords, float2(texture.get_width(), texture.get_height()));
  //shaderZoom(in.texCoords);
  //shaderZoomDistortion(in.texCoords);
  //shaderRepetition(in.texCoords, float2(4));
  //shaderSpiral(in.texCoords);
  shaderThunder(in.texCoords, float2(texture.get_width(), texture.get_height()), 8);

  float4 const color = texture.sample(sampler2d, result);
  return half4(half3(color.rgb), 1);
}
