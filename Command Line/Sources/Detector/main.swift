import Cocoa
import Metal

let devices = MTLCopyAllDevices()

for device in devices {
    print("\n\(device.name)")
    print("\tlow power: \(device.isLowPower)")
    print("\theadless: \(device.isHeadless)")
    print("\tremovable: \(device.isRemovable)")
    let t = device.maxThreadsPerThreadgroup
    print("\tmax threads per threadgroup: [\(t.width), \(t.height), \(t.depth)]")
    print("\tmax threadgroup memory length: \(device.maxThreadgroupMemoryLength)")
}

print("\n")
