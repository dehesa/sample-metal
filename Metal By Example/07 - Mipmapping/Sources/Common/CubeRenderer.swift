import Metal
import MetalKit
import ModelIO
import simd

extension CubeRenderer {
    private struct Uniforms {
        var modelViewProjectionMatrix: float4x4
        var modelViewMatrix: float4x4
        var normalMatrix: float3x3
    }
    
    enum Error: Swift.Error {
        case failedToCreateMetalDevice
        case failedToCreateMetalCommandQueue(device: MTLDevice)
        case failedToCreateMetalLibrary(device: MTLDevice)
        case failedToCreateShaderFunction(name: String)
        case failedToCreateDepthStencilState(device: MTLDevice)
        case failedToFoundFile(name: String)
        case failedToCreateMetalBuffer(device: MTLDevice)
        case failedToCreateMetalSampler(device: MTLDevice)
    }
}

class CubeRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let state: (render: MTLRenderPipelineState, depth: MTLDepthStencilState)
    private let uniformsBuffer: MTLBuffer
    private let diffuseTexture: MTLTexture
    private let samplerTexture: MTLSamplerState
    private let meshes: [MTKMesh]
    private var (time, rotationX, rotationY): (Float, Float, Float) = (0,0,0)
    
    init(view: MTKView) throws {
        // Create GPU representation (MTLDevice) and Command Queue.
        guard let device = MTLCreateSystemDefaultDevice() else { throw Error.failedToCreateMetalDevice }
        guard let commandQueue = device.makeCommandQueue() else { throw Error.failedToCreateMetalCommandQueue(device: device) }
        (self.device, self.commandQueue) = (device, commandQueue)
        
        // Creates the render states
        let pixelFormats: PixelFormats = (.bgra8Unorm, .depth32Float)
        let descriptors = try CubeRenderer.makeStateDescriptors(device: device, pixelFormats: pixelFormats)
        let renderPipelineState = try device.makeRenderPipelineState(descriptor: descriptors.renderPipeline)
        guard let depthStencilState = device.makeDepthStencilState(descriptor: descriptors.depthStencil) else { throw Error.failedToCreateDepthStencilState(device: device) }
        self.state = (renderPipelineState, depthStencilState)
        
        /// Creates the texture and meshes from the external models.
        self.meshes = try CubeRenderer.makeMeshes(device: device, vertexDescriptor: descriptors.renderPipeline.vertexDescriptor!)
        (self.diffuseTexture, self.samplerTexture) = try CubeRenderer.makeTexture(device: device)
        
        // Create buffers used in the shader
        guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride) else { throw Error.failedToCreateMetalBuffer(device: device) }
        uniformBuffer.label = "me.dehesa.metal.buffers.uniform"
        self.uniformsBuffer = uniformBuffer
        
        // Setup the MTKView.
        view.setUp {
            ($0.device, $0.clearColor) = (device, MTLClearColorMake(0, 0, 0, 1))
            ($0.colorPixelFormat, $0.depthStencilPixelFormat) = pixelFormats
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        guard let mesh = meshes.first,
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor else { return }
        
        descriptor.setUp {
            $0.colorAttachments[0].texture = drawable.texture
            $0.colorAttachments[0].loadAction = .clear
            $0.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)
        }
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        let drawableSize = drawable.layer.drawableSize.float2
        updateUniforms(drawableSize: drawableSize, duration: Float(1.0 / 60.0))
        
        do {
            encoder.setRenderPipelineState(self.state.render)
            encoder.setDepthStencilState(self.state.depth)
            encoder.setCullMode(.back)
            encoder.setFrontFacing(.counterClockwise)
            
            let vertexBuffer = mesh.vertexBuffers[0]
            encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
            encoder.setVertexBuffer(self.uniformsBuffer, offset: 0, index: 1)
            encoder.setFragmentTexture(self.diffuseTexture, index: 0)
            encoder.setFragmentSamplerState(self.samplerTexture, index: 0)
            
            guard let submesh = mesh.submeshes.first else { fatalError("Submesh not found.") }
            encoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
            
            encoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension CubeRenderer {
    /// Pixel formats used by the renderer.
    typealias PixelFormats = (color: MTLPixelFormat, depth: MTLPixelFormat)
    
    /// Creates the descriptors for the render pipeline state and depth stencil state.
    private static func makeStateDescriptors(device: MTLDevice, pixelFormats: PixelFormats) throws -> (renderPipeline: MTLRenderPipelineDescriptor, depthStencil: MTLDepthStencilDescriptor) {
        // Initialize the library and respective metal functions.
        let functionName: (vertex: String, fragment: String) = ("main_vertex", "main_fragment")
        guard let library = device.makeDefaultLibrary() else { throw Error.failedToCreateMetalLibrary(device: device) }
        guard let vertexFunction = library.makeFunction(name: functionName.vertex) else { throw Error.failedToCreateShaderFunction(name: functionName.vertex) }
        guard let fragmentFunction = library.makeFunction(name: functionName.fragment) else { throw Error.failedToCreateShaderFunction(name: functionName.fragment) }
        
        // Define both states (render and depth-stencil).
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor().set { (pipeline) in
            pipeline.vertexFunction = vertexFunction
            pipeline.vertexDescriptor = MTLVertexDescriptor().set {
                $0.attributes[0].setUp { (attribute) in
                    attribute.bufferIndex = 0
                    attribute.offset = 0
                    attribute.format = .float3
                }
                $0.attributes[1].setUp { (attribute) in
                    attribute.bufferIndex = 0
                    attribute.offset = MemoryLayout<Float>.stride * 3
                    attribute.format = .float4
                }
                $0.attributes[2].setUp { (attribute) in
                    attribute.bufferIndex = 0
                    attribute.offset = MemoryLayout<Float>.stride * 7
                    attribute.format = .float2
                }
                $0.layouts[0].stride = MemoryLayout<Float>.stride * 9
            }
            
            pipeline.fragmentFunction = fragmentFunction
            pipeline.colorAttachments[0].pixelFormat = pixelFormats.color
            pipeline.depthAttachmentPixelFormat = pixelFormats.depth
        }
        
        let depthStencilStateDescriptor = MTLDepthStencilDescriptor().set { (state) in
            state.depthCompareFunction = .less
            state.isDepthWriteEnabled = true
        }
        
        return (renderPipelineDescriptor, depthStencilStateDescriptor)
    }
    
    /// Initializes the asset from the external model
    private static func makeMeshes(device: MTLDevice, vertexDescriptor: MTLVertexDescriptor) throws -> [MTKMesh] {
        let file: (name: String, `extension`: String) = ("spot", "obj")
        guard let url = Bundle.main.url(forResource: file.name, withExtension: file.`extension`) else { throw Error.failedToFoundFile(name: "\(file.name).\(file.`extension`)") }
        
        let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor).set {
            ($0.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
            ($0.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
            ($0.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        }
        
        let asset = MDLAsset(url: url, vertexDescriptor: modelDescriptor, bufferAllocator: MTKMeshBufferAllocator(device: device))
        #if os(iOS)
        return try MTKMesh.__newMeshes(from: asset, device: device, sourceMeshes: nil)
        #else
        return try MTKMesh.newMeshes(from: asset, device: device, sourceMeshes: nil)
        #endif
    }
    
    /// Initializes a texture buffer from an external image.
    private static func makeTexture(device: MTLDevice) throws -> (texture: MTLTexture, sampler: MTLSamplerState) {
        let file: (name: String, `extension`: String) = ("spot_texture", "png")
        guard let url = Bundle.main.url(forResource: file.name, withExtension: file.`extension`) else { throw Error.failedToFoundFile(name: "\(file.name).\(file.`extension`)") }
        
        let loader = MTKTextureLoader(device: device)
        #if os(iOS)
        let texture = try loader.newTexture(URL: url, options: [.origin: MTKTextureLoader.Origin.bottomLeft, .generateMipmaps: true])
        #else
        let texture = try loader.newTexture(withContentsOf: url, options: [.origin: MTKTextureLoader.Origin.bottomLeft, .generateMipmaps: true])
        #endif
        
        let samplerDescriptor = MTLSamplerDescriptor().set {
            ($0.sAddressMode, $0.tAddressMode) = (.clampToEdge, .clampToEdge)
            ($0.minFilter, $0.magFilter, $0.mipFilter) = (.nearest, .linear, .linear)
        }
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else { throw Error.failedToCreateMetalSampler(device: device) }
        return (texture, sampler)
    }
    
    /// Updates the internal values with the passed arguments.
    private func updateUniforms(drawableSize size: float2, duration: Float) {
        self.time += duration
        self.rotationX += duration * (.𝝉 / 4.0)
        self.rotationY += duration * (.𝝉 / 6.0)
        
        let scaleFactor: Float = 1
        let xRotMatrix  = float4x4(rotate: float3(1, 0, 0), angle: self.rotationX)
        let yRotMatrix  = float4x4(rotate: float3(0, 1, 0), angle: self.rotationX)
        let scaleMatrix = float4x4(scale: scaleFactor)
        
        let modelMatrix = (xRotMatrix * yRotMatrix) * scaleMatrix
        let viewMatrix = float4x4(translate: [0, 0, -1.25])
        let projectionMatrix = float4x4(perspectiveWithAspect: size.x/size.y, fovy: .𝝉/5, near: 0.1, far: 100)
        
        let modelViewMatrix = viewMatrix * modelMatrix
        let modelViewProjectionMatrix = projectionMatrix * modelViewMatrix
        let normalMatrix: float3x3 = { (m: float4x4) in
            let x = m.columns.0.xyz
            let y = m.columns.1.xyz
            let z = m.columns.2.xyz
            return float3x3(x, y, z)
        }(modelViewMatrix)
        
        var uni = Uniforms(modelViewProjectionMatrix: modelViewProjectionMatrix, modelViewMatrix: modelViewMatrix, normalMatrix: normalMatrix)
        memcpy(uniformsBuffer.contents(), &uni, MemoryLayout<Uniforms>.size)
    }
}

