#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if os(macOS)
public final class FrameTimer {
  private let displayLink: CVDisplayLink
  fileprivate let handler: Callback

  @MainActor public init?(window: NSWindow? = .none, nonisolated handler: @escaping Callback) {
    var displayLink: CVDisplayLink?
    var result = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)

    guard result == kCVReturnSuccess, let displayLink else { return nil }
    self.displayLink = displayLink
    self.handler = handler

    let context = Unmanaged<FrameTimer>.passUnretained(self).toOpaque()
    result = CVDisplayLinkSetOutputCallback(displayLink, _displayEvent(_:_:_:_:_:_:), context)
    guard result == kCVReturnSuccess else { return nil }

    result = CVDisplayLinkStart(displayLink)
    guard result == kCVReturnSuccess else { return nil }
  }

  deinit {
    CVDisplayLinkStop(self.displayLink)
  }

  /// - parameter now: The current time for now.
  /// - parameter output: The expected output/display for the frame being produced.
  public typealias Callback = (_ now: Double, _ output: Double) -> Void
}

/// Function called everytime the targeted display refreshes.
/// - parameter displayLink: The instance for which the output callback is being invoked.
/// - parameter inNow: The timestamp with the current display time. This represents the time when the frame will be displayed to the user.
/// - parameter inOutputTime: The expected output/display time for the frame being produced.
/// - parameter flagsIn: It provides context information for the current callback invocation.
/// - parameter flagsOut: Let you request more callbacks or disable temporal processing.
/// - parameter displayLinkContext: An untyped pointer to user data.
/// - returns Indicates the result of the callback. It can be communicated upstream (usually for loggers).
private func _displayEvent(_ displayLink: CVDisplayLink, _ inNow: UnsafePointer<CVTimeStamp>, _ inOutputTime: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
  guard let displayLinkContext else { return kCVReturnInvalidArgument }
  let ticker = Unmanaged<FrameTimer>.fromOpaque(displayLinkContext).takeUnretainedValue()
  let now = Double(inNow.pointee.videoTime) / Double(inNow.pointee.videoTimeScale)
  let out = Double(inOutputTime.pointee.videoTime) / Double(inOutputTime.pointee.videoTimeScale)
  ticker.handler(now, out)
  return kCVReturnSuccess
}

#elseif canImport(UIKit)

public final class FrameTimer {
  fileprivate var displayLink: CADisplayLink!
  fileprivate let handler: Callback

  @MainActor public init?(window: UIWindow? = .none, handler: @escaping Callback) {
    self.handler = handler
    self.displayLink = CADisplayLink(target: Wrapper(self), selector: #selector(Wrapper.update))
    self.displayLink.add(to: .current, forMode: .default)
  }

  deinit {
    displayLink?.invalidate()
  }

  /// - parameter now: The current time for now (relative to the time when the device last booted up).
  /// - parameter output: The expected output/display for the frame being produced.
  public typealias Callback = (_ now: Double, _ output: Double) -> Void
}

fileprivate final class Wrapper: NSObject {
  weak var timer: FrameTimer?

  init(_ timer: FrameTimer) {
    self.timer = timer
  }

  @objc func update(sender displayLink: CADisplayLink) {
    guard let timer else { return }
    let now: Double = displayLink.timestamp
    let out: Double = displayLink.targetTimestamp
    timer.handler(now, out)
  }
}
#endif
