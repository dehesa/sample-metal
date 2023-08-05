import Foundation

// 1. Retrieve the argument passed to this Command-Line tool.
let args = CommandLine.unsafeArguments

// 2. The input image path is expected as the only argument (excluding the program name).
guard args.count == 2 else {
  print("Only one argument specifying the input image is expected.")
  exit(EXIT_FAILURE)
}

guard let inputURL = makeFileURL(args[1]) else {
  print("Invalid input image URL:", args[1])
  exit(EXIT_FAILURE)
}

// 3. We will save the output directory to the desktop.
guard let desktopDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
  print("Unable to access the desktop to produce the output image")
  exit(EXIT_FAILURE)
}

do {
  // 4. Make the grayscale Metal texture from the input
  let texture = try Processor.makeGrayScaleTexture(from: inputURL)
  // 5. Transforme the grayscale texture into a Core Graphics image
  let image = try Processor.makeCGImage(texture: texture)
  // 6. Store the image in the desktop
  let outputURL = desktopDirectory.appendingPathComponent("out.png")
  try Processor.store(image: image, on: outputURL)
} catch let error {
  print("Program failed for file: \(inputURL.absoluteString)", error, separator: "\n")
  exit(EXIT_FAILURE)
}
