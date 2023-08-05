import Foundation
import simd

/// Conforming types expose helper function to perform inline configuration.
public protocol ConfigurableReference: AnyObject {
  /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
  /// - parameter block: Closure executing a given task on the receiving function value.
  /// - returns: The modified reference.
  @discardableResult func configure(_ block: (Self) -> Void) -> Self
}

extension ConfigurableReference {
  @_transparent @discardableResult public func configure(_ block: (Self) -> Void) -> Self {
    block(self)
    return self
  }
}

// Swift doesn't allow to extend a protocol with another protocol; however, we can do default implementation for a specific protocol.
extension NSObjectProtocol {
  @_transparent @discardableResult public func configure(_ block: (Self)->Void) -> Self {
    block(self)
    return self
  }
}

// MARK: -

public extension String {
  static let bundleId: Self = Bundle.main.bundleIdentifier!

  static func identifier(_ suffixes: String...) -> Self {
    var result = bundleId

    let dot: String = "."
    var endsInDot = result.hasSuffix(dot)

    for suffix in suffixes {
      switch (endsInDot, suffix.hasPrefix(dot)) {
      case (true, false), (false, true): break
      case (false, false): result.append(dot)
      case (true, true): result.removeLast()
      }

      result.append(suffix)
      endsInDot = suffix.hasSuffix(dot)
    }

    return result
  }
}

// MARK: -

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

extension CGPoint: Sequence, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByArrayLiteral {
  public init(integerLiteral value: Int) {
    self.init(x: CGFloat(value), y: CGFloat(value))
  }

  public init(floatLiteral value: Double) {
    self.init(x: value, y: value)
  }

  public init(arrayLiteral elements: CGFloat...) {
    switch elements.count {
    case 0: self.init()
    case 1: self.init(x: elements[0], y: elements[0])
    default: self.init(x: elements[0], y: elements[1])
    }
  }

  public func makeIterator() -> some IteratorProtocol<CGFloat> {
    PairIterator((self.x, self.y))
  }
}

extension CGSize: Sequence, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByArrayLiteral {
  public init(integerLiteral value: Int) {
    self.init(width: CGFloat(value), height: CGFloat(value))
  }

  public init(floatLiteral value: Double) {
    self.init(width: value, height: value)
  }

  public init(arrayLiteral elements: CGFloat...) {
    switch elements.count {
    case 0: self.init()
    case 1: self.init(width: elements[0], height: elements[0])
    default: self.init(width: elements[0], height: elements[1])
    }
  }

  public func makeIterator() -> some IteratorProtocol<CGFloat> {
    PairIterator((self.width, self.height))
  }
}

extension CGRect: Sequence, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByArrayLiteral {
  public init(integerLiteral value: Int) {
    self.init(origin: CGPoint(), size: CGSize(width: CGFloat(value), height: CGFloat(value)))
  }

  public init(floatLiteral value: Double) {
    self.init(origin: CGPoint(), size: CGSize(width: value, height: value))
  }

  public init(arrayLiteral elements: CGFloat...) {
    switch elements.count {
    case 0: self.init(origin: CGPoint(), size: CGSize())
    case 1: self.init(origin: CGPoint(), size: CGSize(width: elements[0], height: elements[0]))
    case 2: self.init(origin: CGPoint(), size: CGSize(width: elements[0], height: elements[1]))
    case 3: self.init(origin: CGPoint(x: elements[0], y: elements[0]), size: CGSize(width: elements[1], height: elements[2]))
    default: self.init(origin: CGPoint(x: elements[0], y: elements[1]), size: CGSize(width: elements[2], height: elements[3]))
    }
  }

  public func makeIterator() -> some IteratorProtocol<CGFloat> {
    QuadIterator((self.origin.x, self.origin.y, self.size.width, self.size.height))
  }
}

// MARK: -

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
    // List of the matrix' columns
    let baseX: SIMD4<Float> = [1, 0, 0, 0]
    let baseY: SIMD4<Float> = [0, 1, 0, 0]
    let baseZ: SIMD4<Float> = [0, 0, 1, 0]
    let baseW: SIMD4<Float> = [vector.x, vector.y, vector.z, 1]
    self.init(baseX, baseY, baseZ, baseW)
  }

  /// Creates a 4x4 matrix representing a uniform scale given by the provided scalar.
  /// - parameter s: Scalar giving the uniform magnitude of the scale.
  init(scale s: Float) {
    self.init(diagonal: [s, s, s, 1])
  }

  /// Creates a 4x4 matrix that will rotate through the given vector and given angle.
  /// - parameter angle: The amount of radians to rotate from the given vector center.
  init(rotate vector: SIMD3<Float>, angle: Float) {
    let c: Float = cos(angle)
    let s: Float = sin(angle)
    let cm = 1 - c

    let x0 = vector.x*vector.x + (1-vector.x*vector.x)*c
    let x1 = vector.x*vector.y*cm - vector.z*s
    let x2 = vector.x*vector.z*cm + vector.y*s

    let y0 = vector.x*vector.y*cm + vector.z*s
    let y1 = vector.y*vector.y + (1-vector.y*vector.y)*c
    let y2 = vector.y*vector.z*cm - vector.x*s

    let z0 = vector.x*vector.z*cm - vector.y*s
    let z1 = vector.y*vector.z*cm + vector.x*s
    let z2 = vector.z*vector.z + (1-vector.z*vector.z)*c

    // List of the matrix' columns
    let baseX: SIMD4<Float> = [x0, x1, x2, 0]
    let baseY: SIMD4<Float> = [y0, y1, y2, 0]
    let baseZ: SIMD4<Float> = [z0, z1, z2, 0]
    let baseW: SIMD4<Float> = [ 0,  0,  0, 1]
    self.init(baseX, baseY, baseZ, baseW)
  }

  /// Creates a perspective matrix from an aspect ratio, field of view, and near/far Z planes.
  init(perspectiveWithAspect aspect: Float, fovy: Float, near: Float, far: Float) {
    let yScale = 1 / tan(fovy * 0.5)
    let xScale = yScale / aspect
    let zRange = far - near
    let zScale = -(far + near) / zRange
    let wzScale = -2 * far * near / zRange

    // List of the matrix' columns
    let vectorP: SIMD4<Float> = [xScale,      0,       0,  0]
    let vectorQ: SIMD4<Float> = [     0, yScale,       0,  0]
    let vectorR: SIMD4<Float> = [     0,      0,  zScale, -1]
    let vectorS: SIMD4<Float> = [     0,      0, wzScale,  0]
    self.init(vectorP, vectorQ, vectorR, vectorS)
  }
}


// MARK: -

private struct PairIterator<T>: IteratorProtocol {
  private let elements: (T, T)
  private var index: Int = .zero

  init(_ elements: (T, T)) {
    self.elements = elements
  }

  mutating func next() -> T? {
    guard index < 2 else { return .none }
    defer { index += 1 }
    return withUnsafePointer(to: elements) {
      UnsafeRawPointer($0).assumingMemoryBound(to: T.self)[index]
    }
  }
}

private struct QuadIterator<T>: IteratorProtocol {
  private let elements: (T, T, T, T)
  private var index: Int = .zero

  init(_ elements: (T, T, T, T)) {
    self.elements = elements
  }

  mutating func next() -> T? {
    guard index < 4 else { return .none }
    defer { index += 1 }
    return withUnsafePointer(to: elements) {
      UnsafeRawPointer($0).assumingMemoryBound(to: T.self)[index]
    }
  }
}
