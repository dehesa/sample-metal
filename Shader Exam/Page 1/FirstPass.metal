#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex shader

struct VertexIn {
  float3 position  [[attribute(0)]];
  float3 normal    [[attribute(1)]];
  float2 texCoords [[attribute(2)]];
};

struct Uniforms {
  float4x4 modelViewMatrix;
  float4x4 projectionMatrix;
};

struct VertexOut {
  float4 position [[position]];
  float4 eyeNormal;
  float2 texCoords;
};

[[vertex]] VertexOut firstPassVertex(
  VertexIn in [[stage_in]],
  constant Uniforms &uniforms [[buffer(1)]]
) {
  return VertexOut {
    .position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(in.position, 1),
    .eyeNormal = uniforms.modelViewMatrix * float4(in.normal, 0),
    .texCoords = in.texCoords
  };
}

// MARK: - Fragment shader

[[fragment]] half4 firstPassFragment(
  VertexOut in [[stage_in]],
  texture2d<float,access::sample> diffuseTexture [[texture(0)]]
) {
  constexpr sampler sampler2d(coord::normalized, filter::linear);
  
  float4 const color = diffuseTexture.sample(sampler2d, in.texCoords);
  return half4(half3(color.rgb), 1);
}
