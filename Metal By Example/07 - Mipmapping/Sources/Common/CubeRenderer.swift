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
    
    private typealias CubeTextures = (checker: MTLTexture, vibrant: MTLTexture, depth: MTLTexture)
    private typealias CubeSamplers = (notMip: MTLSamplerState, nearestMip: MTLSamplerState, linearMip: MTLSamplerState)
}

class CubeRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let state: (render: MTLRenderPipelineState, depth: MTLDepthStencilState)
    private let buffers: (vertices: MTLBuffer, indices: MTLBuffer, uniforms: MTLBuffer)
    private let textures: CubeTextures
    private let samplers: CubeSamplers
    private var (time, rotationX, rotationY): (Float, Float, Float) = (0,0,0)
    
    var mipmapMode = MipmapMode.none
    var cameraDistance: Float = 1.0
    
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
        
        // Create buffers used in the shader
        let mesh = try Generator.Cube.makeBuffers(device: device, size: 1.0)
        guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride) else { throw Error.failedToCreateMetalBuffer(device: device) }
        mesh.vertices.label = "me.dehesa.metal.buffers.vertices"
        mesh.indices.label = "me.dehesa.metal.buffers.indices"
        uniformBuffer.label = "me.dehesa.metal.buffers.uniform"
        self.buffers = (mesh.vertices, mesh.indices, uniformBuffer)
        
        // Create the textures.
        let board: (size: CGSize, tileCount: Int) = (CGSize(width: 512, height: 512), 8)
        let checkerTexture = try Generator.Texture.makeCheckboard(size: board.size, tileCount: board.tileCount, inColor: false, with: device)
        let vibrantTexture = try Generator.Texture.makeCheckboard(size: board.size, tileCount: board.tileCount, inColor: true,  with: device)
        let depthTexture = try Generator.Texture.makeDepth(size: view.drawableSize, pixelFormat: pixelFormats.depth, with: device)
        self.textures = (checkerTexture, vibrantTexture, depthTexture)
        
        // Create the samplers
        self.samplers = try Generator.Texture.makeSamplers(with: device)
        
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

