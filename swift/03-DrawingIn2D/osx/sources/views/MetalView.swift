import Cocoa
import Metal
import simd

class MetalView: NSView {
    
    // MARK: Definitions
    
    private struct Vertex {
        var position : float4
        var color : float4
    }
    
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    // MARK: Properties
    
    private var metalLayer : CAMetalLayer { return self.layer as! CAMetalLayer }
    private let metalDevice : MTLDevice = { guard let device = MTLCreateSystemDefaultDevice() else { fatalError() }; return device }()
    
    private var metalPipeline : MTLRenderPipelineState!
    private var metalQueue : MTLCommandQueue!
    private var metalVertexBuffer : MTLBuffer!
    //private var displayLink : CVDisplayLink?
    
    // MARK: Functionality
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    private func setup() {
        // Setup layer (backing layer)
        self.wantsLayer = true
        
        // Setup device
        self.metalLayer.device = metalDevice
        self.metalLayer.pixelFormat = .BGRA8Unorm   // 8-bit unsigned integer [0, 255]
        
        // Setup buffer
        let vertices = [    // Coordinates defined in clip space coords: [-1,+1]
            Vertex(position: [ 0,    0.5, 0, 1], color: [1,0,0,1]),
            Vertex(position: [-0.5, -0.5, 0, 1], color: [0,1,0,1]),
            Vertex(position: [ 0.5, -0.5, 0, 1], color: [0,0,1,1])
        ]
        self.metalVertexBuffer = metalDevice.newBufferWithBytes(vertices, length: sizeof(Vertex) * vertices.count, options: [.CPUCacheModeDefaultCache])
        
        // Setup pipeline
        guard let library = self.metalDevice.newDefaultLibrary() else { fatalError("No default library") }
        guard let vertexFunc: MTLFunction = library.newFunctionWithName("vertex_main"),
            let fragmentFunc: MTLFunction = library.newFunctionWithName("fragment_main") else { fatalError("Shader not found") }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat
        metalPipeline = try! self.metalDevice.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
        
        metalQueue = self.metalDevice.newCommandQueue()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let window = self.window {
            self.metalLayer.contentsScale = window.backingScaleFactor
        } else {
            // Nothing for now
        }
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
        let framebufferTexture = drawable.texture
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = framebufferTexture
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        renderPass.colorAttachments[0].loadAction = .Clear
        renderPass.colorAttachments[0].storeAction = .Store
        
        let cmdBuffer = metalQueue.commandBuffer()
        let encoder = cmdBuffer.renderCommandEncoderWithDescriptor(renderPass)
        encoder.setRenderPipelineState(self.metalPipeline)
        encoder.setVertexBuffer(metalVertexBuffer, offset: 0, atIndex: 0)
        encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        
        cmdBuffer.presentDrawable(drawable)
        cmdBuffer.commit()
    }
}
