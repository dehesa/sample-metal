import Foundation
import MetalKit

enum Loader {
    /// Loads Pikachu's mesh and texture (on their appropriate formats).
    /// - parameter device: Metal device where the mesh buffer and texture will stay.
    static func loadPikachu(to device: MTLDevice) -> (MTKMesh, MTLVertexDescriptor, MTLTexture) {
        // Load the model (through Model I/O).
        guard let modelURL = Bundle.main.url(forResource: "pikachu", withExtension: "obj") else { fatalError("The \"pikachu.obj\" model couldn't be found.") }
        let mdlBufferAllocator = MTKMeshBufferAllocator(device: device)
        let mdlVertexDescriptor = MDLVertexDescriptor().set {
            $0.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
            $0.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: 12, bufferIndex: 0)
            $0.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: 24, bufferIndex: 0)
            $0.layouts[0] = MDLVertexBufferLayout(stride: 32)
        }
        let mdlAsset = MDLAsset(url: modelURL, vertexDescriptor: mdlVertexDescriptor, bufferAllocator: mdlBufferAllocator)
        
        // Initialize the targeted Mesh.
        guard let mdlFirstMesh = mdlAsset.childObjects(of: MDLMesh.self).first as? MDLMesh,
            let resultMesh = try? MTKMesh(mesh: mdlFirstMesh, device: device) else {
                fatalError("MetalKit couldn't be initialized for the Pikachu model.")
        }
        
        // Transform the Model I/O Vertex Descriptor to Metal Vertex Descriptor.
        guard let resultDescriptor = MTKMetalVertexDescriptorFromModelIO(mdlVertexDescriptor) else {
            fatalError("Couldn't transform Model I/O Vertex Descriptor to a Metal Vertex Descriptor.")
        }
        
        // Load the texture.
        guard let textureURL = Bundle.main.url(forResource: "pikachu", withExtension: "png") else { fatalError("The \"pikachu.png\" texture couldn't be found.") }
        let textureLoader = MTKTextureLoader(device: device)
        guard let resultTexture = try? textureLoader.newTexture(URL: textureURL, options: [.SRGB: false, .origin: MTKTextureLoader.Origin.flippedVertically]) else {
            fatalError("MetalKit couldn't load Pikachu's texture.")
        }
        
        return (resultMesh, resultDescriptor, resultTexture)
    }
    
    /// Loads shader files from the given URL; or, in their absence, loads the default library.
    /// - parameter device: Metal device for which the library will be compiled to.
    /// - parameter shadersURLs: Location where the shaders are located. If `nil`, the `defaultLibrary` is used instead.
    static func loadLibrary(to device: MTLDevice, from shadersURLs: (mainShader: URL, quadShader: URL)? = nil) -> MTLLibrary {
        guard let urls = shadersURLs else {
            return device.makeDefaultLibrary()!
        }
        
        guard let mainShader = try? String(contentsOf: urls.mainShader),
              let quadShader = try? String(contentsOf: urls.quadShader) else {
                fatalError("Shaders couldn't be loaded\n\tmain: \(urls.mainShader)\n\tquad: \(urls.quadShader)")
        }
        
        let source = mainShader + "\n" + quadShader
        guard let library = try? device.makeLibrary(source: source, options: nil) else {
            fatalError("Couldn't compile Metal library from shader files:\n\tmain: \(urls.mainShader)\n\tquad: \(urls.quadShader)")
        }
        
        return library
    }

    /// Make the two render states from the shaders on the given library.
    /// - parameter device: Metal device that will run the two render state.
    /// - parameter library: Metal library containing the shader functions.
    /// - parameter meshDescriptor: Vertex descriptor for the render model.
    /// - parameter view: View that will display the render output.
    static func makeRenderStates(for device: MTLDevice, library: MTLLibrary, meshDescriptor: MTLVertexDescriptor, view: MTKView) -> (main: MTLRenderPipelineState, post: MTLRenderPipelineState) {
        let mainDescriptor = MTLRenderPipelineDescriptor().set {
            $0.colorAttachments[0].pixelFormat = .rgba8Unorm
            $0.depthAttachmentPixelFormat = .depth32Float
            $0.vertexDescriptor = meshDescriptor
            $0.vertexFunction = library.makeFunction(name: "vertex_main")
            $0.fragmentFunction = library.makeFunction(name: "fragment_main")
        }
        
        let postDescriptor = MTLRenderPipelineDescriptor().set {
            $0.colorAttachments[0].pixelFormat = view.colorPixelFormat
            $0.vertexDescriptor = MTLVertexDescriptor().set { (vertex) in
                vertex.attributes[0].setUp { (attribute) in
                    attribute.format = .float2
                    attribute.offset = 0
                    attribute.bufferIndex = 0
                }
                vertex.attributes[1].setUp { (attribute) in
                    attribute.format = .float2
                    attribute.offset = 0
                    attribute.bufferIndex = 0
                }
                vertex.layouts[0].stride = 16
            }
            $0.vertexFunction = library.makeFunction(name: "vertex_post")
            $0.fragmentFunction = library.makeFunction(name: "fragment_post")
        }
        
        guard let mainState = try? device.makeRenderPipelineState(descriptor: mainDescriptor),
              let postState = try? device.makeRenderPipelineState(descriptor: postDescriptor) else {
                fatalError("Render state couldn't be built.")
        }
        
        return (mainState, postState)
    }
    
    /// Generates the two offscreen textures (render and depth) used by the two main passes.
    /// - parameter device: Metal device running the render passes.
    /// - parameter size: The size the texture needs to have.
    static func makeOffScreenTargets(for device: MTLDevice, size: CGSize) -> (color: MTLTexture, depth: MTLTexture) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .invalid, width: Int(size.width), height: Int(size.height), mipmapped: false)
        
        guard let colorTarget = device.makeTexture(descriptor: descriptor.set {
            $0.pixelFormat = .rgba8Unorm
            $0.usage = [.shaderRead, .renderTarget]
            $0.storageMode = .managed
        }) else { fatalError("Color target couldn't be build for: \(size)") }
        
        guard let depthTarget = device.makeTexture(descriptor: descriptor.set {
            $0.pixelFormat = .depth32Float
            $0.usage = .renderTarget
            $0.storageMode = .private
        }) else { fatalError("Depth target couldn't be build for: \(size)") }
        
        return (colorTarget, depthTarget)
    }
}
