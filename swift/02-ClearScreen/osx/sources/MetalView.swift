import Cocoa
import Metal
import simd

class MetalView: NSView {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        // Setup the Device and Command Queue (non-transient objects: expensive to create. Do save it)
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else { return nil }
        (self.device, self.commandQueue) = (device, commandQueue)
        
        super.init(coder: aDecoder)
        
        // Setup layer (backing layer)
        self.wantsLayer = true
        self.metalLayer.device = device
        self.metalLayer.pixelFormat = .bgra8Unorm
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        guard let window = self.window else { return }
        self.metalLayer.contentsScale = window.backingScaleFactor
        self.redraw()
    }
    
    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        self.metalLayer.drawableSize = self.convertToBacking(bounds).size
        self.redraw()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.metalLayer.drawableSize = convertToBacking(bounds).size
        self.redraw()
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
