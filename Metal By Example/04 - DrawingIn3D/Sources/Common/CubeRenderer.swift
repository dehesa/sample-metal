import Metal
import simd

extension CubeRenderer {
    private struct Vertex {
        var position: float4
        var color: float4
    }
    
    private struct Uniforms {
        var modelViewProjectionMatrix: float4x4
    }
}

class CubeRenderer: MetalViewDelegate {
    private let device: MTLDevice
    private let renderPipeline: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private var commandQueue: MTLCommandQueue
    private let verticesBuffer: MTLBuffer
    private let indecesBuffer: MTLBuffer
    private let uniformsBuffer: MTLBuffer
    
    private let displaySemaphore = DispatchSemaphore(value: 3)
    private var (time, rotationX, rotationY): (Float, Float, Float) = (0,0,0)
    
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
        
        // Setup buffers. Coordinates defined in clip space coords: [-1,+1] for x and y; and [0,+1] for z.
        let vertices = [Vertex(position: [-1,  1,  1, 1], color: [0, 1, 1, 1]), // left,  top,    back
                        Vertex(position: [-1, -1,  1, 1], color: [0, 0, 1, 1]), // left,  bottom, back
                        Vertex(position: [ 1, -1,  1, 1], color: [1, 0, 1, 1]), // right, bottom, back
                        Vertex(position: [ 1,  1,  1, 1], color: [1, 1, 1, 1]), // right, top,    back
                        Vertex(position: [-1,  1, -1, 1], color: [0, 1, 0, 1]), // left,  top,    front
                        Vertex(position: [-1, -1, -1, 1], color: [0, 0, 0, 1]), // left,  bottom, front
                        Vertex(position: [ 1, -1, -1, 1], color: [1, 0, 0, 1]), // right, bottom, front
                        Vertex(position: [ 1,  1, -1, 1], color: [1, 1, 0, 1])] // right, top,    front
        self.verticesBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride)!.set {
            $0.label = "me.dehesa.metal.buffers.vertices"
        }
        typealias IndexType = UInt16
        let indices: [IndexType] = [3, 2, 6, 6, 7, 3,
                                    4, 5, 1, 1, 0, 4,
                                    4, 0, 3, 3, 7, 4,
                                    1, 5, 6, 6, 2, 1,
                                    0, 1, 2, 2, 3, 0,
                                    7, 6, 5, 5, 4, 7, ]
        self.indecesBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<IndexType>.stride)!.set {
            $0.label = "me.dehesa.metal.buffers.indices"
        }
        self.uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride)!.set {
            $0.label = "me.dehesa.metal.buffers.uniform"
        }
    }
    
    func draw(view metalView: MetalView) {
        self.displaySemaphore.wait()
        guard let drawable = metalView.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPass = metalView.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            let _ = self.displaySemaphore.signal()
            return
        }
        
        let drawableSize = metalView.metalLayer.drawableSize
        updateUniforms(drawableSize: [Float(drawableSize.width), Float(drawableSize.height)], duration: Float(metalView.frameDuration))
        
        encoder.setUp {
            $0.setRenderPipelineState(self.renderPipeline)
            $0.setDepthStencilState(self.depthStencilState)
            $0.setFrontFacing(.counterClockwise)
            $0.setCullMode(.back)
            
            $0.setVertexBuffer(self.verticesBuffer, offset: 0, index: 0)
            $0.setVertexBuffer(self.uniformsBuffer, offset: 0, index: 1)
            $0.drawIndexedPrimitives(type: .triangle, indexCount: self.indecesBuffer.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: indecesBuffer, indexBufferOffset: 0)
            $0.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { (_) in let _ = self.displaySemaphore.signal() }
        commandBuffer.commit()
    }
    
    private func updateUniforms(drawableSize: float2, duration: Float) {
        self.time += duration
        self.rotationX += (.𝝉 / 4.0) * duration
        self.rotationY += (.𝝉 / 6.0) * duration
        
        let scaleFactor: Float = 1 + 0.25*sin(5 * self.time)
        let xRotMatrix = float4x4(rotate: [1, 0, 0], angle: self.rotationX)
        let yRotMatrix = float4x4(rotate: [0, 1, 0], angle: self.rotationX)
        let scaleMatrix = float4x4(diagonal: [scaleFactor, scaleFactor, scaleFactor, 1])
        let modelMatrix = (yRotMatrix * xRotMatrix) * scaleMatrix
        
        let viewMatrix = float4x4(translate: float3(0, 0, -5))  // Move the camera 5 units on the -z axis. Equal to push object 5 units on +z axis diraction.
        let projectionMatrix = float4x4(perspectiveWithAspect: drawableSize.x/drawableSize.y, fovy: .𝝉/5, near: 1, far: 100)
        
        
        let ptr = uniformsBuffer.contents().assumingMemoryBound(to: Uniforms.self)
        ptr.pointee = Uniforms(modelViewProjectionMatrix:  projectionMatrix * (viewMatrix * modelMatrix))
    }
}
