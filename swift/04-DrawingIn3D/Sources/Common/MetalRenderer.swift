import Metal
import simd

extension MetalRenderer {
    private struct Vertex {
        var position: float4
        var color: float4
    }
    
    private struct Uniforms {
        var modelViewProjectionMatrix: float4x4
    }
}

class MetalRenderer: MetalViewDelegate {
    private let device: MTLDevice
    private let renderPipeline: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private var commandQueue: MTLCommandQueue
    private let verticesBuffer: MTLBuffer
    private let indecesBuffer: MTLBuffer
    private let uniformsBuffer: MTLBuffer
    
    private let displaySemaphore = DispatchSemaphore(value: 3)
    private var (time, rotationX, rotationY): (Float, Float, Float) = (0,0,0)
    
    // MARK: Initializer
    
    init(withDevice device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc   = library.makeFunction(name: "main_vertex"),
              let fragmentFunc = library.makeFunction(name: "main_fragment") else { fatalError("Library or Shaders not found") }
        
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
        
        // Setup buffers. Coordinates defined in clip space coords: [-1,+1]
        let vertices = [Vertex(position: [-1,  1,  1, 1], color: [0, 1, 1, 1]),
                        Vertex(position: [-1, -1,  1, 1], color: [0, 0, 1, 1]),
                        Vertex(position: [ 1, -1,  1, 1], color: [1, 0, 1, 1]),
                        Vertex(position: [ 1,  1,  1, 1], color: [1, 1, 1, 1]),
                        Vertex(position: [-1,  1, -1, 1], color: [0, 1, 0, 1]),
                        Vertex(position: [-1, -1, -1, 1], color: [0, 0, 0, 1]),
                        Vertex(position: [ 1, -1, -1, 1], color: [1, 0, 0, 1]),
                        Vertex(position: [ 1,  1, -1, 1], color: [1, 1, 0, 1]) ]
        self.verticesBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride)!
        verticesBuffer.label = "Vertices"
        
        typealias IndexType = UInt16
        let indices: [IndexType] = [3, 2, 6, 6, 7, 3,
                                    4, 5, 1, 1, 0, 4,
                                    4, 0, 3, 3, 7, 4,
                                    1, 5, 6, 6, 2, 1,
                                    0, 1, 2, 2, 3, 0,
                                    7, 6, 5, 5, 4, 7, ]
        indecesBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<IndexType>.stride)!
        indecesBuffer.label = "Indices"
        
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride)!
        uniformsBuffer.label = "Uniforms"
    }
    
    func drawInView(_ metalView: MetalView) {
        displaySemaphore.wait()
        guard let drawable = metalView.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPass = metalView.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            displaySemaphore.signal()
            return
        }
        
        let drawableSize = metalView.metalLayer.drawableSize
        updateUniforms(withDrawableSize: float2(Float(drawableSize.width), Float(drawableSize.height)), duration: metalView.frameDuration)
        
        encoder.setRenderPipelineState(renderPipeline)
        encoder.setDepthStencilState(depthStencilState)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)
        
        encoder.setVertexBuffer(verticesBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: indecesBuffer.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: indecesBuffer, indexBufferOffset: 0)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { (_) in self.displaySemaphore.signal() }
        commandBuffer.commit()
    }
    
    private func updateUniforms(withDrawableSize drawableSize: float2, duration: Double) {
        self.time += Float(duration)
        self.rotationX += Float(duration * .pi * 0.5)
        self.rotationY += Float(duration * .pi / 3)
        
        let scaleFactor: Float = sin(5*time) * 0.25 + 1
        let xRotMatrix = float3(1, 0, 0).rotationMatrix(withAngle: rotationX)
        let yRotMatrix = float3(0, 1, 0).rotationMatrix(withAngle: rotationY)
        let scaleMatrix = float4x4(diagonal: [scaleFactor, scaleFactor, scaleFactor, 1])
        let modelMatrix = (xRotMatrix * yRotMatrix) * scaleMatrix
        
        let viewMatrix = float3(0, 0, -5).translationMatrix
        let projectionMatrix = float4x4(perspectiveWithAspect: drawableSize.x/drawableSize.y, fovy: Float(2*Double.pi/5), near: 1, far: 100)
        
        var uni = Uniforms(modelViewProjectionMatrix:  projectionMatrix * (viewMatrix * modelMatrix))
        memcpy(uniformsBuffer.contents(), &uni, MemoryLayout<Uniforms>.size)
    }
}
