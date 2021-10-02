import Cocoa
import Metal

var result = String()

for device in MTLCopyAllDevices() {
  result.append("\n\(device.name)")

  // GPU location
  result.append("\n\t\(device.location) GPU")
  var properties: [String] = []
  if (device.isLowPower) { properties.append("low power") }
  if (device.isHeadless) { properties.append("headless") }
  if (device.isRemovable) { properties.append("removable") }
  if !properties.isEmpty {
    result.append(" (" + properties.joined(separator: ", ") + ")")
  }

  // GPU memory
  if device.hasUnifiedMemory {
    result.append("\n\tUnified memory (shared with CPU)")
  } else {
    result.append("\n\tDiscrete memory")
  }

  result.append("\n\t\tmax recommended working set: \(bytes: device.recommendedMaxWorkingSetSize)")
  if device.maxTransferRate > 0 {
    result.append("\n\t\tmax transfer rate: \(bytes: device.maxTransferRate)/s")
  }

  // Feature set support
  result.append("\n\tFeature set support")

  var families: [String] = []
  if device.supportsFamily(.common1) { families.append("common 1") }
  if device.supportsFamily(.common2) { families.append("common 2") }
  if device.supportsFamily(.common3) { families.append("common 3") }
  if device.supportsFamily(.mac1) { families.append("mac 1") }
  if device.supportsFamily(.mac2) { families.append("mac 2") }
  result.append("\n\t\tfamily: \(families.joined(separator: ", "))")

  var sets: [String] = []
  if device.supportsFeatureSet(.macOS_GPUFamily1_v1) { sets.append("1v1") }
  if device.supportsFeatureSet(.macOS_GPUFamily1_v2) { sets.append("1v2") }
  if device.supportsFeatureSet(.macOS_GPUFamily1_v3) { sets.append("1v3") }
  if device.supportsFeatureSet(.macOS_GPUFamily1_v4) { sets.append("1v4") }
  if device.supportsFeatureSet(.macOS_GPUFamily2_v1) { sets.append("2v1") }
  result.append("\n\t\tsets: \(sets.joined(separator: ", "))")

  // Computing
  result.append("\n\tGeneral Purpose Computing")
  result.append("\n\t\tmax threadgroup memory: \(bytes: .init(device.maxThreadgroupMemoryLength))")
  let t = device.maxThreadsPerThreadgroup
  result.append("\n\t\tmax threads per threadgroup: [\(t.width), \(t.height), \(t.depth)]")

  let computeDescriptor = MTLComputePipelineDescriptor().set {
    $0.label = "io.dehesa.metal.commandline.gpgpu.detector.compute.pipeline"
    $0.computeFunction = device.makeDefaultLibrary()!.makeFunction(name: "empty")!
  }

  let pipeline = try! device.makeComputePipelineState(descriptor: computeDescriptor, options: [], reflection: nil)
  result.append("\n\t\tthreads execution width: \(pipeline.threadExecutionWidth)")

  result.append("\n")
}

print(result)
