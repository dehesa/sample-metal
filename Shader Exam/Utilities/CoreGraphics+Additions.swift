import CoreGraphics

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
