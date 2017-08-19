import Cocoa
import Metal
import MetalKit

if CommandLine.arguments.count >= 2 {
    let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])
    
    do {
        let texture = try Processor.makeGrayScaleTexture(from: fileURL)
        let image = try Processor.makeCGImage(texture: texture)
        try Processor.store(image: image, on: URL(fileURLWithPath: "out.png"))
    } catch let error {
        print("Program failed for file: \(fileURL)\n")
        print(error)
    }
}
