import Metal
import simd

struct Mesh {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    
    init(group: Model.OBJ.Group, device: MTLDevice) throws {
        guard let data = group.data else { throw Mesh.Error.emptyDataSource(group: group) }
        
        guard let vBuffer = data.vertices.withUnsafeBytes({ device.makeBuffer(bytes: $0, length: data.vertices.count, options: []) }) else { throw Mesh.Error.failedToCreateMetalBuffer(device: device) }
        self.vertexBuffer = vBuffer
        
        guard let iBuffer = data.indices.withUnsafeBytes({ device.makeBuffer(bytes: $0, length: data.indices.count, options: []) }) else { throw Mesh.Error.failedToCreateMetalBuffer(device: device) }
        self.indexBuffer = iBuffer
    }
}

extension Mesh {
    enum Error: Swift.Error {
        case emptyDataSource(group: Model.OBJ.Group)
        case failedToCreateMetalBuffer(device: MTLDevice)
    }
}
