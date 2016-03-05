import Metal
import simd

struct Mesh {
	
	// MARK: Definitions
	
	typealias Vertex = ModelOBJ.Vertex
	typealias Index = ModelOBJ.Index
	
	// MARK: Properties
	
	var vertexBuffer : MTLBuffer
	var indexBuffer  : MTLBuffer
	
	// MARK: Initializer
	
	init(withOBJGroup group: ModelOBJ.Group, device: MTLDevice) {
		
	}
}
