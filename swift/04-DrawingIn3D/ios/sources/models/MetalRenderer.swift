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
    private let pipelineState : MTLRenderPipelineState
    private let depthStencilState : MTLDepthStencilState
    private var commandQueue : MTLCommandQueue
    private let verticesBuffer : MTLBuffer
    private let indecesBuffer : MTLBuffer
    private let uniformsBuffer : MTLBuffer
    
    private let displaySemaphore : dispatch_semaphore_t = dispatch_semaphore_create(MetalRenderer.inFlightBufferCount)
    private var (time, rotationX, rotationY) : (Float, Float, Float) = (0,0,0)
    private var bufferIndex : Int = 0
    
    // MARK: Initializer
    
    init() {
        commandQueue = device.newCommandQueue()
        
        guard let library = device.newDefaultLibrary() else { fatalError("No default library") }
        guard let vertexFunc: MTLFunction = library.newFunctionWithName("vertex_main"),
              let fragmentFunc: MTLFunction = library.newFunctionWithName("fragment_main") else { fatalError("Shader not found") }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .Depth32Float
        pipelineState = try! device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)

        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .Less
        depthStencilDescriptor.depthWriteEnabled = true
        depthStencilState = device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        
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
        verticesBuffer = device.newBufferWithBytes(vertices, length: sizeof(Vertex) * vertices.count, options: .CPUCacheModeDefaultCache)
        verticesBuffer.label = "Vertices"
        
        let indices : [UInt16] = [ 3, 2, 6, 6, 7, 3,
            4, 5, 1, 1, 0, 4,
            4, 0, 3, 3, 7, 4,
            1, 5, 6, 6, 2, 1,
            0, 1, 2, 2, 3, 0,
            7, 6, 5, 5, 4, 7 ]
        indecesBuffer = device.newBufferWithBytes(indices, length: sizeof(UInt16) * indices.count, options: .CPUCacheModeDefaultCache)
        indecesBuffer.label = "Indices"
        
        uniformsBuffer = device.newBufferWithLength(sizeof(Uniforms)*MetalRenderer.inFlightBufferCount, options: .CPUCacheModeDefaultCache)
        uniformsBuffer.label = "Uniforms"
    }
    
    // MARK: Functionality
    
    func drawInView(metalView: MetalView) {
        dispatch_semaphore_wait(self.displaySemaphore, DISPATCH_TIME_FOREVER)
        guard let drawable = metalView.currentDrawable else { dispatch_semaphore_signal(self.displaySemaphore); return }
        
        metalView.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        
        let drawableSize = metalView.metalLayer.drawableSize
        self.updateUniforms(withDrawableSize: float2(Float(drawableSize.width), Float(drawableSize.height)), duration: metalView.frameDuration)
        
        let commandBuffer = self.commandQueue.commandBuffer()
        
        let passDescriptor = metalView.currentRenderPassDescriptor!
        let renderPass = commandBuffer.renderCommandEncoderWithDescriptor(passDescriptor)
        renderPass.setRenderPipelineState(self.pipelineState)
        renderPass.setDepthStencilState(self.depthStencilState)
        renderPass.setFrontFacingWinding(.CounterClockwise)
        renderPass.setCullMode(.Back)
        
        let uniformBufferOffset = sizeof(Uniforms) * self.bufferIndex
        renderPass.setVertexBuffer(self.verticesBuffer, offset: 0, atIndex: 0)
        renderPass.setVertexBuffer(self.uniformsBuffer, offset: uniformBufferOffset, atIndex: 1)
        renderPass.drawIndexedPrimitives(.Triangle, indexCount: self.indecesBuffer.length / sizeof(UInt16), indexType: .UInt16, indexBuffer: self.indecesBuffer, indexBufferOffset: 0)
        renderPass.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        commandBuffer.addCompletedHandler { (cmdBuffer) in
            self.bufferIndex = (self.bufferIndex + 1) % MetalRenderer.inFlightBufferCount
            dispatch_semaphore_signal(self.displaySemaphore)
        }
    }
    
    private func updateUniforms(withDrawableSize drawableSize: float2, duration: Double) {
        time += Float(duration)
        rotationX += Float(duration * M_PI_2)
        rotationY += Float(duration * M_PI / 3)
        
        let scaleFactor : Float = sin(5*time) * 0.25 + 1
        let xRotMatrix = float3(1, 0, 0).rotationMatrix(withAngle: rotationX)
        let yRotMatrix = float3(0, 1, 0).rotationMatrix(withAngle: rotationY)
        let scaleMatrix = float4x4(diagonal: float4(scaleFactor, scaleFactor, scaleFactor, 1))
        
        let modelMatrix = (xRotMatrix * yRotMatrix) * scaleMatrix
        let viewMatrix = float3(0, 0, -5).translationMatrix
        let projectionMatrix = float4x4(perspectiveWithAspect: drawableSize.x*drawableSize.y, fovy: Float(2*M_PI/5), near: 1, far: 100)
        
        var uni = Uniforms(modelViewProjectionMatrix: projectionMatrix * (viewMatrix * modelMatrix))
        let bufferOffset = sizeof(Uniforms) * bufferIndex
        memcpy(uniformsBuffer.contents() + bufferOffset, &uni, sizeofValue(uni))
    }
}
