import PlaygroundSupport
import Foundation

/// Reference to the playground page to be able to run a live view.
let page: PlaygroundPage = .current
/// Date formatter for printing in console purposes.
let dateStyle: Date.FormatStyle = .dateTime.minute(.twoDigits).second(.twoDigits)
/// Number formatter for human-readable amount of seconds.
let numberStyle: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(1...4))
//: ---
import Metal

/// The GPU computing what is being showned in the live view.
let device = MTLCreateSystemDefaultDevice()!
/// The serial queue managing the work being feed to the GPU.
let queue = device.makeCommandQueue()!
/// A custom view executing the closure for each display refresh.
page.liveView = MetalView(device: device, queue: queue) { layer, now, output in
  print("\(Date().formatted(dateStyle)) Next frame in \((output - now).formatted(numberStyle)) seconds")

  guard let drawable = layer.nextDrawable(),
        let commandBuffer = queue.makeCommandBuffer() else { return }
  // Setup the render pass descriptor.
  let renderPass = MTLRenderPassDescriptor().configure {
    $0.colorAttachments[0].configure {
      $0.texture = drawable.texture
      $0.clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
      $0.loadAction = .clear
      $0.storeAction = .store
    }
  }

  // Setup Command Encoder (transient)
  guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
  encoder.endEncoding()

  // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
  commandBuffer.present(drawable)
  commandBuffer.commit()
}.configure {
  $0.frame = [400, 600]
}
