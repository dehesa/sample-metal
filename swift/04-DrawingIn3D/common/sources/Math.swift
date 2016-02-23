import simd

extension float3 {
    
    public var translationMatrix : float4x4 {
        // List of the matrix' columns
        let vectorX : float4 = [1, 0, 0, 0]
        let vectorY : float4 = [0, 1, 0, 0]
        let vectorZ : float4 = [0, 0, 1, 0]
        let vectorW : float4 = [x, y, z, 1]
        return float4x4([vectorX, vectorY, vectorZ, vectorW])
    }
    
    public func rotationMatrix(withAngle angle: Float) -> float4x4 {
        let c : Float = cos(angle)
        let s : Float = sin(angle)
        
        // List of the matrix' columns
        let vectorX : float4 = [x*x + (1-x*x)*c, x*y*(1-c) - z*s, x*z*(1-c) + y*s, 0]
        let vectorY : float4 = [x*y*(1-c) + z*s, y*y + (1-y*y)*c, y*z*(1-c) - x*s, 0]
        let vectorZ : float4 = [x*z*(1-c) - y*s, y*z*(1-c) + x*s, z*z + (1-z*z)*c, 0]
        let vectorW : float4 = [0, 0, 0, 1]
        return float4x4([vectorX, vectorY, vectorZ, vectorW])
    }
}

extension float4x4 {
    
    public init(perspectiveWithAspect aspect: Float, fovy: Float, near: Float, far: Float) {
        let yScale = 1 / tan(fovy * 0.5)
        let zRange = far - near
        
        // List of the matrix' columns
        let vectorP : float4 = [yScale/aspect, 0, 0, 0]
        let vectorQ : float4 = [0, yScale, 0, 0]
        let vectorR : float4 = [0, 0, -(far+near)/zRange, -1]
        let vectorS : float4 = [0, 0, -2*far*near/zRange, 0]
        self.init([vectorP, vectorQ, vectorR, vectorS])
    }
    
}
