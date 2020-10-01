import Foundation
import CoreGraphics
import Metal
import simd

/// List the generators provided by this binary.
enum Generator {
    /// Cube vertices/indices generator.
    enum Cube {
        /// Cube's point
        struct Vertex {
            var position: SIMD4<Float>
            var normal: SIMD4<Float>
            var texCoords: SIMD2<Float>
        }
        /// Index to a cube's point.
        typealias Index = UInt16
        /// Possible errors throwable by the cube generator.
        enum Error: Swift.Error {
            case failedToCreateVertexBuffer(vertices: [Cube.Vertex])
            case failedToCreateIndexBuffer(indices: [Cube.Index])
        }
        /// Makes a Metal buffer given a specific cube size (in model view units).
        /// - parameter device: Metal device where the buffers will be stored.
        /// - parameter size: Side square size.
        /// - Vertex & Index buffer for a perfect square.
        static func makeBuffers(device: MTLDevice, size: Float) throws -> (vertices: MTLBuffer, indices: MTLBuffer) {
            /// Half side and normal to be used as coordinates.
            let (s, n): (Float, Float) = (0.5*size, 1)
            // Points
            let lbf = SIMD4<Float>(x: -s, y: -s, z: -s, w: 1) // x: left,  y: bottom, z: front
            let lbb = SIMD4<Float>(x: -s, y: -s, z:  s, w: 1) // x: right, y: bottom, z: back
            let ltf = SIMD4<Float>(x: -s, y:  s, z: -s, w: 1)
            let ltb = SIMD4<Float>(x: -s, y:  s, z:  s, w: 1)
            let rbf = SIMD4<Float>(x:  s, y: -s, z: -s, w: 1)
            let rbb = SIMD4<Float>(x:  s, y: -s, z:  s, w: 1)
            let rtf = SIMD4<Float>(x:  s, y:  s, z: -s, w: 1)
            let rtb = SIMD4<Float>(x:  s, y:  s, z:  s, w: 1)
            
            // Normals
            let nx = SIMD4<Float>(x: -n, y:  0, z:  0, w: 0)
            let px = SIMD4<Float>(x:  n, y:  0, z:  0, w: 0)
            let ny = SIMD4<Float>(x:  0, y: -n, z:  0, w: 0)
            let py = SIMD4<Float>(x:  0, y:  n, z:  0, w: 0)
            let nz = SIMD4<Float>(x:  0, y:  0, z: -n, w: 0)
            let pz = SIMD4<Float>(x:  0, y:  0, z:  n, w: 0)
            
            // Textures
            let lt = SIMD2<Float>(x: 0, y: 0) // u: left,  v: top
            let lb = SIMD2<Float>(x: 0, y: 1) // u: left,  v: bottom
            let rt = SIMD2<Float>(x: 1, y: 0) // u: right, v: top
            let rb = SIMD2<Float>(x: 1, y: 1) // u: right, v: bottom
            
            let vertices: [Vertex] = [
                // -X
                Vertex(position: lbf, normal: nx, texCoords: lt),
                Vertex(position: lbb, normal: nx, texCoords: lb),
                Vertex(position: ltb, normal: nx, texCoords: rb),
                Vertex(position: ltf, normal: nx, texCoords: rt),
                // +X
                Vertex(position: rbb, normal: px, texCoords: lt),
                Vertex(position: rbf, normal: px, texCoords: lb),
                Vertex(position: rtf, normal: px, texCoords: rb),
                Vertex(position: rtb, normal: px, texCoords: rt),
                // -Y
                Vertex(position: lbf, normal: ny, texCoords: lt),
                Vertex(position: rbf, normal: ny, texCoords: lb),
                Vertex(position: rbb, normal: ny, texCoords: rb),
                Vertex(position: lbb, normal: ny, texCoords: rt),
                // +Y
                Vertex(position: ltb, normal: py, texCoords: lt),
                Vertex(position: rtb, normal: py, texCoords: lb),
                Vertex(position: rtf, normal: py, texCoords: rb),
                Vertex(position: ltf, normal: py, texCoords: rt),
                // -Z
                Vertex(position: rbf, normal: nz, texCoords: lt),
                Vertex(position: lbf, normal: nz, texCoords: lb),
                Vertex(position: ltf, normal: nz, texCoords: rb),
                Vertex(position: rtf, normal: nz, texCoords: rt),
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
            
            vertexBuffer.label = "io.dehesa.metal.buffers.vertices"
            indexBuffer.label = "io.dehesa.metal.buffers.indices"
            return (vertexBuffer, indexBuffer)
        }
    }
    
    /// Checkboard texture generators.
    enum Texture {
        private static let bytesPerPixel = 4
        
        /// List possible errors when generating textures
        enum Error: Swift.Error {
            case failedToCreateTexture(device: MTLDevice)
            case failedToCreateSampler(device: MTLDevice)
            case failedToCreateCheckerboard(size: CGSize, tileCount: Int)
            case failedtoCreateResizedCheckboard(size: CGSize)
        }
        
        /// Generates the black & white checkboard texture.
        static func makeSimpleCheckerboard(size: CGSize, tileCount: Int, pixelFormat: MTLPixelFormat, with metal: (device: MTLDevice, queue: MTLCommandQueue)) throws -> MTLTexture {
            let bytesPerRow = bytesPerPixel * Int(size.width)
            
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: true)
            guard let texture = metal.device.makeTexture(descriptor: descriptor) else { throw Error.failedToCreateTexture(device: metal.device) }
            
            (try makeCheckerboardImage(size: size, tileCount: tileCount)).data.withUnsafeBytes { (ptr) in
                let region = MTLRegionMake2D(0, 0, Int(size.width), Int(size.height))
                texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
            }
            
            guard let buffer = metal.queue.makeCommandBuffer(),
                let encoder = buffer.makeBlitCommandEncoder() else { throw Error.failedToCreateTexture(device: metal.device) }
            encoder.generateMipmaps(for: texture)
            encoder.endEncoding()
            
            return texture
        }
        
        /// Generates the tinted checkboard texture.
        static func makeTintedCheckerboard(size: CGSize, tileCount: Int, pixelFormat: MTLPixelFormat, with device: MTLDevice) throws -> MTLTexture {
            let bytesPerRow = bytesPerPixel * Int(size.width)
            
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: true)
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw Error.failedToCreateTexture(device: device) }
            
            let (data, image) = try makeCheckerboardImage(size: size, tileCount: tileCount)
            data.withUnsafeBytes { (ptr) in
                let region = MTLRegionMake2D(0, 0, Int(size.width), Int(size.height))
                texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
            }
            
            var (level, mipWidth, mipHeight, levelImage) = (1, texture.width/2, texture.height/2, image)
            while mipWidth > 1 && mipHeight > 1 {
                let mipBytesPerRow = bytesPerPixel * mipWidth
                let tintColor = makeTintColor(level: level - 1)
                
                let scaled = try makeResizeImage(image: levelImage, size: CGSize(width: mipWidth, height: mipHeight), tintColor: tintColor)
                levelImage = scaled.image
                
                scaled.data.withUnsafeBytes { (ptr) in
                    let region = MTLRegionMake2D(0, 0, mipWidth, mipHeight)
                    texture.replace(region: region, mipmapLevel: level, withBytes: ptr.baseAddress!, bytesPerRow: mipBytesPerRow)
                }
                
                mipWidth /= 2
                mipHeight /= 2
                level += 1
            }
            
            return texture
        }
        
        /// Generates the depth texture for a cube
        static func makeDepth(size: CGSize, pixelFormat: MTLPixelFormat, with device: MTLDevice) throws -> MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false).set {
                $0.usage = .renderTarget
                $0.storageMode = .`private`
                
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

extension Generator.Texture {
    /// Returns a tintColor depending on the mip level.
    private static func makeTintColor(level: Int) -> CGColor {
        switch level {
        case 0:  return CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1) // red
        case 1:  return CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1) // orange
        case 2:  return CGColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1) // yellow
        case 3:  return CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1) // green
        case 4:  return CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1) // blue
        case 5:  return CGColor(red: 0.5, green: 0.0, blue: 1.0, alpha: 1) // indigo
        default: return CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1) // purple
        }
    }
    
    /// Returns an array of bytes with the data of the checkboard image (and as a convenience a `CGImage` of that bytes array.
    private static func makeCheckerboardImage(size: CGSize, tileCount: Int) throws -> (data: Data, image: CGImage) {
        let (width, height) = (Int(size.width), Int(size.height))
        guard width  % tileCount == 0,
              height % tileCount == 0 else { throw Error.failedToCreateCheckerboard(size: size, tileCount: tileCount) }
        
        let bytes: (count: Int, alignment: Int) = (bytesPerPixel * width * height, MemoryLayout<UInt8>.alignment)
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: bytes.alignment)
        
        let (colorSpace, bitmapInfo) = (CGColorSpaceCreateDeviceRGB(), CGImageAlphaInfo.premultipliedLast.rawValue | CGImageByteOrderInfo.order32Big.rawValue)
        guard let context = CGContext(data: ptr, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerPixel*width, space: colorSpace, bitmapInfo: bitmapInfo) else { throw Error.failedToCreateCheckerboard(size: size, tileCount: tileCount) }
        
        let values: (light: CGFloat, dark: CGFloat) = (0.95, 0.15)
        let tile: (width: Int, height: Int) = (width / tileCount, height / tileCount)
        for row in 0..<tileCount {
            var useLightColor = (row % 2) == 0
            for column in 0..<tileCount {
                let value = (useLightColor) ? values.light : values.dark
                context.setFillColor(red: value, green: value, blue: value, alpha: 1)
                context.fill( CGRect(x: row*tile.height, y: column*tile.width, width: tile.width, height: tile.height) )
                useLightColor = !useLightColor
            }
        }
        
        guard let image = context.makeImage() else { throw Error.failedToCreateCheckerboard(size: size, tileCount: tileCount) }
        let data = Data(bytesNoCopy: ptr, count: bytes.count, deallocator: .custom { (p, _) in p.deallocate() })
        return (data, image)
    }
    
    /// Resizes an image and blends the tint color on the blackened squares.
    private static func makeResizeImage(image: CGImage, size: CGSize, tintColor: CGColor) throws -> (data: Data, image: CGImage) {
        let (width, height) = (Int(size.width), Int(size.height))
        
        let bytes: (count: Int, alignment: Int) = (bytesPerPixel * width * height, MemoryLayout<UInt8>.alignment)
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: bytes.alignment)
        
        let (colorSpace, bitmapInfo) = (CGColorSpaceCreateDeviceRGB(), CGImageAlphaInfo.premultipliedLast.rawValue | CGImageByteOrderInfo.order32Big.rawValue)
        guard let context = CGContext(data: ptr, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerPixel*width, space: colorSpace, bitmapInfo: bitmapInfo) else { throw Error.failedtoCreateResizedCheckboard(size: size) }
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        
        guard let image = context.makeImage() else { throw Error.failedtoCreateResizedCheckboard(size: size) }
        
        guard let components = tintColor.components else { throw Error.failedtoCreateResizedCheckboard(size: size) }
        context.setFillColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        context.setBlendMode(.multiply)
        context.fill(rect)
        
        let data = Data(bytesNoCopy: ptr, count: bytes.count, deallocator: .custom { (p, _) in p.deallocate() })
        return (data, image)
    }
}
