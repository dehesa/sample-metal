import Metal
import simd

final class CubeRenderer: MetalViewDelegate {
  private let _device: MTLDevice
  private let _renderPipeline: MTLRenderPipelineState
  private let _depthStencilState: MTLDepthStencilState
  private var _commandQueue: MTLCommandQueue
  private let _verticesBuffer: MTLBuffer
  private let _indecesBuffer: MTLBuffer
  private let _uniformsBuffer: MTLBuffer

  private let _displaySemaphore = DispatchSemaphore(value: 3)
  private var (_time, _rotationX, _rotationY): (Float, Float, Float) = (0,0,0)

  init(withDevice device: MTLDevice) {
    self._device = device
    self._commandQueue = device.makeCommandQueue()!

    guard let library = device.makeDefaultLibrary(),
          let vertexFunc   = library.makeFunction(name: "main_vertex"),
          let fragmentFunc = library.makeFunction(name: "main_fragment") else { fatalError("Library or Shaders not found") }

    self._renderPipeline = try! device.makeRenderPipelineState(descriptor: MTLRenderPipelineDescriptor().set {
      $0.vertexFunction = vertexFunc
      $0.fragmentFunction = fragmentFunc
      $0.colorAttachments[0].pixelFormat = .bgra8Unorm
      $0.depthAttachmentPixelFormat = .depth32Float
    })

    self._depthStencilState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor().set {
      $0.depthCompareFunction = .less
      $0.isDepthWriteEnabled = true
    })!

    // Setup buffers. Coordinates defined in clip space coords: [-1,+1] for x and y; and [0,+1] for z.
    let vertices = [_Vertex(position: [-1,  1,  1, 1], color: [0, 1, 1, 1]), // left,  top,    back
                    _Vertex(position: [-1, -1,  1, 1], color: [0, 0, 1, 1]), // left,  bottom, back
                    _Vertex(position: [ 1, -1,  1, 1], color: [1, 0, 1, 1]), // right, bottom, back
                    _Vertex(position: [ 1,  1,  1, 1], color: [1, 1, 1, 1]), // right, top,    back
                    _Vertex(position: [-1,  1, -1, 1], color: [0, 1, 0, 1]), // left,  top,    front
                    _Vertex(position: [-1, -1, -1, 1], color: [0, 0, 0, 1]), // left,  bottom, front
                    _Vertex(position: [ 1, -1, -1, 1], color: [1, 0, 0, 1]), // right, bottom, front
                    _Vertex(position: [ 1,  1, -1, 1], color: [1, 1, 0, 1])] // right, top,    front
    self._verticesBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<_Vertex>.stride, options: .cpuCacheModeWriteCombined)!.set {
      $0.label = "io.dehesa.metal.buffers.vertices"
    }
    typealias IndexType = UInt16
    let indices: [IndexType] = [3, 2, 6, 6, 7, 3,   4, 5, 1, 1, 0, 4,
                                4, 0, 3, 3, 7, 4,   1, 5, 6, 6, 2, 1,
                                0, 1, 2, 2, 3, 0,   7, 6, 5, 5, 4, 7 ]
    self._indecesBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<IndexType>.stride, options: .cpuCacheModeWriteCombined)!.set {
      $0.label = "io.dehesa.metal.buffers.indices"
    }
    self._uniformsBuffer = device.makeBuffer(length: MemoryLayout<_Uniforms>.stride)!.set {
      $0.label = "io.dehesa.metal.buffers.uniform"
    }
  }

  func draw(view metalView: MetalView) {
    self._displaySemaphore.wait()
    guard let drawable = metalView.currentDrawable,
          let commandBuffer = _commandQueue.makeCommandBuffer(),
          let renderPass = metalView.currentRenderPassDescriptor,
          let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            let _ = self._displaySemaphore.signal()
            return
          }

    let drawableSize = metalView.metalLayer.drawableSize
    self._updateUniforms(drawableSize: [Float(drawableSize.width), Float(drawableSize.height)], duration: Float(metalView.frameDuration))

    encoder.setUp {
      $0.setRenderPipelineState(self._renderPipeline)
      $0.setDepthStencilState(self._depthStencilState)
      $0.setFrontFacing(.counterClockwise)
      $0.setCullMode(.back)

      $0.setVertexBuffer(self._verticesBuffer, offset: 0, index: 0)
      $0.setVertexBuffer(self._uniformsBuffer, offset: 0, index: 1)
      $0.drawIndexedPrimitives(type: .triangle, indexCount: self._indecesBuffer.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: _indecesBuffer, indexBufferOffset: 0)
      $0.endEncoding()
    }

    commandBuffer.present(drawable)
    commandBuffer.addCompletedHandler { (_) in let _ = self._displaySemaphore.signal() }
    commandBuffer.commit()
  }
}

private extension CubeRenderer {
  struct _Vertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
  }

  struct _Uniforms {
    var modelViewProjectionMatrix: float4x4
  }

  func _updateUniforms(drawableSize: SIMD2<Float>, duration: Float) {
    self._time += duration
    self._rotationX += (.𝝉 / 4.0) * duration
    self._rotationY += (.𝝉 / 6.0) * duration

    let scaleFactor: Float = 1 + 0.25*sin(5 * self._time)
    let xRotMatrix = float4x4(rotate: [1, 0, 0], angle: self._rotationX)
    let yRotMatrix = float4x4(rotate: [0, 1, 0], angle: self._rotationX)
    let scaleMatrix = float4x4(diagonal: [scaleFactor, scaleFactor, scaleFactor, 1])
    let modelMatrix = yRotMatrix * (xRotMatrix * scaleMatrix)
    // Move the camera 5 units on the -z axis. Equal to push object 5 units on +z axis diraction.
    let viewMatrix = float4x4(translate: SIMD3<Float>(0, 0, -5))
    let projectionMatrix = float4x4(perspectiveWithAspect: drawableSize.x/drawableSize.y, fovy: .𝝉/5, near: 1, far: 100)


    let ptr = self._uniformsBuffer.contents().assumingMemoryBound(to: _Uniforms.self)
    ptr.pointee = _Uniforms(modelViewProjectionMatrix: projectionMatrix * (viewMatrix * modelMatrix))
  }
}
