import Foundation

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

struct Lock {
  let ptr: UnsafeMutablePointer<os_unfair_lock>

  @_transparent init() {
    ptr = .allocate(capacity: 1)
    ptr.initialize(to: os_unfair_lock())
  }

  @_transparent func lock() {
    os_unfair_lock_lock(ptr)
  }

  @_transparent func unlock() {
    os_unfair_lock_unlock(ptr)
  }

  @discardableResult @_transparent func sync<T>(within closure: () throws -> T) rethrows -> T {
    os_unfair_lock_lock(ptr)
    let result = try closure()
    os_unfair_lock_unlock(ptr)
    return result
  }

  @_transparent func invalidate() {
    ptr.deinitialize(count: 1)
    ptr.deallocate()
  }
}

// MARK: -

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
