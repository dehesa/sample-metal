import Foundation
import Metal

public protocol SetUp { }

public extension SetUp where Self: Any {
    /// Makes the receiving value accessible within the passed block parameter.
    /// - parameter block: Closure executing a given task on the receiving function value.
    public func setUp(with block: (Self)->Void) {
        block(self)
    }
    
    /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
    /// - parameter block: Closure executing a given task on the receiving function value.
    /// - returns: The modified value
    public func set(with block: (inout Self)->Void) -> Self {
        var copy = self
        block(&copy)
        return copy
    }
}

public extension SetUp where Self: AnyObject {
    /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
    /// - parameter block: Closure executing a given task on the receiving function value.
    /// - returns: The modified value
    public func set(with block: (Self)->Void) -> Self {
        block(self)
        return self
    }
}

extension NSObject: SetUp {}
