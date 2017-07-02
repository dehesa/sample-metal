import UIKit
import Metal
import simd

protocol MetalViewDelegate {
    /// This method is called once per frame. Within the method, you may access any of the properties of the view, and request the current render pass descriptor to get a descriptor configured with renderable color and depth textures.
    func drawInView(metalView: MetalView)
}

final class MetalView: UIView {
    
    /// The layer used by this view (`CAMetalLayer`).
    override static func layerClass() -> AnyClass { return CAMetalLayer.self }
    
    // MARK: Properties
    
    /// The metal layer that backs this view.
    var metalLayer: CAMetalLayer { return layer as! CAMetalLayer }
    
    /// The delegate of this view, responsible for drawing.
    var delegate: MetalViewDelegate?
    
    /// Texture containing the depth data from the depth/stencil test.
    private var depthTexture: MTLTexture?
    
    /// The color to which the color attachment should be cleared at the start of a rendering pass.
    let clearColor: MTLClearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    
    /// The view's layer's current drawable. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var currentDrawable: CAMetalDrawable?
    
    /// A render pass descriptor configured to use the current drawable's texture as its primary color attachment and an internal depth texture of the same size as its depth attachment's texture.
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? {
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
    private var displayLink: CADisplayLink?
    
    /// The target frame rate (in Hz). For best results, this should be a number that evenly divides 60 (e.g., 60, 30, 15).
    private let preferredFramesPerSecond: UInt = 60
    
    /// The duration (in seconds) of the previous frame. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var frameDuration: NSTimeInterval = 1 / 60
    
    // MARK: Initializer
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm   // 8-bit unsigned integer [0, 255]
    }
    
    // MARK: Functionality
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        let idealFrameDuration: NSTimeInterval = 1 / 60
        let targetFrameDuration: NSTimeInterval = 1 / Double(preferredFramesPerSecond)
        let frameInterval = Int(round(targetFrameDuration / idealFrameDuration))
        
        if let _ = superview {
            if let dl = displayLink { dl.invalidate() }
            displayLink = CADisplayLink(target: self, selector: "displayLinkDidFire:")
            displayLink!.frameInterval = frameInterval
            displayLink!.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
        let scale = window?.screen.scale ?? UIScreen.mainScreen().scale
        let size = CGSizeApplyAffineTransform(bounds.size, CGAffineTransformMakeScale(scale, scale))
        
        // If there are no changes on the width and height of the depth texture, don't recreate it.
        let w = Int(size.width), h = Int(size.height)
        guard depthTexture == nil || depthTexture!.width != w || depthTexture!.height != h else { return }
        
        metalLayer.drawableSize = size
        depthTexture = metalLayer.device!.newTextureWithDescriptor(MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Depth32Float, width: w, height: h, mipmapped: false))
    }
    
    func displayLinkDidFire(displayLink: CADisplayLink) {
        currentDrawable = metalLayer.nextDrawable()
        frameDuration = displayLink.duration
        delegate?.drawInView(self)
    }
}
