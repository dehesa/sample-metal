import Foundation

/// Conforming types expose helper function to configure inline.
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
