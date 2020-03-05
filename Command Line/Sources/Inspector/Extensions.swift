import Foundation
import Metal

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

extension MTLDeviceLocation: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .builtIn: return "Built-in"
        case .slot: return "Slot"
        case .external: return "External"
        default: return "Unspecified/Undetermined"
        }
    }
}

extension DefaultStringInterpolation {
    /// Takes a number of bytes of outputs a human readable version.
    mutating func appendInterpolation(bytes: UInt64) {
        let formatter = ByteCountFormatter()
        guard let result = formatter.string(for: bytes) else { fatalError() }
        self.appendInterpolation(result)
    }
}
