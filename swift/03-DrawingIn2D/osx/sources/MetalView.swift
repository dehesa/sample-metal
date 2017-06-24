import Cocoa
import Metal
import simd

extension MetalView {
    private struct Vertex {
        var position: float4
        var color: float4
    }
}

class MetalView: NSView {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let vertexBuffer: MTLBuffer
    private let pipeline: MTLRenderPipelineState
    
    private var metalLayer : CAMetalLayer {
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
        
        // Setup buffer (non-transient)
        let vertices = [    // Coordinates defined in clip space: [-1,+1]
            Vertex(position: [ 0,    0.5, 0, 1], color: [1,0,0,1]),
            Vertex(position: [-0.5, -0.5, 0, 1], color: [0,1,0,1]),
            Vertex(position: [ 0.5, -0.5, 0, 1], color: [0,0,1,1])
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.size*vertices.count) else { return nil }
        self.vertexBuffer = vertexBuffer
        
        // Setup shader library
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc   = library.makeFunction(name: "main_vertex"),
              let fragmentFunc = library.makeFunction(name: "main_fragment") else { fatalError("Library or shaders not found") }
        
        // Setup pipeline (non-transient)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm   // 8-bit unsigned integer [0, 255]
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        self.pipeline = pipeline
        
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
        redraw()
    }
    
    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        self.metalLayer.drawableSize = convertToBacking(bounds).size
        redraw()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.metalLayer.drawableSize = convertToBacking(bounds).size
        redraw()
    }
    
    private func redraw() {
        // Setup Command Buffer (transient)
        guard let drawable = self.metalLayer.nextDrawable(),
              let commandBuffer = self.commandQueue.makeCommandBuffer() else { return }
        
        // Setup Command Encoders (transient)
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        
        // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
