import Foundation

extension CGRect: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByArrayLiteral {
  public init(integerLiteral value: Int) {
    let value = Double(value)
    self.init(origin: CGPoint(x: value, y: value), size: CGSize(width: value, height: value))
  }

  public init(floatLiteral value: Double) {
    self.init(origin: CGPoint(x: value, y: value), size: CGSize(width: value, height: value))
  }

  public init(arrayLiteral elements: CGFloat...) {
    switch elements.count {
    case 1: self.init(origin: CGPoint(), size: CGSize(width: elements[0], height: elements[0]))
    case 2: self.init(origin: CGPoint(), size: CGSize(width: elements[0], height: elements[1]))
    case 4: self.init(origin: CGPoint(x: elements[0], y: elements[1]), size: CGSize(width: elements[2], height: elements[3]))
    default: fatalError("\(Self.self) requires 2 or 4 arguments during initialization")
    }
  }
}

public extension NSObjectProtocol {
  @discardableResult func set(_ block: (Self)->Void) -> Self {
    block(self)
    return self
  }
}
