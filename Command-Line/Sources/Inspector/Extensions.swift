import Foundation
import Metal

extension NSObjectProtocol {
  /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
  /// - parameter block: Closure executing a given task on the receiving function value.
  /// - returns: The modified value
  @discardableResult public func configure(_ block: (Self)->Void) -> Self {
    block(self)
    return self
  }
}

extension String {
  static var targetIdentifier: Self {
    "io.dehesa.metal.commandline.gpgpu.detector"
  }

  static func identify(_ suffix: Self) -> Self {
    precondition(suffix.allSatisfy { !$0.isWhitespace })
    var result: String = targetIdentifier
    if !suffix.hasPrefix(".") { result.append(".") }
    result.append(suffix)
    return result
  }
}

extension MTLDeviceLocation: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .builtIn: "Built-in"
    case .slot: "Slot"
    case .external: "External"
    default: "Unspecified/Undetermined"
    }
  }
}

extension FormatStyle where Self == ByteCountFormatStyle {
  static var memory: ByteCountFormatStyle {
    .byteCount(style: .memory)
  }
}

extension MTLGPUFamily: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .metal3: "metal 3"
    case .apple1: "apple 1"
    case .apple2: "apple 2"
    case .apple3: "apple 3"
    case .apple4: "apple 4"
    case .apple5: "apple 5"
    case .apple6: "apple 6"
    case .apple7: "apple 7"
    case .apple8: "apple 8"
    case .common1: "common 1"
    case .common2: "common 2"
    case .common3: "common 3"
    default: "??"
    }
  }
}
