import Metal
import MetalKit
import ModelIO
import simd

class CubeRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let state: (render: MTLRenderPipelineState, depth: MTLDepthStencilState)
    private let buffers: (vertices: MTLBuffer, indices: MTLBuffer, uniforms: MTLBuffer)
    private var textures: CubeTextures
    private let samplers: CubeSamplers
    private var angles: (x: Float, y: Float) = (0, 0)
    
    var mipmapMode = MipmapMode.none
    var cameraDistance: Float = 1.0
    
    init(view: MTKView) throws {
        // 1. Create GPU representation (MTLDevice) and Command Queue.
        guard let device = MTLCreateSystemDefaultDevice() else { throw Error.failedToCreateMetalDevice }
        guard let commandQueue = device.makeCommandQueue() else { throw Error.failedToCreateMetalCommandQueue(device: device) }
        (self.device, self.commandQueue) = (device, commandQueue)
        
        // 2. Creates the render states
        let pixelFormats: PixelFormats = (.bgra8Unorm, .depth32Float)
        let descriptors = try CubeRenderer.makeStateDescriptors(device: device, pixelFormats: pixelFormats)
        let renderPipelineState = try device.makeRenderPipelineState(descriptor: descriptors.renderPipeline)
        guard let depthStencilState = device.makeDepthStencilState(descriptor: descriptors.depthStencil) else { throw Error.failedToCreateDepthStencilState(device: device) }
        self.state = (renderPipelineState, depthStencilState)
        
        // 3. Create buffers used in the shader
        let mesh = try Generator.Cube.makeBuffers(device: device, size: 1.0)
        guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride) else { throw Error.failedToCreateMetalBuffers(device: device) }
        uniformBuffer.label = "me.dehesa.metal.buffers.uniform"
        self.buffers = (mesh.vertices, mesh.indices, uniformBuffer)
        
        // 4. Create the textures.
        let board: (size: CGSize, tileCount: Int) = (CGSize(width: 512, height: 512), 8)
        let checkerTexture = try Generator.Texture.makeSimpleCheckerboard(size: board.size, tileCount: board.tileCount, pixelFormat: pixelFormats.color, with: (device, commandQueue))
        let vibrantTexture = try Generator.Texture.makeTintedCheckerboard(size: board.size, tileCount: board.tileCount, pixelFormat: pixelFormats.color, with: device)
        let depthTexture = try Generator.Texture.makeDepth(size: view.drawableSize, pixelFormat: pixelFormats.depth, with: device)
        self.textures = (checkerTexture, vibrantTexture, depthTexture)
        
        // 5. Create the samplers
        self.samplers = try Generator.Texture.makeSamplers(with: device)
        
        // 6. Setup the MTKView.
        view.setUp {
            ($0.device, $0.clearColor) = (device, MTLClearColorMake(0, 0, 0, 1))
            ($0.colorPixelFormat, $0.depthStencilPixelFormat) = pixelFormats
        }
    }
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let depthSize = CGSize(width: textures.depth.width, height: textures.depth.height)
        guard !size.equalTo(depthSize) else { return }
        self.textures.depth = try! Generator.Texture.makeDepth(size: size, pixelFormat: view.colorPixelFormat, with: device)
    }
    
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
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
            
            encoder.setVertexBuffer(self.buffers.vertices, offset: 0, index: 0)
            encoder.setVertexBuffer(self.buffers.uniforms, offset: 0, index: 1)
            
            let fragment = self.mipmapMode.selector(textures: self.textures, samplers: self.samplers)
            encoder.setFragmentTexture(fragment.texture, index: 0)
            encoder.setFragmentSamplerState(fragment.sampler, index: 0)
            
            let indicesCount = self.buffers.indices.length / MemoryLayout<Generator.Cube.Index>.stride
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indicesCount, indexType: .uint16, indexBuffer: self.buffers.indices, indexBufferOffset: 0)
            
            encoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension CubeRenderer {
    /// Pixel formats used by the renderer.
    private typealias PixelFormats = (color: MTLPixelFormat, depth: MTLPixelFormat)
    
    /// Creates the descriptors for the render pipeline state and depth stencil state.
    /// - parameter device: Metal device where the render pipeline will be created.
    /// - parameter pixelFormats: Pixel formats for the color and depth attachments.
    /// - returns: Fully constructer render pipeline (with vertex and fragment function) and the depth state.
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
                    attribute.format = .float4
                }
                $0.attributes[1].setUp { (attribute) in
                    attribute.bufferIndex = 0
                    attribute.offset = MemoryLayout<Float>.stride * 4
                    attribute.format = .float4
                }
                $0.attributes[2].setUp { (attribute) in
                    attribute.bufferIndex = 0
                    attribute.offset = MemoryLayout<Float>.stride * 8
                    attribute.format = .float2
                }
                $0.layouts[0].setUp { (layout) in
                    layout.stride = MemoryLayout<Float>.stride * 10
                    layout.stepFunction = .perVertex
                    layout.stepRate = 1
                }
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
    
    /// Updates the internal values with the passed arguments.
    private func updateUniforms(drawableSize size: float2, duration: Float) {
        let cubePosition: float3 = [0, 0, 20]
        let modelMatrix = float4x4(translate: cubePosition) //* (float4x4(rotate: [1, 0, 0], angle: self.angles.x) * float4x4(rotate: [0, 1, 0], angle: self.angles.y))
        
        let cameraPosition: float3 = [0, 0, -1.25]
//        let cameraPosition: float3 = [0, 0, -self.cameraDistance]
        let viewMatrix = float4x4(translate: cameraPosition)
        
        let fov: Float = (size.x / size.y) > 1 ? (.𝝉/6) : (.𝝉/4)
        let projectionMatrix = float4x4(perspectiveWithAspect: size.x/size.y, fovy: fov, near: 0.1, far: 100)
        
        let modelViewMatrix = viewMatrix * modelMatrix
        let modelViewProjectionMatrix = projectionMatrix * modelViewMatrix
        let normalMatrix: float3x3 = { (m: float4x4) in
            let x = m.columns.0.xyz
            let y = m.columns.1.xyz
            let z = m.columns.2.xyz
            return float3x3(x, y, z)
        }(modelViewMatrix)
        
        let ptr = self.buffers.uniforms.contents().assumingMemoryBound(to: Uniforms.self)
        ptr.pointee = Uniforms(modelMatrix: modelMatrix, modelViewProjectionMatrix: modelViewProjectionMatrix, normalMatrix: normalMatrix.inverse.transpose)
    }
}

extension CubeRenderer {
    /// The uniform buffer passed to shader.
    private struct Uniforms {
        var modelMatrix: float4x4
        var modelViewProjectionMatrix: float4x4
        var normalMatrix: float3x3
    }
    /// Types of errors generated on this renderer.
    enum Error: Swift.Error {
        case failedToCreateMetalDevice
        case failedToCreateMetalCommandQueue(device: MTLDevice)
        case failedToCreateMetalLibrary(device: MTLDevice)
        case failedToCreateShaderFunction(name: String)
        case failedToCreateDepthStencilState(device: MTLDevice)
        case failedToFoundFile(name: String)
        case failedToCreateMetalBuffers(device: MTLDevice)
    }
    /// All possible texture used by this renderer.
    fileprivate typealias CubeTextures = (checker: MTLTexture, vibrant: MTLTexture, depth: MTLTexture)
    /// All possible samplers used by this  renderer.
    fileprivate typealias CubeSamplers = (notMip: MTLSamplerState, nearestMip: MTLSamplerState, linearMip: MTLSamplerState)
    /// Enumeration for all the mipmapping options.
    enum MipmapMode: Int {
        case none = 0
        case blitGeneratedLinear
        case vibrantLinear
        case vibrantNearest
        
        var next: MipmapMode {
            let nextRawValue = (self.rawValue + 1) % (MipmapMode.last.rawValue + 1)
            return MipmapMode(rawValue: nextRawValue)!
        }
        
        private static var last: MipmapMode {
            return .vibrantNearest
        }
        
        fileprivate func selector(textures: CubeTextures, samplers: CubeSamplers) -> (texture: MTLTexture, sampler: MTLSamplerState) {
            switch self {
            case .none:                return (textures.checker, samplers.notMip)
            case .blitGeneratedLinear: return (textures.checker, samplers.linearMip)
            case .vibrantNearest:      return (textures.vibrant, samplers.nearestMip)
            case .vibrantLinear:       return (textures.vibrant, samplers.linearMip)
            }
        }
    }
}
