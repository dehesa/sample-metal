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

struct UnfairLock {
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
