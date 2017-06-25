import Cocoa
import Metal
import simd

protocol MetalViewDelegate {
    /// This method is called once per frame. Within the method, you may access any of the properties of the view, and request the current render pass descriptor to get a descriptor configured with renderable color and depth textures.
    func drawInView(_ metalView: MetalView)
}

class MetalView: NSView {
    /// Texture containing the depth data from the depth/stencil test.
    private var depthTexture: MTLTexture?
    /// Timer sync with the screen refresh controlling when the drawing loop is fired.
    private var displayLink: CVDisplayLink?
    /// The target frame rate (in Hz). For best results, this should be a number that evenly divides 60 (e.g., 60, 30, 15).
    private let preferredFramesPerSecond: UInt = 60
    /// Helper for the CVDisplayLink instance
    private var previousTimeStamp: UInt64 = CVGetCurrentHostTime()
    /// The duration (in seconds) of the previous frame. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var frameDuration: TimeInterval = 1 / 60
    /// The color to which the color attachment should be cleared at the start of a rendering pass.
    let clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    /// The view's layer's current drawable. This is valid only in the context of a callback to the delegate's `drawInView:` method.
    var currentDrawable: CAMetalDrawable?
    /// The delegate of this view, responsible for drawing.
    var delegate: MetalViewDelegate?
    /// The metal layer that backs this view.
    var metalLayer: CAMetalLayer {
        return self.layer as! CAMetalLayer
    }
    /// The device executing the tasks for the layer.
    var device: MTLDevice {
        return self.metalLayer.device!
    }
    /// A render pass descriptor configured to use the current drawable's texture as its primary color attachment and an internal depth texture of the same size as its depth attachment's texture.
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? {
        guard let drawable = self.currentDrawable,
              let depthTexture = self.depthTexture else { return nil }
        
        return MTLRenderPassDescriptor().set { (renderPass) in
            renderPass.colorAttachments[0].setUp { (attachment) in
                attachment.texture = drawable.texture
                attachment.clearColor = clearColor
                attachment.loadAction = .clear
                attachment.storeAction = .store
            }
            renderPass.depthAttachment.setUp { (attachment) in
                attachment.texture = depthTexture
                attachment.clearDepth = 1
                attachment.loadAction = .clear
                attachment.storeAction = .dontCare
            }
        }
    }
    
    /// The layer used by this view (`CAMetalLayer`).
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        super.init(coder: aDecoder)
        
        // Setup layer (backing layer)
        self.layer = CAMetalLayer().set {
            $0.device = device
            $0.pixelFormat = .bgra8Unorm   // 8-bit unsigned integer [0, 255]
        }
        wantsLayer = true
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        func displayLinkOutputCallback(_ displayLink: CVDisplayLink, _ inNow: UnsafePointer<CVTimeStamp>, _ inOutputTime: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
            guard let context = displayLinkContext else { return kCVReturnInvalidArgument }
            let view = unsafeBitCast(context, to: MetalView.self)
			
            let futureTimeStamp = inOutputTime.pointee.hostTime
			view.frameDuration = TimeInterval(futureTimeStamp-view.previousTimeStamp) / TimeInterval(NSEC_PER_SEC)
			view.previousTimeStamp = futureTimeStamp
            
            DispatchQueue.main.async {
                view.displayLinkDidFire()
            }
            return kCVReturnSuccess
        }
        
		guard let window = self.window else {
			if let displayLink = self.displayLink {
				CVDisplayLinkStop(displayLink)
				self.displayLink = nil
			}
			return
		}
		
		self.metalLayer.contentsScale = window.backingScaleFactor
		if let dl = self.displayLink {
            CVDisplayLinkStop(dl)
        }
		guard CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink) == kCVReturnSuccess else {
            fatalError("Display Link could not be created")
        }
        
        CVDisplayLinkSetOutputCallback(displayLink!, displayLinkOutputCallback, Unmanaged.passUnretained(self).toOpaque())
		
		previousTimeStamp = CVGetCurrentHostTime()
		CVDisplayLinkStart(displayLink!)
    }
    
    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        resize()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        resize()
    }
    
    private func resize() {
        // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
        let size = convertToBacking(bounds).size
        
        // If there are no changes on the width and height of the depth texture, don't recreate it.
        let w = Int(size.width), h = Int(size.height)
        guard self.depthTexture == nil || self.depthTexture!.width != w || self.depthTexture!.height != h else { return }
        
        self.metalLayer.drawableSize = size
        self.depthTexture = self.device.makeTexture(descriptor: MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: w, height: h, mipmapped: false).set {
            $0.storageMode = .private
            $0.usage = .renderTarget
        })
    }
    
    func displayLinkDidFire() {
		autoreleasepool {
			self.currentDrawable = self.metalLayer.nextDrawable()
			self.delegate?.drawInView(self)
		}
    }
}
