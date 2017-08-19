Metal
-----

This repo contains code with examples on how to use Apple's Metal GPU APIs:
- [Warren Moore](https://warrenmoore.net)'s _Metal by Example_ book [sample code](https://github.com/metal-by-example/sample-code) (migrated to Swift and MetalKit by [me](https://github.com/dehesa)).
- [Safx](https://github.com/safx)'s Command-Line [example](https://github.com/safx/Metal-CommandLine-Sample-Swift) (migrated to the newest Swift version by [me](https://github.com/dehesa)).

Most examples on this repository support:
- macOS and iOS platforms.
- Swift 4.0
- Metal 2.0

### Command-Line

To use the command-line tool, you need to:

1. Clone the project
   ```swift
   git clone https://github.com/dehesa/Metal.git
   ```

2. Build the _Command Line_ project
   ```swift
   cd "Command Line"
   xcodebuild -project "Command Line.xcodeproj"
   ```

3. Execute the Command-Line tool
   ```swift
   cd build/Release
   ./MetalCLI /absolute/path/to/image.jpg
   ```