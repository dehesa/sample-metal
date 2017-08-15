import simd
import CoreGraphics

extension Double {
    /// Number of radians in *one turn*.
    public static let 𝝉: Double = Double.pi * 2
    /// Number of radians in *half a turn*.
    public static let π: Double = Double.pi
}

extension Float {
    /// Number of radians in *one turn*.
    public static let 𝝉: Float = Float(Double.𝝉)
    /// Number of radians in *half a turn*.
    public static let π: Float = Float(Double.π)
}

extension CGSize {
    /// Transforms a `CGSize` into a vector with two numbers
    var float2: simd.float2 {
        return simd.float2(Float(self.width), Float(self.height))
    }
}

extension float4 {
    var xy: float2 {
        return float2([self.x, self.y])
    }
    
    var xyz: float3 {
        return float3([self.x, self.y, self.z])
    }
}

extension float4x4 {
    /// Creates a 4x4 matrix representing a translation given by the provided vector.
    /// - parameter vector: Vector giving the direction and magnitude of the translation.
    init(translate vector: float3) {
        // List of the matrix' columns
        let baseX: float4 = [1, 0, 0, 0]
        let baseY: float4 = [0, 1, 0, 0]
        let baseZ: float4 = [0, 0, 1, 0]
        let baseW: float4 = [vector.x, vector.y, vector.z, 1]
        self.init(baseX, baseY, baseZ, baseW)
    }
    
    /// Creates a 4x4 matrix representing a uniform scale given by the provided scalar.
    /// - parameter s: Scalar giving the uniform magnitude of the scale.
    init(scale s: Float) {
        self.init(diagonal: [s, s, s, 1])
    }
    
    /// Creates a 4x4 matrix that will rotate through the given vector and given angle.
    /// - parameter angle: The amount of radians to rotate from the given vector center.
    init(rotate vector: float3, angle: Float) {
        let c: Float = cos(angle)
        let s: Float = sin(angle)
        let cm = 1 - c
        
        let x0 = vector.x*vector.x + (1-vector.x*vector.x)*c
        let x1 = vector.x*vector.y*cm - vector.z*s
        let x2 = vector.x*vector.z*cm + vector.y*s
        
        let y0 = vector.x*vector.y*cm + vector.z*s
        let y1 = vector.y*vector.y + (1-vector.y*vector.y)*c
        let y2 = vector.y*vector.z*cm - vector.x*s
        
        let z0 = vector.x*vector.z*cm - vector.y*s
        let z1 = vector.y*vector.z*cm + vector.x*s
        let z2 = vector.z*vector.z + (1-vector.z*vector.z)*c
        
        // List of the matrix' columns
        let baseX: float4 = [x0, x1, x2, 0]
        let baseY: float4 = [y0, y1, y2, 0]
        let baseZ: float4 = [z0, z1, z2, 0]
        let baseW: float4 = [ 0,  0,  0, 1]
        self.init(baseX, baseY, baseZ, baseW)
    }
    
    /// Creates a perspective matrix from an aspect ratio, field of view, and near/far Z planes.
    init(perspectiveWithAspect aspect: Float, fovy: Float, near: Float, far: Float) {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        // List of the matrix' columns
        let vectorP: float4 = [xScale,      0,       0,  0]
        let vectorQ: float4 = [     0, yScale,       0,  0]
        let vectorR: float4 = [     0,      0,  zScale, -1]
        let vectorS: float4 = [     0,      0, wzScale,  0]
        self.init(vectorP, vectorQ, vectorR, vectorS)
    }
}
