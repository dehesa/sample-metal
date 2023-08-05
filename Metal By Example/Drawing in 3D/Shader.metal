#include <metal_stdlib>
using namespace metal;

struct ShaderVertex {
  float4 position [[position]];
  float4 color;
};

struct ShaderUniforms {
  float4x4 mvpMatrix;
};

[[vertex]] ShaderVertex main_vertex(
  device ShaderVertex const* const vertices [[buffer(0)]],
  constant ShaderUniforms* uniforms [[buffer(1)]],
  uint vid [[vertex_id]]
) {
  return ShaderVertex {
    .position = uniforms->mvpMatrix * vertices[vid].position,
    .color = vertices[vid].color
  };
}

[[fragment]] float4 main_fragment(
  ShaderVertex interpolatedVertex [[stage_in]]
) {
  return interpolatedVertex.color;
}
