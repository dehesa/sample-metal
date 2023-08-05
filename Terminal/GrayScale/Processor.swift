import CoreGraphics
import MetalKit

enum Processor {
  /// Make a gray scale image Metal Texture from a file.
  static func makeGrayScaleTexture(from fileURL: URL) throws -> MTLTexture {
    // 1. Instantiate the GPU representation and the serial queue sending "jobs" to the GPU.
    guard let device = MTLCreateSystemDefaultDevice() else { throw Error.failedToCreateMetalDevice }
    guard let queue = device.makeCommandQueue() else { throw Error.failedToCreateMetalQueue(device: device.name) }
    // 2. Retrieve the metal kernel/function from the Metal library.
    let functionName = "grayscale"
    guard let library = device.makeDefaultLibrary() else { throw Error.failedToCreateMetalLibrary(device: device.name) }
    guard let kernel = library.makeFunction(name: functionName) else { throw Error.failedToCreateMetalFunction(device: device.name, function: functionName) }
    let pipelineState = try device.makeComputePipelineState(function: kernel)
    // 3. Load the input image and create/populate a Metal Texture with its content.
    let loader = MTKTextureLoader(device: device)
    let inTexture = try loader.newTexture(URL: fileURL, options: [
      .textureCPUCacheMode: MTLCPUCacheMode.writeCombined.rawValue,
      .textureUsage: MTLTextureUsage.shaderRead.rawValue
    ])
    let (width, height) = (inTexture.width, inTexture.height)
    // 4. Create the Metal Texture that will contain the gray scale image output.
    let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
    outTextureDescriptor.cpuCacheMode = .defaultCache
    outTextureDescriptor.usage = .shaderWrite
    guard let outTexture = device.makeTexture(descriptor: outTextureDescriptor) else { throw Error.failedToCreateMetalTexture(device: device.name) }
    // 5. Define the state the GPU must be in to perform the gray-scaling.
    guard let buffer = queue.makeCommandBuffer() else { throw Error.failedToCreateMetalCommandBuffer(device: device.name) }
    guard let computeEncoder = buffer.makeComputeCommandEncoder() else { throw Error.failedToCreateMetalEncoder(device: device.name) }
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setTexture(inTexture, index: 0)
    computeEncoder.setTexture(outTexture, index: 1)
    // 6. Dispatch the gray-scale kernel.
    let threadsPerThreadgroup = MTLSize(width: 32, height: 16, depth: 1)
    let numGroups = MTLSize(width: 1 + width/threadsPerThreadgroup.width, height: 1 + height/threadsPerThreadgroup.height, depth: 1)
    computeEncoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerThreadgroup)
    computeEncoder.endEncoding()
    // 7. Tell the GPU to tell the CPU when it is done.
    guard let blitEncoder = buffer.makeBlitCommandEncoder() else { throw Error.failedToCreateMetalEncoder(device: device.name) }
    blitEncoder.synchronize(resource: outTexture)
    blitEncoder.endEncoding()
    buffer.commit()
    // 8. Wait for the job to be completed.
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

  /// Save the image on the given relative URL.
  static func store(image: CGImage, on url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)

    guard let data = rep.representation(using: .png, properties: [:]) else { throw Error.failedToGeneratePNGImage }
    try data.write(to: url, options: .atomic)
  }
}

extension Processor {
  /// List of possible errors thrown my the static functions.
  enum Error: Swift.Error {
    case failedToCreateMetalDevice
    case failedToCreateMetalLibrary(device: String)
    case failedToCreateMetalFunction(device: String, function: String)
    case failedToCreateMetalTexture(device: String)

    case failedToCreateMetalQueue(device: String)
    case failedToCreateMetalCommandBuffer(device: String)
    case failedToCreateMetalEncoder(device: String)

    case failedToGeneratePNGImage
    case failedToCreateCGContext
    case failedToCreateCGImage
  }
}
