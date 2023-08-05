import simd

/// The vertices being fed to the GPU.
struct ShaderVertex {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
  var texCoords: SIMD2<Float>
}

struct ShaderUniforms {
  var modelViewProjectionMatrix: float4x4
  var modelViewMatrix: float4x4
  var normalMatrix: float3x3
}
