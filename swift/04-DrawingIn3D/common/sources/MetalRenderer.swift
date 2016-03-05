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
    
    // MARK: Properties
    
    private let device : MTLDevice
    private let pipelineState : MTLRenderPipelineState
    private let depthStencilState : MTLDepthStencilState
    private var commandQueue : MTLCommandQueue
    private let verticesBuffer : MTLBuffer
    private let indecesBuffer : MTLBuffer
    private let uniformsBuffer : MTLBuffer
    
    private let displaySemaphore : dispatch_semaphore_t = dispatch_semaphore_create(1)
    private var (time, rotationX, rotationY) : (Float, Float, Float) = (0,0,0)
    
    // MARK: Initializer
    
    init(withDevice device: MTLDevice) {
        self.device = device
        commandQueue = device.newCommandQueue()
        
        guard let library = device.newDefaultLibrary() else { fatalError("No default library") }
        guard let vertexFunc: MTLFunction = library.newFunctionWithName("main_vertex"),
              let fragmentFunc: MTLFunction = library.newFunctionWithName("main_fragment") else { fatalError("Shader not found") }
        
        pipelineState = try! device.newRenderPipelineStateWithDescriptor({ () -> MTLRenderPipelineDescriptor in
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            descriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
            descriptor.depthAttachmentPixelFormat = .Depth32Float
            return descriptor
        }())

        depthStencilState = device.newDepthStencilStateWithDescriptor({
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.depthCompareFunction = .Less
            descriptor.depthWriteEnabled = true
            return descriptor
        }())
        
        // Setup buffers
        let vertices = [    // Coordinates defined in clip space coords: [-1,+1]
            Vertex(position: [-1,  1,  1, 1], color: [0, 1, 1, 1]),
            Vertex(position: [-1, -1,  1, 1], color: [0, 0, 1, 1]),
            Vertex(position: [ 1, -1,  1, 1], color: [1, 0, 1, 1]),
            Vertex(position: [ 1,  1,  1, 1], color: [1, 1, 1, 1]),
            Vertex(position: [-1,  1, -1, 1], color: [0, 1, 0, 1]),
            Vertex(position: [-1, -1, -1, 1], color: [0, 0, 0, 1]),
            Vertex(position: [ 1, -1, -1, 1], color: [1, 0, 0, 1]),
            Vertex(position: [ 1,  1, -1, 1], color: [1, 1, 0, 1]) ]
        verticesBuffer = device.newBufferWithBytes(vertices, length: vertices.count*sizeof(Vertex), options: .CPUCacheModeDefaultCache)
        verticesBuffer.label = "Vertices"
        
        typealias IndexType = UInt16
        let indices : [IndexType] = [
            3, 2, 6, 6, 7, 3,
            4, 5, 1, 1, 0, 4,
            4, 0, 3, 3, 7, 4,
            1, 5, 6, 6, 2, 1,
            0, 1, 2, 2, 3, 0,
            7, 6, 5, 5, 4, 7, ]
        indecesBuffer = device.newBufferWithBytes(indices, length: indices.count*sizeof(IndexType), options: .CPUCacheModeDefaultCache)
        indecesBuffer.label = "Indices"
        
        uniformsBuffer = device.newBufferWithLength(sizeof(Uniforms), options: .CPUCacheModeDefaultCache)
        uniformsBuffer.label = "Uniforms"
    }
    
    // MARK: Functionality
    
    func drawInView(metalView: MetalView) {
        dispatch_semaphore_wait(self.displaySemaphore, DISPATCH_TIME_FOREVER);
        guard let drawable = metalView.currentDrawable else { dispatch_semaphore_signal(self.displaySemaphore); return }
        
        let drawableSize = metalView.metalLayer.drawableSize
        updateUniforms(withDrawableSize: float2(Float(drawableSize.width), Float(drawableSize.height)), duration: metalView.frameDuration)

        let commandBuffer = commandQueue.commandBuffer()
        let encoder = commandBuffer.renderCommandEncoderWithDescriptor(metalView.currentRenderPassDescriptor!)
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthStencilState)
        encoder.setFrontFacingWinding(.CounterClockwise)
        encoder.setCullMode(.Back)
        
        encoder.setVertexBuffer(verticesBuffer, offset: 0, atIndex: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, atIndex: 1)
        encoder.drawIndexedPrimitives(.Triangle, indexCount: indecesBuffer.length / sizeof(UInt16), indexType: .UInt16, indexBuffer: indecesBuffer, indexBufferOffset: 0)
        encoder.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        commandBuffer.addCompletedHandler { (_) in dispatch_semaphore_signal(self.displaySemaphore) }
        commandBuffer.commit()
    }
    
    private func updateUniforms(withDrawableSize drawableSize: float2, duration: Double) {
        time += Float(duration)
        rotationX += Float(duration * M_PI_2)
        rotationY += Float(duration * M_PI / 3)
        
        let scaleFactor : Float = sin(5*time) * 0.25 + 1
        let xRotMatrix = float3(1, 0, 0).rotationMatrix(withAngle: rotationX)
        let yRotMatrix = float3(0, 1, 0).rotationMatrix(withAngle: rotationY)
        let scaleMatrix = float4x4(diagonal: [scaleFactor, scaleFactor, scaleFactor, 1])
        let modelMatrix = (xRotMatrix * yRotMatrix) * scaleMatrix
        
        let viewMatrix = float3(0, 0, -5).translationMatrix
        let projectionMatrix = float4x4(perspectiveWithAspect: drawableSize.x/drawableSize.y, fovy: Float(2*M_PI/5), near: 1, far: 100)
        
        var uni = Uniforms(modelViewProjectionMatrix:  projectionMatrix * (viewMatrix * modelMatrix))
        memcpy(uniformsBuffer.contents(), &uni, sizeof(Uniforms))
    }
}
