import Metal
import simd

extension MetalRenderer {
    private struct Uniforms {
        var modelViewProjectionMatrix: float4x4
    }
}

class MetalRenderer: MetalViewDelegate {
    private let device: MTLDevice
    private let renderPipeline: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private var commandQueue: MTLCommandQueue
    private let mesh: Mesh
    private let uniformsBuffer: MTLBuffer
    
    private let displaySemaphore = DispatchSemaphore(value: 3)
    private var (time, rotationX, rotationY): (Float, Float, Float) = (0,0,0)
    
    init(withDevice device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc: MTLFunction = library.makeFunction(name: "main_vertex"),
              let fragmentFunc: MTLFunction = library.makeFunction(name: "main_fragment") else { fatalError("Library or Shaders not found") }
        
        self.renderPipeline = try! device.makeRenderPipelineState(descriptor: MTLRenderPipelineDescriptor().set {
            $0.vertexFunction = vertexFunc
            $0.fragmentFunction = fragmentFunc
            $0.colorAttachments[0].pixelFormat = .bgra8Unorm
            $0.depthAttachmentPixelFormat = .depth32Float
        })

        self.depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor().set {
            $0.depthCompareFunction = .less
            $0.isDepthWriteEnabled = true
        })!
        
        // Setup buffers
        guard let modelURL = Bundle.main.url(forResource: "teapot", withExtension: "obj") else { fatalError("teapot not found") }
        let model = try! Model.OBJ(url: modelURL, generateNormals: true)
        self.mesh = try! Mesh(group: model[name: "teapot"], device: device)
		
        self.uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride)!
        self.uniformsBuffer.label = "me.dehesa.metal.buffers.uniform"
    }
    
    func draw(view metalView: MetalView) {
//        displaySemaphore.wait()
//        guard let drawable = metalView.currentDrawable,
//            let commandBuffer = commandQueue.makeCommandBuffer(),
//            let renderPass = metalView.currentRenderPassDescriptor,
//            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
//                let _ = displaySemaphore.signal()
//                return
//        }
//        
//        let drawableSize = metalView.metalLayer.drawableSize
//        updateUniforms(drawableSize: float2(Float(drawableSize.width), Float(drawableSize.height)), duration: Float(metalView.frameDuration))
//        
//        encoder.setRenderPipelineState(self.renderPipeline)
//        encoder.setDepthStencilState(self.depthStencilState)
//        encoder.setFrontFacing(.counterClockwise)
//        encoder.setCullMode(.back)
//        
//        encoder.setVertexBuffer(self.mesh.vertexBuffer, offset: 0, index: 0)
//        encoder.setVertexBuffer(self.uniformsBuffer, offset: 0, index: 1)
//        encoder.drawIndexedPrimitives(type: .triangle, indexCount: self.mesh.indexBuffer.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: self.mesh.indexBuffer, indexBufferOffset: 0)
//        encoder.endEncoding()
//        
//        commandBuffer.present(drawable)
//        commandBuffer.addCompletedHandler { (_) in let _ = self.displaySemaphore.signal() }
//        commandBuffer.commit()
    }
    
    private func updateUniforms(drawableSize: float2, duration: Float) {
        self.time += duration
        self.rotationX += (0.25 * .tau) * duration
        self.rotationY += (.tau / 6.0) * duration
        
        let scaleFactor: Float = 1
        let xRotMatrix = float4x4(rotate: float3(1, 0, 0), angle: self.rotationX)
        let yRotMatrix = float4x4(rotate: float3(0, 1, 0), angle: self.rotationX)
        let scaleMatrix = float4x4(diagonal: [scaleFactor, scaleFactor, scaleFactor, 1])
        let modelMatrix = (xRotMatrix * yRotMatrix) * scaleMatrix
        
        let viewMatrix = float4x4(translation: float3(0, 0, -1.5))
        let projectionMatrix = float4x4(perspectiveWithAspect: drawableSize.x/drawableSize.y, fovy: .tau/5, near: 0.1, far: 100)
        
        var uni = Uniforms(modelViewProjectionMatrix:  projectionMatrix * (viewMatrix * modelMatrix))
        memcpy(uniformsBuffer.contents(), &uni, MemoryLayout<Uniforms>.size)
    }
}
