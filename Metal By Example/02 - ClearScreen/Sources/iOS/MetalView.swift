import UIKit
import Metal

/// `UIView` handling the first basic metal commands.
final class MetalView: UIView {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    
    init(frame: CGRect, device: MTLDevice, queue: MTLCommandQueue) {
        // Setup the Device & Command Queue (non-transient objects: expensive to create)
        (self.device, self.queue) = (device, queue)
        super.init(frame: frame)
        
        // Setup Core Animation related functionality
        self.metalLayer.setUp { (layer) in
            layer.device = device
            layer.pixelFormat = .bgra8Unorm
            layer.framebufferOnly = true
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    private var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    override static var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        guard let window = self.window else { return }
        self.metalLayer.contentsScale = window.screen.nativeScale
        redraw()
    }
}

extension MetalView {
    private func redraw() {
        // Setup Command Buffer (transient)
        guard let drawable = self.metalLayer.nextDrawable(),
              let commandBuffer = self.queue.makeCommandBuffer() else { return }
        
        // Setup the render pass descriptor.
        let renderPass = MTLRenderPassDescriptor().set {
            $0.colorAttachments[0].setUp { (attachment) in
                attachment.texture = drawable.texture
                attachment.clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
                attachment.loadAction = .clear
                attachment.storeAction = .store
            }
        }
        
        // Setup Command Encoder (transient)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
        encoder.endEncoding()
        
        // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
