Metal
-----

This repo contains code with examples on how to use Apple's Metal GPU APIs. Some sample code has been created entirely by [me](https://github.com/dehesa), while others have been picked from Github. The latter ones are in this repo because they have been heavily modified, not only to support the latest version of Swift, but also to add support to iOS or macOS (when applicable). Links to the source Github repos or websites are provided.

Examples on this repository support:
- Swift 4.1
- Metal 2.0
- Xcode 9.3

Listing of Xcode projects:
- [Apple's sample code](https://developer.apple.com/metal).
   They are usually in Objective-C and haven't been refreshed in some time. I have migrated them to the latest Swift and try to support both iOS and macOS.
   - [**Basic Tessellation**](https://developer.apple.com/library/content/samplecode/MetalBasicTessellation/Introduction/Intro.html).
- Command-Line samples.
   - **Detector**. Small utility to check basic parameters for all your GPUs.
   - [Safx](https://github.com/safx)'s **Gray converter [compute sample](https://github.com/safx/Metal-CommandLine-Sample-Swift)**.
- [Warren Moore](https://warrenmoore.net)'s **Metal by Example** book [sample code](https://github.com/metal-by-example/sample-code).
   I've migrated most chapters to the latest Swift and I've added support to macOS.
- Leon Denise's [**Shader Exam**](https://github.com/leon196/SIGExam).
  [Leon Denise](https://twitter.com/leondenise) wrote a [tweet](https://twitter.com/leondenise/status/953716696161882114) with a typical shader exam he gives to his students on [SupInfo.com](https://rubika-edu.com).
  - [Page 1](Shader%20Exam/Sources/Common/Assets/Exam/Page1.png) shaders:
    [pass](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L7),
    [mirror](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L17), 
    [symmetry](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L24),
    [rotation](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L32),
    [zoom](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L50),
    [zoomDistortion](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L59),
    [repetition](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L70), 
    [spiral](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L77), 
    [thunder](Shader%20Exam/Sources/Common/Pages/ShadersPage1.metal#L91).
  - [Page 2](Shader%20Exam/Sources/Common/Assets/Exam/Page2.png) shaders:.
  - [Page 3](Shader%20Exam/Sources/Common/Assets/Exam/Page3.png) shaders:.
  - [Page 4](Shader%20Exam/Sources/Common/Assets/Exam/Page4.png) shaders:.
  - [Page 5](Shader%20Exam/Sources/Common/Assets/Exam/Page5.png) shaders:.

### Command-Line Apps

You can run Command-Line projects from Xcode and see the result in Xcode console; however, you can also build those projects on your terminal and execute them outside execute.

1. [Clone the project](xcode://clone?repo=https://github.com/dehesa/Metal).
    ```swift
   git clone https://github.com/dehesa/Metal
   ```

2. Navigate to the _Command-Line_ source folder.
    ```
    cd "Command Line"
    ```

3. Build the project you are interested in.
   ```swift
   xcodebuild -project "$PROJECT_NAME.xcodeproj"
   ```

3. Execute the Command-Line tool from the `build/Release` folder.
    ```swift
   cd build/Release
   ./$TOOL_NAME
   ```
