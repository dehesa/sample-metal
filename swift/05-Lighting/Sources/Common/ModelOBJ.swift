import Metal
import simd
import Foundation

struct Model {
    class OBJ {
        /// All the groups on the OBJ file.
        ///
        /// Index 0 corresponds to an unnamed group that collects all the geometry declared outside of explicit "g" statements.
        private let groups: [Group]
        
        /// Initialize an instance by parsing the given file (which is supposed to be an `.obj` file).
        /// - param url: The address indicating where the `.obj` file is located.
        /// - param generateNormals: Boolean indicating whether at the end of the file parsing process, the normals should be generated.
        init(url: URL, generateNormals: Bool) throws {
            let fileContent = try String(contentsOf: url, encoding: .ascii)
            self.groups = try OBJ.parse(file: fileContent, generatingNormals: generateNormals)
        }
        
        subscript(_ index: Int) -> Group {
            return groups[index]
        }
        
        /// Retrieve a group identified by its name.
        /// - returns: Optional value with the target group if it is there.
        subscript(name name: String) -> Group {
            return self.group(name: name)!
        }
        
        /// Retrieve a group identified by its name.
        /// - returns: Optional value with the target group if it is there.
        func group(name: String) -> Group? {
            for group in self.groups {
                guard group.name == name else { continue }
                return group
            }
            return nil
        }
    }
}

extension Model.OBJ {
    struct Vertex {
        let position: float4
        let normal: float4
    }
    
    typealias Index = UInt16
    
    struct Group {
        let name: String
        var data: (vertices: Data, indices: Data)?
    }
    
    struct Uniform {
        struct Matrices {
            let modelViewProjection: float4x4
            let modelView: float4x4
            let normal: float4x4
        }
    }
    
    enum Error: Swift.Error {
        case parsingLine(String)
        case parsingGroup
        case parsingVertex
    }
}

extension Model.OBJ {
    private struct FaceVertex: Comparable {
        var (vi, ti, ni): (UInt16, UInt16, UInt16)
        
        static func ==(lhs: FaceVertex, rhs: FaceVertex) -> Bool {
            return (lhs.vi == rhs.vi) && (lhs.ti == rhs.ti) && (lhs.ni == rhs.ni)
        }
        
        static func <(lhs: FaceVertex, rhs: FaceVertex) -> Bool {
            guard lhs.vi == rhs.vi else { return lhs.vi < rhs.vi }
            guard lhs.ti == rhs.ti else { return lhs.ti < rhs.ti }
            guard lhs.ni == rhs.ni else { return lhs.ni < rhs.ni }
            return false
        }
    }
    
    private class TemporaryGroup {
        var name: String
        var vertices: [float4] = []
        var normals: [float4] = []
        var texCoords: [float2] = []
        var groupVertices: [Vertex] = []
        var groupIndices: [Index] = []
        var vertexToGroupIndex: [FaceVertex:Index] = [:]
        
        init(name: String = "(unnamed)") {
            self.name = name
            self.vertices.reserveCapacity(512)
            self.normals.reserveCapacity(512)
            self.texCoords.reserveCapacity(512)
            self.groupVertices.reserveCapacity(512)
            self.groupIndices.reserveCapacity(512)
        }
        
        func reset(with name: String) {
            self.name = name
            self.vertices.removeAll()
            self.normals.removeAll()
            self.texCoords.removeAll()
            self.groupVertices.removeAll()
            self.groupIndices.removeAll()
        }
    }
    
    private static func parse(file: String, generatingNormals: Bool) throws -> [Group] {
        var result: [Group] = []
        
        let scanner = Scanner(string: file).set { $0.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines }
        let consumeSet = CharacterSet.whitespacesAndNewlines.inverted
        
        let tmp = TemporaryGroup()
        while scanner.isAtEnd == false {
            var charsScanned: NSString?
            guard scanner.scanCharacters(from: consumeSet, into: &charsScanned) == true else { break }
            guard let token = charsScanned else { continue }
            
            switch token {
            case "v":
                var (x, y, z): (Float, Float, Float) = (0, 0, 0)
                let isValidScan = scanner.scanFloat(&x) && scanner.scanFloat(&y) && scanner.scanFloat(&z)
                guard isValidScan else { throw Error.parsingVertex }
                tmp.vertices.append(float4(x, y, z, 1))
            case "vt":
                var (u, v): (Float, Float) = (0, 0)
                scanner.scanFloat(&u)
                scanner.scanFloat(&v)
                tmp.texCoords.append(float2(u, v))
            case "vn":
                var (nx, ny, nz): (Float, Float, Float) = (0, 0, 0)
                scanner.scanFloat(&nx)
                scanner.scanFloat(&ny)
                scanner.scanFloat(&nz)
                tmp.normals.append(float4(nx, ny, nz, 0))
            case "f":
                var faceVertices: [FaceVertex] = []
                faceVertices.reserveCapacity(4)
                
                while(true) {
                    var (vi, ti, ni): (Int32, Int32, Int32) = (0, 0, 0)
                    guard scanner.scanInt32(&vi) else { break }
                    
                    if (scanner.scanString("/", into: nil)) {
                        scanner.scanInt32(&ti)
                        if (scanner.scanString("/", into: nil)) {
                            scanner.scanInt32(&ni)
                        }
                    }
                    
                    // OBJ format allows relative vertex references in the form of negative indices, and dictates that indices are 1-based. Below, we simultaneously fix up negative indices and offset everything by -1 to allow 0-based indexing later on.
                    let faceVertex = FaceVertex(
                        vi: (vi < 0) ? UInt16(Int32(tmp.vertices.count) + vi - 1) : UInt16(vi - 1),
                        ti: (ti < 0) ? UInt16(Int32(tmp.texCoords.count) + ti - 1) : UInt16(ti - 1),
                        ni: (ni < 0) ? UInt16(Int32(tmp.vertices.count) + ni - 1) : UInt16(ni - 1))
                    faceVertices.append(faceVertex)
                }
                
                // Transform polygonal faces into "fans" of triangles, three vertices at a time
                for i in 0..<(faceVertices.count - 2) {
                    for fv in [faceVertices[0], faceVertices[i+1], faceVertices[i+2]] {
                        let up = float4(0, 1, 0, 0)
                        let invalidIndex = UInt16(0xFFFF)
                        
                        
                    }
                }
            case "g":
                var groupName: NSString?
                guard scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &groupName),
                      let name = groupName as String? else { throw Error.parsingGroup }
                
                result.append(try process(parsedGroup: tmp, generateNormals: generatingNormals))
                tmp.reset(with: name)
            default:
                throw Error.parsingLine(token as String)
            }
        }
        
        result.append(try process(parsedGroup: tmp, generateNormals: generatingNormals))
        return result
    }
    
    private static func process(parsedGroup group: TemporaryGroup, generateNormals: Bool) throws -> Group {
        if generateNormals {
            
        }
    }
}

extension Model.OBJ.Group: CustomStringConvertible {
    var description: String {
        var num: (vertices: Int, indices: Int) = (0, 0)
        if let data = self.data {
            num.vertices = data.vertices.count / MemoryLayout<Model.OBJ.Vertex>.stride
            num.indices  = data.indices.count  / MemoryLayout<Model.OBJ.Index>.stride
        }
        return "<Group: \(self.name) - \(num.vertices) vertices, \(num.indices) indices>"
    }
}
