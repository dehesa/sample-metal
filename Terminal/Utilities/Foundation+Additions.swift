import Foundation

extension NSObjectProtocol {
  /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
  /// - parameter block: Closure executing a given task on the receiving function value.
  /// - returns: The modified value
  @discardableResult public func configure(_ block: (Self)->Void) -> Self {
    block(self)
    return self
  }
}

extension FormatStyle where Self == ByteCountFormatStyle {
  static var memory: ByteCountFormatStyle {
    .byteCount(style: .memory)
  }
}

extension String {
  static var targetIdentifier: Self {
    "io.dehesa.metal.commandline.gpgpu"
  }

  static func identify(_ suffix: Self) -> Self {
    precondition(suffix.allSatisfy { !$0.isWhitespace })
    var result: String = targetIdentifier
    if !suffix.hasPrefix(".") { result.append(".") }
    result.append(suffix)
    return result
  }
}
