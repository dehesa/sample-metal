import Foundation
import CoreGraphics
import Metal
import simd

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
}

/// List the generators provided by this binary.
enum Generator {
    /// Cube vertices/indices generator.
    enum Cube {
        /// Cube's point
        struct Vertex {
            var position: float4
            var normal: float4
            var texCoords: float2
        }
        /// Index to a cube's point.
        typealias Index = UInt16
        /// Possible errors throwable by the cube generator.
        enum Error: Swift.Error {
            case failedToCreateVertexBuffer(vertices: [Cube.Vertex])
            case failedToCreateIndexBuffer(indices: [Cube.Index])
        }
        /// Makes a Metal buffer given a specific cube size (in model view units).
        static func makeBuffers(device: MTLDevice, size: Float) throws -> (vertices: MTLBuffer, indices: MTLBuffer) {
            let (s, n) = (0.5 * size, Float(1.0))
            // Points
            let lbf = float4(x: -s, y: -s, z: -s, w: 1) // x: left,  y: bottom, z: front
            let lbb = float4(x: -s, y: -s, z:  s, w: 1) // x: right, y: bottom, z: back
            let ltf = float4(x: -s, y:  s, z: -s, w: 1)
            let ltb = float4(x: -s, y:  s, z:  s, w: 1)
            let rbf = float4(x:  s, y: -s, z: -s, w: 1)
            let rbb = float4(x:  s, y: -s, z:  s, w: 1)
            let rtf = float4(x:  s, y:  s, z: -s, w: 1)
            let rtb = float4(x:  s, y:  s, z:  s, w: 1)
            
            // Normals
            let mx = float4(x: -n, y:  0, z:  0, w: 0)
            let px = float4(x:  n, y:  0, z:  0, w: 0)
            let my = float4(x:  0, y: -n, z:  0, w: 0)
            let py = float4(x:  0, y:  n, z:  0, w: 0)
            let mz = float4(x:  0, y:  0, z: -n, w: 0)
            let pz = float4(x:  0, y:  0, z:  n, w: 0)
            
            // Textures
            let lt = float2(x: 0, y: 0) // u: left,  v: top
            let lb = float2(x: 0, y: 1) // u: left,  v: bottom
            let rt = float2(x: 1, y: 0) // u: right, v: top
            let rb = float2(x: 1, y: 1) // u: right, v: bottom
            
            let vertices: [Vertex] = [
                // -X
                Vertex(position: lbf, normal: mx, texCoords: lt),
                Vertex(position: lbb, normal: mx, texCoords: lb),
                Vertex(position: ltb, normal: mx, texCoords: rb),
                Vertex(position: ltf, normal: mx, texCoords: rt),
                // +X
                Vertex(position: rbb, normal: px, texCoords: lt),
                Vertex(position: rbf, normal: px, texCoords: lb),
                Vertex(position: rtf, normal: px, texCoords: rb),
                Vertex(position: rtb, normal: px, texCoords: rt),
                // -Y
                Vertex(position: lbf, normal: my, texCoords: lt),
                Vertex(position: rbf, normal: my, texCoords: lb),
                Vertex(position: rbb, normal: my, texCoords: rb),
                Vertex(position: lbb, normal: my, texCoords: rt),
                // +Y
                Vertex(position: ltb, normal: py, texCoords: lt),
                Vertex(position: rtb, normal: py, texCoords: lb),
                Vertex(position: rtf, normal: py, texCoords: rb),
                Vertex(position: ltf, normal: py, texCoords: rt),
                // -Z
                Vertex(position: rbf, normal: mz, texCoords: lt),
                Vertex(position: lbf, normal: mz, texCoords: lb),
                Vertex(position: ltf, normal: mz, texCoords: rb),
                Vertex(position: rtf, normal: mz, texCoords: rt),
                // +Z
                Vertex(position: lbb, normal: pz, texCoords: lt),
                Vertex(position: rbb, normal: pz, texCoords: lb),
                Vertex(position: rtb, normal: pz, texCoords: rb),
                Vertex(position: ltb, normal: pz, texCoords: rt)
            ]
            
            guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride) else {
                throw Error.failedToCreateVertexBuffer(vertices: vertices)
            }
            
            let indices: [Index] = [
                3,   1,  2,  0,  1,  3,
                7,   5,  6,  4,  5,  7,
                11,  9, 10,  8,  9, 11,
                15, 13, 14, 12, 13, 15,
                19, 17, 18, 16, 17, 19,
                23, 21, 22, 20, 21, 23,
            ]
            
            guard let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<Index>.stride) else {
                throw Error.failedToCreateIndexBuffer(indices: indices)
            }
            
            return (vertexBuffer, indexBuffer)
        }
    }
    
    /// Checkboard texture generators.
    enum Texture {
        /// List possible errors when generating textures
        enum Error: Swift.Error {
            case failedToCreateTexture(device: MTLDevice)
            case failedToCreateSampler(device: MTLDevice)
        }
        /// Generates the checkboard texture.
        static func makeCheckboard(size: CGSize, tileCount: Int, inColor: Bool, pixelFormat: MTLPixelFormat, with device: MTLDevice) throws -> MTLTexture {
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * Int(size.width)
            
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: true)
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw Error.failedToCreateTexture(device: device) }
            
            // TODO: ...
        }
        
        /// Generates the depth texture for a cube
        static func makeDepth(size: CGSize, pixelFormat: MTLPixelFormat, with device: MTLDevice) throws -> MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false).set {
                $0.usage = .renderTarget
            }
            guard let depthTexture = device.makeTexture(descriptor: descriptor) else { throw Error.failedToCreateTexture(device: device) }
            return depthTexture
        }
        
        /// Generates the samplers for the textures.
        static func makeSamplers(with device: MTLDevice) throws -> (notMip: MTLSamplerState, nearestMip: MTLSamplerState, linearMip: MTLSamplerState) {
            let descriptor = MTLSamplerDescriptor().set {
                ($0.minFilter, $0.magFilter) = (.linear, .linear)
                ($0.sAddressMode, $0.tAddressMode) = (.clampToEdge, .clampToEdge)
            }
            
            descriptor.mipFilter = .notMipmapped
            guard let notMip = device.makeSamplerState(descriptor: descriptor) else { throw Error.failedToCreateSampler(device: device) }
            
            descriptor.mipFilter = .nearest
            guard let nearest = device.makeSamplerState(descriptor: descriptor) else { throw Error.failedToCreateSampler(device: device) }
            
            descriptor.mipFilter = .linear
            guard let linear = device.makeSamplerState(descriptor: descriptor) else { throw Error.failedToCreateSampler(device: device) }
            
            return (notMip, nearest, linear)
        }
    }
}
