import Metal
import simd
import Foundation

struct ModelOBJ {
	
	// MARK: Definitions
	
	struct Vertex {
		var position : float4
		var normal : float4
	}
	
	typealias Index = UInt16
	
	struct Group : CustomStringConvertible {
		var vertexData : NSData?
		var indexData : NSData?
	}
	
	// MARK: Properties
	
	var vertices  : [float4]
	var normals   : [float4]
	var texCoords : [float2]
	var groupVertices : [Vertex]
	var groupIndices  : [Index]
	
	// MARK: Initializer
	
	init?(withURL url: NSURL, generateNormals: Bool) {
		guard let fileString = try? String(contentsOfURL: url, encoding: NSASCIIStringEncoding) else { return nil }
		
		let scanner = NSScanner(string: fileString)
		let skipSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
		let consumeSet = skipSet.invertedSet
		let endLineSet = NSCharacterSet.newlineCharacterSet()
		scanner.charactersToBeSkipped = skipSet
		
		
		
		while !scanner.atEnd {
			scanner.scanCharactersFromSet(<#T##set: NSCharacterSet##NSCharacterSet#>, intoString: <#T##AutoreleasingUnsafeMutablePointer<NSString?>#>)
		}
		return nil
	}
	
	// Functionality
	
	func group(withName name: String) -> Group? {
		
	}
}
