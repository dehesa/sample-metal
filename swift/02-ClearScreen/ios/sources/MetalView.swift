import UIKit
import Metal
import simd

final class MetalView: UIView {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    override static var layerClass: AnyClass {
		return CAMetalLayer.self
	}
    
    required init?(coder aDecoder: NSCoder) {
        // Setup the Device & Command Queue (non-transient objects: expensive to create)
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else { return nil }
        (self.device, self.commandQueue) = (device, commandQueue)
		
        super.init(coder: aDecoder)
        
        // Setup Core Animation related functionality
        self.metalLayer.device = device
        self.metalLayer.pixelFormat = .bgra8Unorm
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        guard let window = self.window else { return }
        self.metalLayer.contentsScale = window.screen.nativeScale
        redraw()
    }
    
    private func redraw() {
        // Setup Command Buffer (transient)
        guard let drawable = self.metalLayer.nextDrawable(),
              let commandBuffer = self.commandQueue.makeCommandBuffer() else { return }
        
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        
        // Setup Command Encoder (transient)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.endEncoding()
        
        // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
