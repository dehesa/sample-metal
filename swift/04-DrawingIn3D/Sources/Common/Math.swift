import simd

extension float3 {
    var translationMatrix: float4x4 {
        // List of the matrix' columns
        let vectorX: float4 = [1, 0, 0, 0]
        let vectorY: float4 = [0, 1, 0, 0]
        let vectorZ: float4 = [0, 0, 1, 0]
        let vectorW: float4 = [x, y, z, 1]
        return float4x4([vectorX, vectorY, vectorZ, vectorW])
    }
    
    func rotationMatrix(withAngle angle: Float) -> float4x4 {
        let c: Float = cos(angle)
        let s: Float = sin(angle)
        let cm = 1 - c
        
        let x0 = x*x + (1-x*x)*c
        let x1 = x*y*cm - z*s
        let x2 = x*z*cm + y*s
        
        let y0 = x*y*cm + z*s
        let y1 = y*y + (1-y*y)*c
        let y2 = y*z*cm - x*s
        
        let z0 = x*z*cm - y*s
        let z1 = y*z*cm + x*s
        let z2 = z*z + (1-z*z)*c
        
        // List of the matrix' columns
        let vectorX: float4 = [x0, x1, x2, 0]
        let vectorY: float4 = [y0, y1, y2, 0]
        let vectorZ: float4 = [z0, z1, z2, 0]
        let vectorW: float4 = [ 0,  0,  0, 1]
        return float4x4([vectorX, vectorY, vectorZ, vectorW])
    }
}

extension float4x4 {
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
        self.init([vectorP, vectorQ, vectorR, vectorS])
    }
}
