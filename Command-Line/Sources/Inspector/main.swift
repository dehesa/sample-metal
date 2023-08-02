import CoreGraphics
import Metal

var result = String()

for device in MTLCopyAllDevices() {
  result.append("\n\(device.name)")

  // GPU location
  result.append("\n\t\(device.location) GPU")
  let properties = [(device.isLowPower, "low power"), (device.isHeadless, "headless"), (device.isRemovable, "removable")]
    .filter(\.0).map(\.1).joined(separator: ", ")
  if !properties.isEmpty {
    result.append(" (\(properties))")
  }

  // GPU memory
  if device.hasUnifiedMemory {
    result.append("\n\tUnified memory (shared with CPU)")
  } else {
    result.append("\n\tDiscrete memory")
  }

  result.append("\n\t\tmax recommended working set: \(device.recommendedMaxWorkingSetSize.formatted(.memory))")
  if device.maxTransferRate > 0 {
    result.append("\n\t\tmax transfer rate: \(device.maxTransferRate.formatted(.memory))/s")
  }

  // Feature set support
  result.append("\n\tFeature set support")

  let families = [MTLGPUFamily.apple1, .apple2, .apple3, .apple4, .apple5, .apple6, .apple7, .apple8, .metal3]
    .filter(device.supportsFamily(_:))
    .map(\.debugDescription)
    .joined(separator: ", ")
  result.append("\n\t\tfamily: \(families)")

  // Computing
  result.append("\n\tGeneral Purpose Computing")
  result.append("\n\t\tmax threadgroup memory: \(device.maxThreadgroupMemoryLength.formatted(.memory))")
  let t = device.maxThreadsPerThreadgroup
  result.append("\n\t\tmax threads per threadgroup: [\(t.width), \(t.height), \(t.depth)]")

  let computeDescriptor = MTLComputePipelineDescriptor().set {
    $0.label = .identify("compute.pipeline")
    $0.computeFunction = device.makeDefaultLibrary()!.makeFunction(name: "empty")!
  }

  let pipeline = try! device.makeComputePipelineState(descriptor: computeDescriptor, options: [], reflection: .none)
  result.append("\n\t\tthreads execution width: \(pipeline.threadExecutionWidth)")

  result.append("\n")
}

print(result)
