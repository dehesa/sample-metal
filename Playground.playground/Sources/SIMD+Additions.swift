import simd

extension Double {
  /// Number of radians in *one turn*.
  @_transparent public static var τ: Double { Double.pi * 2 }
  /// Number of radians in *half a turn*.
  @_transparent public static var π: Double { Double.pi }
}

extension Float {
  /// Number of radians in *one turn*.
  @_transparent public static var τ: Float { Float(Double.τ) }
  /// Number of radians in *half a turn*.
  @_transparent public static var π: Float { Float(Double.π) }
}

extension SIMD4 {
  var xy: SIMD2<Scalar> {
    SIMD2([self.x, self.y])
  }

  var xyz: SIMD3<Scalar> {
    SIMD3([self.x, self.y, self.z])
  }
}

extension float4x4 {
  /// Creates a 4x4 matrix representing a translation given by the provided vector.
  /// - parameter vector: Vector giving the direction and magnitude of the translation.
  init(translate vector: SIMD3<Float>) {
    self.init(
      [1, 0, 0, 0],
      [0, 1, 0, 0],
      [0, 0, 1, 0],
      [vector.x, vector.y, vector.z, 1]
    )
  }

  /// Creates a 4x4 matrix representing a uniform scale given by the provided scalar.
  /// - parameter s: Scalar giving the uniform magnitude of the scale.
  init(scale s: Float) {
    self.init(diagonal: [s, s, s, 1])
  }

  /// Creates a 4x4 matrix that will rotate through the given vector and given angle.
  /// - parameter angle: The amount of radians to rotate from the given vector center.
  init(rotate axis: SIMD3<Float>, angle: Float) {
    let x = axis.x, y = axis.y, z = axis.z
    let c: Float = cos(angle)
    let s: Float = sin(angle)
    let t = 1 - c

    let x0 = t * x * x + c
    let x1 = t * x * y + z * s
    let x2 = t * x * z - y * s

    let y0 = t * x * y - z * s
    let y1 = t * y * y + c
    let y2 = t * y * z + x * s

    let z0 = t * x * z + y * s
    let z1 = t * y * z - x * s
    let z2 = t * z * z + c

    self.init(
      [x0, x1, x2, 0],
      [y0, y1, y2, 0],
      [z0, z1, z2, 0],
      [ 0,  0,  0, 1]
    )
  }

  /// Creates a perspective matrix from an aspect ratio, field of view, and near/far Z planes.
  init(perspectiveWithAspect aspect: Float, fovy: Float, near: Float, far: Float) {
    let yy = 1 / tan(fovy * 0.5)
    let xx = yy / aspect
    let zRange = far - near
    let zz = -(far + near) / zRange
    let ww = -2 * far * near / zRange

    self.init(
      [xx,  0,  0,  0],
      [ 0, yy,  0,  0],
      [ 0,  0, zz, -1],
      [ 0,  0, ww,  0]
    )
  }
}
