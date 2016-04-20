import Cocoa
import Metal
import simd

class MetalView : NSView {
    
    // MARK: Definitions
    
    private struct Vertex {
        var position : float4
        var color : float4
    }
    
    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
    // MARK: Properties
    
    private var metalLayer : CAMetalLayer { return layer as! CAMetalLayer }
    private let device : MTLDevice = MTLCreateSystemDefaultDevice()!
    private let pipeline : MTLRenderPipelineState
    private let commandQueue : MTLCommandQueue
    private let vertexBuffer : MTLBuffer
    
    // MARK: Functionality
    
    required init?(coder aDecoder: NSCoder) {
        commandQueue = device.newCommandQueue()
        
        // Setup buffer (non-transient)
        let vertices = [    // Coordinates defined in clip space: [-1,+1]
            Vertex(position: [ 0,    0.5, 0, 1], color: [1,0,0,1]),
            Vertex(position: [-0.5, -0.5, 0, 1], color: [0,1,0,1]),
            Vertex(position: [ 0.5, -0.5, 0, 1], color: [0,0,1,1])
        ]
        vertexBuffer = device.newBufferWithBytes(vertices, length: sizeof(Vertex) * vertices.count, options: .CPUCacheModeDefaultCache)
        
        // Setup shader library
        guard let library = device.newDefaultLibrary() else { fatalError("No default library") }
        guard let vertexFunc : MTLFunction   = library.newFunctionWithName("main_vertex"),
              let fragmentFunc : MTLFunction = library.newFunctionWithName("main_fragment") else { fatalError("Shader not found") }
        
        // Setup pipeline (non-transient)
        pipeline = try! device.newRenderPipelineStateWithDescriptor({ () -> MTLRenderPipelineDescriptor in
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            descriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm   // 8-bit unsigned integer [0, 255]
            return descriptor
        }())
        
        super.init(coder: aDecoder)
        
        // Setup layer (backing layer)
        wantsLayer = true
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
		guard let window = self.window else { return }
		metalLayer.contentsScale = window.backingScaleFactor
        redraw()
    }
    
    override func setBoundsSize(newSize: NSSize) {
        super.setBoundsSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        redraw()
    }
    
    override func setFrameSize(newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = convertRectToBacking(bounds).size
        redraw()
    }
    
    private func redraw() {
        guard let drawable = metalLayer.nextDrawable() else { return }
        
        // Setup Command Buffers (transient)
        let cmdBuffer = commandQueue.commandBuffer()
        
        // Setup Command Encoders (transient)
        let encoder = cmdBuffer.renderCommandEncoderWithDescriptor({
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = drawable.texture
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
            descriptor.colorAttachments[0].loadAction = .Clear
            descriptor.colorAttachments[0].storeAction = .Store
            return descriptor
        }())
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        
        // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
        cmdBuffer.presentDrawable(drawable)
        cmdBuffer.commit()
    }
}
