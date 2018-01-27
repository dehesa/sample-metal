import Cocoa
import Metal

for device in MTLCopyAllDevices() {
    print("\n\(device.name)")
    print("\tlow power, headless, removable: \(device.isLowPower), \(device.isHeadless), \(device.isRemovable)")
    
    let computeDescriptor = MTLComputePipelineDescriptor().set {
        $0.label = "me.dehesa.metal.commandline.gpgpu.detector.compute.pipeline"
        $0.computeFunction = device.makeDefaultLibrary()!.makeFunction(name: "grayscale")!
        $0.buffers[0].mutability = .immutable
        $0.buffers[1].mutability = .mutable
    }
    
    let pipeline = try! device.makeComputePipelineState(descriptor: computeDescriptor, options: [], reflection: nil)
    print("\tthreads execution width: \(pipeline.threadExecutionWidth)")
    
    let t = device.maxThreadsPerThreadgroup
    print("\tmax threads per threadgroup: [\(t.width), \(t.height), \(t.depth)]")
    print("\tmax threadgroup memory length: \(device.maxThreadgroupMemoryLength / 1_000) KB")
    print("\tmax working set: \(device.recommendedMaxWorkingSetSize / 1_000_000) MB (recommended)")
}

print("\n")
