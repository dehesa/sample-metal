import Metal

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
