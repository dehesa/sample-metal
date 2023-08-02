import simd

/// The vertices being fed to the GPU.
struct ShaderVertex {
  var position: SIMD4<Float>
  var color: SIMD4<Float>
}

struct ShaderUniforms {
  var mvpMatrix: float4x4
}
