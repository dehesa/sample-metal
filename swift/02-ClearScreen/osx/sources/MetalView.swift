import Cocoa
import Metal
import simd

class MetalView: NSView {
    
    // MARK: Definitions
    
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    // MARK: Properties
    
    private var metalLayer : CAMetalLayer { return self.layer as! CAMetalLayer }
    private let device : MTLDevice
    private var commandQueue : MTLCommandQueue
    
    // MARK: Functionality
    
    required init?(coder aDecoder: NSCoder) {
        // Setup device
        device = MTLCreateSystemDefaultDevice()!
        
        // Setup Command Queue (non-transient object: expensive to create. Do save it)
        commandQueue = device.newCommandQueue()
        
        super.init(coder: aDecoder)
        
        // Setup layer (backing layer)
        self.wantsLayer = true
        self.metalLayer.device = device
        self.metalLayer.pixelFormat = .BGRA8Unorm
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        guard let window = self.window else { return }
        self.metalLayer.contentsScale = window.backingScaleFactor
        self.redraw()
    }
    
    override func setBoundsSize(newSize: NSSize) {
        super.setBoundsSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        self.redraw()
    }
    
    override func setFrameSize(newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        self.redraw()
    }
    
    private func redraw() {
        guard let drawable = self.metalLayer.nextDrawable() else { return }
        
        // Setup Command Buffers (transient)
        let cmdBuffer = self.commandQueue.commandBuffer()
        
        // Setup Command Encoders (transient)
        let encoder = cmdBuffer.renderCommandEncoderWithDescriptor({
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = drawable.texture
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
            descriptor.colorAttachments[0].loadAction = .Clear
            descriptor.colorAttachments[0].storeAction = .Store
            return descriptor
        }())
        encoder.endEncoding()
        
        // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
        cmdBuffer.presentDrawable(drawable)
        cmdBuffer.commit()
    }
}
