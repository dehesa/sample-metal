import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = false
//: Let's inspect several types for how much space they occupy in memory
let inspection = Inspect(types:
  UInt8.self, UInt16.self, UInt32.self, UInt64.self,
  Float16.self, Float32.self, Float64.self,
  Character.self, String.self, String.UTF8View.Element.self, String.UTF16View.Element.self,
  [Int].self, Set<Int>.self
)
print(inspection.table)

//: [Play with `MTKView`s](@next)
PlaygroundPage.current.finishExecution()
