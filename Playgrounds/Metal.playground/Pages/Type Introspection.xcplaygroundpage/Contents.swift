import PlaygroundSupport

let page: PlaygroundPage = .current
 page.needsIndefiniteExecution = false
//: ----
//: Let's inspect several types to figure out how much space do they occupy in memory
Inspect(types:
  UInt8.self,
  UInt16.self,
  UInt32.self,
  UInt64.self,
  Float16.self,
  Float32.self,
  Float64.self,
  Character.self,
  String.self,
  String.UTF8View.Element.self,
  String.UTF16View.Element.self,
  [Int].self,
  Set<Int>.self
).table
//: ----
//: [Play with `MTKView`s](@next)
page.finishExecution()
