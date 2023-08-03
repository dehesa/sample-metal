import Foundation
import System

extension CommandLine {
  /// It is the similar to `CommandLine.arguments`, but it circumvents the concurrency warning.
  static var unsafeArguments: [String] {
    let numArguments = Int(Self.argc)
    let argumentsPtr = CommandLine.unsafeArgv

    var result: [String] = Array()
    result.reserveCapacity(numArguments)
    for i in 0..<numArguments {
      guard let argumentPtr = argumentsPtr[i] else { continue }
      let unsafePtr = UnsafeRawPointer(argumentPtr).assumingMemoryBound(to: UTF8.CodeUnit.self)
      result.append(String(decodingCString: unsafePtr, as: UTF8.self))
    }
    return result
  }
}

func makeFileURL(_ string: String) -> URL? {
  guard let url = URL(string: string) else { return .none }
  guard !url.isFileURL else { return url.resolvingSymlinksInPath() }

  guard url.scheme.map(\.isEmpty) ?? true else { return .none }
  let filepath = FilePath(url.absoluteString)
  return URL(filePath: filepath)?.resolvingSymlinksInPath()
}
