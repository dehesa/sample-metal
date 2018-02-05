import Foundation
import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    private let metal: (view: MTKView, device: MTLDevice, queue: MTLCommandQueue)
    private let pikachu: (mesh: MTKMesh, descriptor: MTLVertexDescriptor, texture: MTLTexture)
    private var textures: (color: MTLTexture, depth: MTLTexture)
    private var state: (main: MTLRenderPipelineState, post: MTLRenderPipelineState, depthStencil: MTLDepthStencilState)
    
    private let reloadFrame = 10
    private var frameCounter = 0
    
    /// Designated initializer for the Pikachu renderer.
    /// - param device: Metal device where the mesh buffers, texture, and render pipelines will be created.
    /// - param view: MetalKit view being driven by this renderer.
    init(device: MTLDevice, view: MTKView) {
        self.metal = (view, device, device.makeCommandQueue()!)
        self.pikachu = Loader.loadPikachu(to: device)
        self.textures = Loader.makeOffScreenTargets(for: device, size: view.convertToBacking(view.drawableSize))
        
        let library = Loader.loadLibrary(to: device)
        let renderState = Loader.makeRenderStates(for: device, library: library, meshDescriptor: pikachu.descriptor, view: view)
        let depthState = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor().set {
            $0.depthCompareFunction = .less
            $0.isDepthWriteEnabled = true
        })!
        self.state = (renderState.main, renderState.post, depthState)
        
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let previousSize = CGSize(width: self.textures.color.width, height: self.textures.color.height)
        if previousSize != size {
            self.textures = Loader.makeOffScreenTargets(for: self.metal.device, size: size)
        }
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = self.metal.queue.makeCommandBuffer() else { return }
        self.mainPass(commandBuffer: commandBuffer, view: view)
        self.postPass(commandBuffer: commandBuffer, view: view)
        
        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension Renderer {
    private struct Uniforms {
        let modelViewMatrix: float4x4
        let projectionMatrix: float4x4
    }
    
    private func mainPass(commandBuffer: MTLCommandBuffer, view: MTKView) {
        let mainPassDescriptor = MTLRenderPassDescriptor().set {
            $0.colorAttachments[0].setUp { (attachment) in
                attachment.texture = self.textures.color
                attachment.clearColor = MTLClearColor(red: 0.95, green: 0, blue: 0, alpha: 1)
                attachment.loadAction = .clear
                attachment.storeAction = .store
            }
            $0.depthAttachment.setUp { (attachment) in
                attachment.texture = self.textures.depth
                attachment.clearDepth = 1.0
                attachment.loadAction = .clear
                attachment.storeAction = .dontCare
            }
        }
        
        guard let mainEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mainPassDescriptor) else { return }
        mainEncoder.setUp {
            $0.setRenderPipelineState(self.state.main)
            $0.setDepthStencilState(self.state.depthStencil)
            $0.setFragmentTexture(pikachu.texture, index: 0)
            
            for (index, vertexBuffer) in self.pikachu.mesh.vertexBuffers.enumerated() {
                $0.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
            }
            
            let modelTransform = float4x4(translationBy: float3(0, -1.1, 0)) * float4x4(scaleBy: Float(1 / 4.5))
            let cameraTransform = float4x4(translationBy: float3(0, 0, -4))
            let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
            let projectionMatrix = float4x4(perspectiveProjectionFov: .pi / 6, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
            var uniforms = Uniforms(modelViewMatrix: cameraTransform * modelTransform, projectionMatrix: projectionMatrix)
            $0.setVertexBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 1)
            
            let submesh = self.pikachu.mesh.submeshes[0]
            let indexBuffer = submesh.indexBuffer
            $0.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
        }
        mainEncoder.endEncoding()
    }
    
    private func postPass(commandBuffer: MTLCommandBuffer, view: MTKView) {
        guard let postPassDescriptor = view.currentRenderPassDescriptor,
            let postEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: postPassDescriptor) else { return }
        postEncoder.setUp {
            $0.setRenderPipelineState(self.state.post)
            $0.setFragmentTexture(self.textures.color, index: 0)
            
            let vertexData: [Float] = [-1, -1, 0, 1,    -1, 1, 0, 0,    1, -1, 1, 1,    1, 1, 1, 0]
            $0.setVertexBytes(vertexData, length: 16*4, index: 0)
            $0.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        postEncoder.endEncoding()
    }
}
