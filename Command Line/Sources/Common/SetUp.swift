import Foundation

// Swift doesn't allow to extend a protocol with another protocol; however, we can do default implementation for a specific protocol.
extension NSObjectProtocol {
    /// Makes the receiving value accessible within the passed block parameter.
    /// - parameter block: Closure executing a given task on the receiving function value.
    public func setUp(_ block: (Self)->Void) {
        block(self)
    }
    
    /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
    /// - parameter block: Closure executing a given task on the receiving function value.
    /// - returns: The modified value
    public func set(_ block: (Self)->Void) -> Self {
        block(self)
        return self
    }
}
