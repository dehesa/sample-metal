import PlaygroundSupport

public struct Inspect: CustomPlaygroundDisplayConvertible {
  private var info: [Info] = []

  public init<each T>(types: repeat (each T).Type) {
    repeat _aggregate(_introspect(type: (each T).self), into: &self.info)
  }

  public init<each T>(values: repeat each T) {
    self.init(types: repeat (each T).self)
  }

  public var playgroundDescription: Any {
    self.table
  }
}

public extension Inspect {
  var table: String {
    var (rows, maxChars) = self.makeRows(titles: ("Type", "Size", "Stride", "Align"))
    rows = rows.map { row -> ParsedInfo in
      (row.name.padLeft(max: maxChars.name), row.size.pad(max: maxChars.size), row.stride.pad(max: maxChars.stride), row.alignment.pad(max: maxChars.alignment))
    }
    rows.insert((.dash(count: maxChars.name), .dash(count: maxChars.size), .dash(count: maxChars.stride), .dash(count: maxChars.alignment)), at: 1)
    return rows
      .map { "|\($0.name)|\($0.size)|\($0.stride)|\($0.alignment)|" }
      .joined(separator: "\n")
  }
}

private extension Inspect {
  func makeRows(titles: ParsedInfo) -> (rows: [ParsedInfo], maxChars: CountInfo) {
    var rows: [ParsedInfo] = [titles]
    var maxChars: CountInfo = (titles.name.count, titles.size.count, titles.stride.count, titles.alignment.count)
    for i in info {
      let row: ParsedInfo = (i.name, String(i.size), String(i.stride), String(i.alignment))
      maxChars.name = max(row.name.count, maxChars.name)
      maxChars.size = max(row.size.count, maxChars.size)
      maxChars.stride = max(row.stride.count, maxChars.stride)
      maxChars.alignment = max(row.alignment.count, maxChars.alignment)
      rows.append(row)
    }
    return (rows, maxChars)
  }
}

// MARK: -

private typealias TupleInfo<N, I> = (name: N, size: I, stride: I, alignment: I)
private typealias Info = TupleInfo<String, Int>
private typealias ParsedInfo = TupleInfo<String, String>
private typealias CountInfo = TupleInfo<Int, Int>

private func _introspect<T>(type: T.Type) -> Info {
  ("\(type)", MemoryLayout<T>.size, MemoryLayout<T>.stride, MemoryLayout<T>.alignment)
}

private func _aggregate(_ input: Info..., into output: inout [Info]) {
  output.append(contentsOf: input)
}

private extension String {
  func pad(max: Int) -> Self {
    let remain = max - self.count
    let left = remain / 2
    let right = remain - left

    var result = String()
    result.append(spaces: left)
    result.append(self)
    result.append(spaces: right)
    return result
  }

  func padLeft(max: Int) -> Self {
    var result = String()
    result.append(spaces: max - self.count)
    result.append(self)
    return result
  }

  mutating func append(spaces: Int) {
    guard spaces > .zero else { return }
    self.append(String(repeating: " ", count: spaces))
  }

  static func dash(count: Int) -> Self {
    String(repeating: "-", count: count)
  }
}
