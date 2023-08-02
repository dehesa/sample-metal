import Foundation
import MetalKit
import simd

final class Renderer: NSObject, MTKViewDelegate {
  private let _metal: (view: MTKView, device: MTLDevice, queue: MTLCommandQueue)
  private let _pikachu: (mesh: MTKMesh, descriptor: MTLVertexDescriptor, texture: MTLTexture)
  private var _textures: (color: MTLTexture, depth: MTLTexture)
  private var _state: (main: MTLRenderPipelineState, post: MTLRenderPipelineState, depthStencil: MTLDepthStencilState)

  /// Designated initializer for the Pikachu renderer.
  /// - param device: Metal device where the mesh buffers, texture, and render pipelines will be created.
  /// - param view: MetalKit view being driven by this renderer.
  init(device: MTLDevice, view: MTKView) {
    self._metal = (view, device, device.makeCommandQueue()!)
    self._pikachu = Loader.loadPikachu(to: device)
    self._textures = Loader.makeOffScreenTargets(for: device, size: view.convertToBacking(view.drawableSize))

    let library = Loader.loadLibrary(to: device)
    let renderState = Loader.makeRenderStates(for: device, library: library, meshDescriptor: _pikachu.descriptor, view: view)
    let depthState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor().set {
      $0.depthCompareFunction = .less
      $0.isDepthWriteEnabled = true
    })!
    self._state = (renderState.main, renderState.post, depthState)

    super.init()
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    let previousSize = CGSize(width: self._textures.color.width, height: self._textures.color.height)
    if previousSize != size {
      self._textures = Loader.makeOffScreenTargets(for: self._metal.device, size: size)
    }
  }

  func draw(in view: MTKView) {
    guard let commandBuffer = self._metal.queue.makeCommandBuffer() else { return }
    self._mainPass(commandBuffer: commandBuffer, aspectRatio: Float(view.drawableSize.width / view.drawableSize.height))
    self._postPass(commandBuffer: commandBuffer, view: view)

    guard let drawable = view.currentDrawable else { return }
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

private extension Renderer {
  /// Uniform structure for the main render pass.
  struct _Uniforms {
    let modelViewMatrix: float4x4
    let projectionMatrix: float4x4
  }

  /// Main passing, which clears the screen to a "whitish" color and draw the pikachu with a bit of zoom out and in the center.
  /// The outcome of this pass is a texture with the size of the window with the pikachu right in the center.
  /// - parameter commandBuffer: Metal Command Buffer hosting all render passes.
  /// - parameter aspectRatio: Aspect ratio for the post render pass.
  func _mainPass(commandBuffer: MTLCommandBuffer, aspectRatio: Float) {
    let mainPassDescriptor = MTLRenderPassDescriptor().set {
      $0.colorAttachments[0].setUp { (attachment) in
        attachment.texture = self._textures.color
        attachment.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        attachment.loadAction = .clear
        attachment.storeAction = .store
      }
      $0.depthAttachment.setUp { (attachment) in
        attachment.texture = self._textures.depth
        attachment.clearDepth = 1.0
        attachment.loadAction = .clear
        attachment.storeAction = .dontCare
      }
    }

    guard let mainEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mainPassDescriptor) else { return }
    mainEncoder.setUp {
      $0.setRenderPipelineState(self._state.main)
      $0.setDepthStencilState(self._state.depthStencil)
      $0.setFragmentTexture(_pikachu.texture, index: 0)

      for (index, vertexBuffer) in self._pikachu.mesh.vertexBuffers.enumerated() {
        $0.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
      }

      let modelTransform = float4x4(translationBy: SIMD3<Float>(0, -1.1, 0)) * float4x4(scaleBy: Float(1 / 4.5))
      let cameraTransform = float4x4(translationBy: SIMD3<Float>(0, 0, -4))
      let projectionMatrix = float4x4(perspectiveProjectionFov: .pi / 6, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
      var uniforms = _Uniforms(modelViewMatrix: cameraTransform * modelTransform, projectionMatrix: projectionMatrix)
      $0.setVertexBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 1)

      let submesh = self._pikachu.mesh.submeshes[0]
      let indexBuffer = submesh.indexBuffer
      $0.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
    }
    mainEncoder.endEncoding()
  }

  /// Post-processing render pass where the fragment shaders will take place.
  /// - parameter commandBuffer: Metal Command Buffer hosting all render passes.
  /// - parameter view: MetalKit view hosting the final framebuffer.
  func _postPass(commandBuffer: MTLCommandBuffer, view: MTKView) {
    guard let postPassDescriptor = view.currentRenderPassDescriptor,
          let postEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: postPassDescriptor) else { return }
    postEncoder.setUp {
      $0.setRenderPipelineState(self._state.post)
      $0.setFragmentTexture(self._textures.color, index: 0)

      let vertexData: [Float] = [-1, -1,  0,  1,
                                  -1,  1,  0,  0,
                                  1, -1,  1,  1,
                                  1,  1,  1,  0]
      $0.setVertexBytes(vertexData, length: 16*4, index: 0)
      $0.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    postEncoder.endEncoding()
  }
}
