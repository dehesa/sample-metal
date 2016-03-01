import Cocoa
import Metal
import simd

protocol MetalViewDelegate {
    /// This method is called once per frame. Within the method, you may access any of the properties of the view, and request the current render pass descriptor to get a descriptor configured with renderable color and depth textures.
    func drawInView(metalView: MetalView)
}

class MetalView: NSView {
    
    /// The layer used by this view (`CAMetalLayer`).
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    // MARK: Properties
    
    /// The metal layer that backs this view.
    var metalLayer : CAMetalLayer { return layer as! CAMetalLayer }
    
    /// The delegate of this view, responsible for drawing.
    var delegate : MetalViewDelegate?
    
    /// Texture containing the depth data from the depth/stencil test.
    private var depthTexture : MTLTexture?
    
    /// The color to which the color attachment should be cleared at the start of a rendering pass.
    let clearColor : MTLClearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    
    /// The view's layer's current drawable. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var currentDrawable : CAMetalDrawable?
    
    /// A render pass descriptor configured to use the current drawable's texture as its primary color attachment and an internal depth texture of the same size as its depth attachment's texture.
    var currentRenderPassDescriptor : MTLRenderPassDescriptor? {
        guard let drawable = currentDrawable, let depthTexture = self.depthTexture else { return nil }
        
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = drawable.texture
        desc.colorAttachments[0].clearColor = clearColor
        desc.colorAttachments[0].loadAction = .Clear
        desc.colorAttachments[0].storeAction = .Store
        desc.depthAttachment.texture = depthTexture
        desc.depthAttachment.clearDepth = 1
        desc.depthAttachment.loadAction = .Clear
        desc.depthAttachment.storeAction = .DontCare
        return desc
    }
    
    /// Timer sync with the screen refresh controlling when the drawing loop is fired.
    private var displayLink : CVDisplayLink?
    
    /// The target frame rate (in Hz). For best results, this should be a number that evenly divides 60 (e.g., 60, 30, 15).
    private let preferredFramesPerSecond : UInt = 60
    
    /// The duration (in seconds) of the previous frame. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var frameDuration : NSTimeInterval = 1 / 60
    
    // MARK: Initializer
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        // Setup layer (backing layer)
        self.wantsLayer = true
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm   // 8-bit unsigned integer [0, 255]
    }
    
    // MARK: Functionality
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        let idealFrameDuration  : NSTimeInterval = 1 / 60
        let targetFrameDuration : NSTimeInterval = 1 / Double(preferredFramesPerSecond)
        let frameInterval = Int(round(targetFrameDuration / idealFrameDuration))
        
        func displayLinkOutputCallback(displayLink: CVDisplayLink, _ inNow: UnsafePointer<CVTimeStamp>, _ inOutputTime: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutablePointer<Void>) -> CVReturn {
            unsafeBitCast(displayLinkContext, MetalView.self).displayLinkDidFire()
            return kCVReturnSuccess
        }
        
        if let window = self.window {
            self.metalLayer.contentsScale = window.backingScaleFactor
            if let dl = displayLink { CVDisplayLinkStop(dl) }
            guard CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink) == kCVReturnSuccess else { fatalError("Display Link could not be created") }
            CVDisplayLinkSetOutputCallback(self.displayLink!, displayLinkOutputCallback, UnsafeMutablePointer<Void>(unsafeAddressOf(self)))
            CVDisplayLinkStart(displayLink!)
        } else if let displayLink = self.displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
    }
    
    override func setBoundsSize(newSize: NSSize) {
        super.setBoundsSize(newSize)
        resize()
    }
    
    override func setFrameSize(newSize: NSSize) {
        super.setFrameSize(newSize)
        resize()
    }
    
    private func resize() {
        // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
        let size = convertRectToBacking(bounds).size
        
        // If there are no changes on the width and height of the depth texture, don't recreate it.
        let w = Int(size.width), h = Int(size.height)
        guard depthTexture == nil || depthTexture!.width != w || depthTexture!.height != h else { return }
        
        metalLayer.drawableSize = size
        depthTexture = metalLayer.device!.newTextureWithDescriptor({ () -> MTLTextureDescriptor in
            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Depth32Float, width: w, height: h, mipmapped: false)
            descriptor.storageMode = .Private
            return descriptor
        }())
    }
    
    func displayLinkDidFire() {
        currentDrawable = metalLayer.nextDrawable()
//        frameDuration = displayLink.duration
        delegate?.drawInView(self)
    }
}
