import UIKit
import Metal
import simd

protocol MetalViewDelegate {
    func drawInView(metalView: MetalView)
}

final class MetalView : UIView {
    
    // MARK: Definitions
    
    /// The delegate of this view, responsible for drawing.
    var delegate : MetalViewDelegate?
    
    /// The layer used by this view (`CAMetalLayer`).
    override static func layerClass() -> AnyClass { return CAMetalLayer.self }
    
    // MARK: Properties
    
    /// The metal layer that backs this view.
    var metalLayer : CAMetalLayer { return self.layer as! CAMetalLayer }
    
    /// The view's layer's current drawable. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var currentDrawable : CAMetalDrawable?
    
    /// A render pass descriptor configured to use the current drawable's texture as its primary color attachment and an internal depth texture of the same size as its depth attachment's texture.
    var currentRenderPassDescriptor : MTLRenderPassDescriptor? {
        guard let drawable = self.currentDrawable else { return nil }
        
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].clearColor = self.clearColor
        passDescriptor.colorAttachments[0].loadAction = .Clear
        passDescriptor.colorAttachments[0].storeAction = .Store
        
        passDescriptor.depthAttachment.texture = self.depthTexture
        passDescriptor.depthAttachment.clearDepth = 1
        passDescriptor.depthAttachment.loadAction = .Clear
        passDescriptor.depthAttachment.storeAction = .DontCare
        return passDescriptor
    }
    
    /// The desired pixel format of the color attachment.
    private var colorPixelFormat : MTLPixelFormat {
        get { return self.metalLayer.pixelFormat }
        set { self.metalLayer.pixelFormat = newValue }
    }
    
    private var depthTexture : MTLTexture?
    
    /// The color to which the color attachment should be cleared at the start of a rendering pass.
    var clearColor : MTLClearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
    
    /// The target frame rate (in Hz). For best results, this should be a number that evenly divides 60 (e.g., 60, 30, 15).
    private var preferredFramesPerSecond : UInt = 60
    
    /// The duration (in seconds) of the previous frame. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var frameDuration : NSTimeInterval = 1.0 / 60.0
    
    private var displayLink : CADisplayLink?
    
    override var frame : CGRect {
        didSet {
            // During the first layout pass, we will not be in a view hierarchy, so we guess our scale.
            // If we've moved to a window by the time our frame is being set, we can take its scale as our own
            let scale = self.window?.screen.scale ?? UIScreen.mainScreen().scale
            
            // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels
            var drawableSize = self.bounds.size
            drawableSize.width *= scale
            drawableSize.height *= scale
            self.metalLayer.drawableSize = drawableSize
            
            self.makeDepthTexture()
        }
    }
    
    
    // MARK: Functionality
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.metalLayer.pixelFormat = .BGRA8Unorm   // 8-bit unsigned integer [0, 255]
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        let idealFrameDuration  : NSTimeInterval = 1.0 / 60.0
        let targetFrameDuration : NSTimeInterval = 1.0 / Double(self.preferredFramesPerSecond)
        let frameInterval = Int(round(targetFrameDuration / idealFrameDuration))
        
        if let _ = self.superview {
            if let dl = self.displayLink { dl.invalidate() }
            self.displayLink = CADisplayLink(target: self, selector: "displayLinkDidFire:")
            self.displayLink!.frameInterval = frameInterval
            self.displayLink!.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        } else {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }
    
    func displayLinkDidFire(displayLink: CADisplayLink) {
        self.frameDuration = displayLink.duration
        self.currentDrawable = self.metalLayer.nextDrawable()
        
        guard let _ = self.currentDrawable else { return }
        delegate?.drawInView(self)
    }
    
    private func makeDepthTexture() {
        let drawableSize = self.metalLayer.drawableSize
        let width = Int(drawableSize.width), height = Int(drawableSize.height)
        if let texture = self.depthTexture where texture.width == width && texture.height == height { return }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Depth32Float, width: width, height: height, mipmapped: false)
        self.depthTexture = self.metalLayer.device?.newTextureWithDescriptor(textureDescriptor)
    }
}
