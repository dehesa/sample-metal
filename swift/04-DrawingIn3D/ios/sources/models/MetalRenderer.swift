import Metal
import simd

class MetalRenderer : MetalViewDelegate {
    
    // MARK: Definitions
    
    private struct Vertex {
        var position : float4
        var color : float4
    }
    
    private struct Uniforms {
        var modelViewProjectionMatrix : float4x4
    }
    
    private static let inFlightBufferCount : Int = 3
    
    // MARK: Properties
    
    private let device : MTLDevice = MTLCreateSystemDefaultDevice()!
    private var commandQueue : MTLCommandQueue
    private let vertexBuffer : MTLBuffer
    private let indecesBuffer : MTLBuffer
    private let uniformBuffer : MTLBuffer
    private let renderPipelineState : MTLRenderPipelineState
    private let depthStencilState : MTLDepthStencilState
    private let displaySemaphore : dispatch_semaphore_t = dispatch_semaphore_create(MetalRenderer.inFlightBufferCount)
    
    // MARK: Functionality
    
    init() {
        commandQueue = device.newCommandQueue()
        
        // Setup pipeline
        guard let library = device.newDefaultLibrary() else { fatalError("No default library") }
        guard let vertexFunc: MTLFunction = library.newFunctionWithName("vertex_main"),
            let fragmentFunc: MTLFunction = library.newFunctionWithName("fragment_main") else { fatalError("Shader not found") }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm

        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .Less
        depthStencilDescriptor.depthWriteEnabled = true
        
        depthStencilState = device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        renderPipelineState = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
        commandQueue = device.newCommandQueue()
        
        // Setup buffers
        let vertices = [    // Coordinates defined in clip space coords: [-1,+1]
            Vertex(position: [-1,  1,  1,  1], color: [0,1,1,1]),
            Vertex(position: [-1, -1,  1,  1], color: [0,0,1,1]),
            Vertex(position: [ 1, -1,  1,  1], color: [1,0,1,1]),
            Vertex(position: [ 1,  1,  1,  1], color: [1,1,1,1]),
            Vertex(position: [-1,  1, -1,  1], color: [0,1,0,1]),
            Vertex(position: [-1, -1, -1,  1], color: [0,0,0,1]),
            Vertex(position: [ 1, -1, -1,  1], color: [1,0,0,1]),
            Vertex(position: [ 1,  1, -1,  1], color: [1,1,0,1])
        ]
        vertexBuffer = device.newBufferWithBytes(vertices, length: sizeof(Vertex) * vertices.count, options: .CPUCacheModeDefaultCache)
        vertexBuffer.label = "Vertices"
        
        let indices : [UInt16] = [
            3, 2, 6, 6, 7, 3,
            4, 5, 1, 1, 0, 4,
            4, 0, 3, 3, 7, 4,
            1, 5, 6, 6, 2, 1,
            0, 1, 2, 2, 3, 0,
            7, 6, 5, 5, 4, 7
        ]
        indecesBuffer = device.newBufferWithBytes(indices, length: sizeof(UInt16) * indices.count, options: .CPUCacheModeDefaultCache)
        indecesBuffer.label = "Indices"
        
        uniformBuffer = device.newBufferWithLength(sizeof(Uniforms)*MetalRenderer.inFlightBufferCount, options: .CPUCacheModeDefaultCache)
    }
    
    func drawInView(metalView: MetalView) {
        dispatch_semaphore_wait(self.displaySemaphore, DISPATCH_TIME_FOREVER)
        metalView.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        self.updateUniforms(forView: metalView, duration: metalView.frameDuration)
        
        let commandBuffer = self.commandQueue.commandBuffer()
        
        let passDescriptor = metalView.currentRenderPassDescriptor!
        let renderPass = commandBuffer.renderCommandEncoderWithDescriptor(passDescriptor)
        renderPass.setRenderPipelineState(self.renderPipelineState)
        renderPass.setDepthStencilState(self.depthStencilState)
        renderPass.setFrontFacingWinding(.CounterClockwise)
        renderPass.setCullMode(.Back)
        
        // ...
    }
    
    private func updateUniforms(forView metalView: MetalView, duration: NSTimeInterval) {
        
    }
    
    

    
//    private func redraw() {
//        guard let drawable = self.metalLayer.nextDrawable() else { return }
//        let framebufferTexture = drawable.texture
//        
//        let renderPass = MTLRenderPassDescriptor()
//        renderPass.colorAttachments[0].texture = framebufferTexture
//        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
//        renderPass.colorAttachments[0].loadAction = .Clear
//        renderPass.colorAttachments[0].storeAction = .Store
//        
//        let cmdBuffer = metalQueue.commandBuffer()
//        let encoder = cmdBuffer.renderCommandEncoderWithDescriptor(renderPass)
//        encoder.setRenderPipelineState(self.metalPipeline)
//        encoder.setVertexBuffer(metalVertexBuffer, offset: 0, atIndex: 0)
//        encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 8)
//        encoder.endEncoding()
//        
//        cmdBuffer.presentDrawable(drawable)
//        cmdBuffer.commit()
//    }
}
