import Metal
import simd

class MetalRenderer : MetalViewDelegate {
    
    // MARK: Definitions
    
    private struct Uniforms {
        var modelViewProjectionMatrix : float4x4
    }
    
    // MARK: Properties
    
    private let device : MTLDevice
    private let pipelineState : MTLRenderPipelineState
    private let depthStencilState : MTLDepthStencilState
    private var commandQueue : MTLCommandQueue
	private let mesh : Mesh
    private let uniformsBuffer : MTLBuffer
    
    private let displaySemaphore : dispatch_semaphore_t = dispatch_semaphore_create(1)
    private var (time, rotationX, rotationY) : (Float, Float, Float) = (0,0,0)
    
    // MARK: Initializer
    
    init(withDevice device: MTLDevice) {
        self.device = device
        commandQueue = device.newCommandQueue()
        
        guard let library = device.newDefaultLibrary() else { fatalError("No default library") }
        guard let vertexFunc: MTLFunction = library.newFunctionWithName("main_vertex"),
              let fragmentFunc: MTLFunction = library.newFunctionWithName("main_fragment") else { fatalError("Shaders not found") }
        
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
		guard let modelURL = NSBundle.mainBundle().URLForResource("teapot", withExtension: "obj") else { fatalError("teapot not found") }
		guard let model = ModelOBJ(withURL: modelURL, generateNormals: true) else { fatalError("teapot cound not be generated") }
		guard let group = model.group(withName: "teapot") else { fatalError("teapot group not found") }
		mesh = Mesh(withOBJGroup: group, device: device)
		
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
        
        encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, atIndex: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, atIndex: 1)
        encoder.drawIndexedPrimitives(.Triangle, indexCount: mesh.indexBuffer.length / sizeof(UInt16), indexType: .UInt16, indexBuffer: mesh.indexBuffer, indexBufferOffset: 0)
        encoder.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        commandBuffer.addCompletedHandler { (_) in dispatch_semaphore_signal(self.displaySemaphore) }
        commandBuffer.commit()
    }
    
    private func updateUniforms(withDrawableSize drawableSize: float2, duration: Double) {
        time += Float(duration)
        rotationX += Float(duration * M_PI_2)
        rotationY += Float(duration * M_PI / 3)
        
        let scaleFactor : Float = 1
        let xRotMatrix = float3(1, 0, 0).rotationMatrix(withAngle: rotationX)
        let yRotMatrix = float3(0, 1, 0).rotationMatrix(withAngle: rotationY)
        let scaleMatrix = float4x4(diagonal: [scaleFactor, scaleFactor, scaleFactor, 1])
        let modelMatrix = (xRotMatrix * yRotMatrix) * scaleMatrix
        
        let viewMatrix = float3(0, 0, -1.5).translationMatrix
        let projectionMatrix = float4x4(perspectiveWithAspect: drawableSize.x/drawableSize.y, fovy: Float(2*M_PI/5), near: 0.1, far: 100)
        
        var uni = Uniforms(modelViewProjectionMatrix:  projectionMatrix * (viewMatrix * modelMatrix))
        memcpy(uniformsBuffer.contents(), &uni, sizeof(Uniforms))
    }
}
