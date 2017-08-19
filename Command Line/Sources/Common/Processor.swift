import Cocoa
import Metal
import MetalKit

enum Processor {
    /// Make a gray scale image Metal Texture from a file.
    static func makeGrayScaleTexture(from fileURL: URL) throws -> MTLTexture {
        // Create the *non-transient* metal objects.
        guard let device = MTLCreateSystemDefaultDevice() else { throw Error.failedToCreateMetalDevice }
        guard let queue = device.makeCommandQueue() else { throw Error.failedToCreateMetalQueue(device: device) }
        
        let functionName = "grayscale"
        guard let library = device.makeDefaultLibrary() else { throw Error.failedToCreateMetalLibrary(device: device) }
        guard let kernel = library.makeFunction(name: functionName) else { throw Error.failedToCreateMetalFunction(device: device, name: functionName) }
        let pipelineState = try device.makeComputePipelineState(function: kernel)
        
        let loader = MTKTextureLoader(device: device)
        let inTexture = try loader.newTexture(withContentsOf: fileURL, options: nil)
        let (width, height) = (inTexture.width, inTexture.height)
        
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        guard let outTexture = device.makeTexture(descriptor: outTextureDescriptor) else { throw Error.failedToCreateMetalTexture(device: device, descriptor: outTextureDescriptor) }
        
        // Create the *transient* metal objects.
        guard let buffer = queue.makeCommandBuffer() else { throw Error.failedToCreateMetalCommandBuffer(device: device) }
        
        guard let computeEncoder = buffer.makeComputeCommandEncoder() else { throw Error.failedToCreateMetalEncoder(device: device) }
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inTexture, index: 0)
        computeEncoder.setTexture(outTexture, index: 1)
        
        let threadsPerThreadgroup = MTLSize(width: 32, height: 16, depth: 1)
        let numGroups = MTLSize(width: 1 + width/threadsPerThreadgroup.width, height: 1 + height/threadsPerThreadgroup.height, depth: 1)
        computeEncoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        guard let blitEncoder = buffer.makeBlitCommandEncoder() else { throw Error.failedToCreateMetalEncoder(device: device) }
        blitEncoder.synchronize(resource: outTexture)
        blitEncoder.endEncoding()
        
        buffer.commit()
        buffer.waitUntilCompleted()
        
        if let error = buffer.error { throw error }
        return outTexture
    }
    
    /// Creates a Core Graphic Image from the given metal texture.
    static func makeCGImage(texture: MTLTexture) throws -> CGImage {
        let (width, height) = (texture.width, texture.height)
        let rowBytes = width * 4
        
        var buf = Array<UInt8>(repeating: 0, count: rowBytes*height)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(&buf, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &buf, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Error.failedToCreateCGContext }
        guard let result = context.makeImage() else { throw Error.failedToCreateCGImage }
        return result
    }
    
    /// Save the image on the passed relative URL.
    static func store(image: CGImage, on url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = NSSize(width: image.width, height: image.height)
        
        guard let data = rep.representation(using: .png, properties: [:]) else { throw Error.failedToGeneratePNGImage(representation: rep) }
        try data.write(to: url, options: .atomic)
    }
}

extension Processor {
    /// List of possible errors thrown my the static functions.
    enum Error: Swift.Error {
        case failedToCreateMetalDevice
        case failedToCreateMetalLibrary(device: MTLDevice)
        case failedToCreateMetalFunction(device: MTLDevice, name: String)
        case failedToCreateMetalTexture(device: MTLDevice, descriptor: MTLTextureDescriptor)
        
        case failedToCreateMetalQueue(device: MTLDevice)
        case failedToCreateMetalCommandBuffer(device: MTLDevice)
        case failedToCreateMetalEncoder(device: MTLDevice)
        
        case failedToGeneratePNGImage(representation: NSBitmapImageRep)
        case failedToCreateCGContext
        case failedToCreateCGImage
    }
}
