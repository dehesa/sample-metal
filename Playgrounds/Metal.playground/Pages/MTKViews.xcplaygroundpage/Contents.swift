import PlaygroundSupport
import Cocoa
import MetalKit

let device = MTLCreateSystemDefaultDevice()!
let view = MTKView(frame: 400, device: device)
let queue = device.makeCommandQueue()!
let commands = queue.makeCommandBuffer()!
let encoder = commands.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
encoder.endEncoding()

let drawable = view.currentDrawable!
commands.present(drawable)
commands.commit()

PlaygroundPage.current.liveView = view
