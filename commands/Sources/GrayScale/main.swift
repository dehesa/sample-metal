import Cocoa
import Metal
import MetalKit

// The input image path is expected as the only argument (excluding the program name).
guard CommandLine.arguments.count == 2 else {
  print("Only one argument specifying the input image is expected.")
  exit(EXIT_FAILURE)
}
let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])

// We will save the output directory to the desktop.
guard let desktopDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else { exit(EXIT_FAILURE) }
let outputURL = desktopDirectory.appendingPathComponent("out.png")

do {
  let texture = try Processor.makeGrayScaleTexture(from: inputURL)
  let image = try Processor.makeCGImage(texture: texture)
  try Processor.store(image: image, on: outputURL)
} catch let error {
  print("Program failed for file: \(inputURL)\n")
  print(error)
}
