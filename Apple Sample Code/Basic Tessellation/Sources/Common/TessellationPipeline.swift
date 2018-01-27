import Foundation
import Metal
import MetalKit

class TessellationPipeline: NSObject, MTKViewDelegate {
    /// The type of tessellation patch being rendered.
    var patchType: MTLPatchType = .triangle
    /// Indicates whether only the wireframe or the whole patch will be displayed.
    var wireframe: Bool = true
    /// Tessellation factors to be applied on the following renders.
    var factors: (edge: Float, inside: Float) = (2, 2)
    
    init(view: MTKView) {
        super.init()
        
        guard self.setupMetal() else { fatalError("Metal basic entities (device, command queue, and library) could not be setup.") }
        
    }
    
    // MARK: Setup methods
    
    func setupMetal() -> Bool {
        return false
    }
    
    func setupComputePipelines() -> Bool {
        return false
    }
    
    func setupRenderPipelines(view: MTKView) -> Bool {
        return false
    }
    
    func setupBuffers() {
        
    }
    
    // MARK: Compute/Render methods
    
    func computeTessellationFactors(on commandBuffer: MTLCommandBuffer) {
        
    }
    
    func tessellateAndRender(view: MTKView, commandBuffer: MTLCommandBuffer) {
        
    }
    
    // MARK: MTKView delegate methods
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        autoreleasepool {
            
        }
    }
}
