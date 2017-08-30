import UIKit
import Metal
import simd

extension MetalView {
    private struct Vertex {
        var position: float4
        var color: float4
    }
}

final class MetalView: UIView {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let vertexBuffer: MTLBuffer
    private let renderPipeline: MTLRenderPipelineState
    private var displayLink: CADisplayLink?
    
    private var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    override static var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        // Setup the Device and Command Queue (non-transient objects: expensive to create. Do save it)
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else { return nil }
        (self.device, self.queue) = (device, commandQueue)
        
        // Setup shader library
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc   = library.makeFunction(name: "main_vertex"),
              let fragmentFunc = library.makeFunction(name: "main_fragment") else { fatalError("Library or shaders not found") }
        
        // Setup pipeline (non-transient)
        self.renderPipeline = try! device.makeRenderPipelineState(descriptor: MTLRenderPipelineDescriptor().set {
            $0.vertexFunction = vertexFunc
            $0.fragmentFunction = fragmentFunc
            $0.colorAttachments[0].pixelFormat = .bgra8Unorm   // 8-bit unsigned integer [0, 255]
        })
        
        // Setup buffer (non-transient). Coordinates defined in clip space: [-1,+1]
        let vertices = [Vertex(position: [ 0,    0.5, 0, 1], color: [1,0,0,1]),
                        Vertex(position: [-0.5, -0.5, 0, 1], color: [0,1,0,1]),
                        Vertex(position: [ 0.5, -0.5, 0, 1], color: [0,0,1,1]) ]
        let size = vertices.count * MemoryLayout<Vertex>.stride
        self.vertexBuffer = device.makeBuffer(bytes: vertices, length: size)!
        
        super.init(coder: aDecoder)
        
        // Setup Core Animation related functionality
        self.metalLayer.setUp { (layer) in
            layer.device = device
            layer.pixelFormat = .bgra8Unorm
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        self.displayLink?.invalidate()
		guard let window = self.window else {
            return self.displayLink = nil
		}
		
		self.metalLayer.contentsScale = window.screen.nativeScale
        self.displayLink = CADisplayLink(target: self, selector: #selector(MetalView.tickTrigger(from:))).set {
            // $0.preferredFramesPerSecond = 60
            $0.add(to: .main, forMode: .commonModes)
        }
    }
    
    @objc func tickTrigger(from displayLink: CADisplayLink) {
        // Setup Command Buffers (transient)
		guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = self.queue.makeCommandBuffer() else { return }
		
        guard let _ = commandBuffer.makeRenderCommandEncoder(descriptor: MTLRenderPassDescriptor().set {
            $0.colorAttachments[0].setUp { (attachment) in
                attachment.texture = drawable.texture
                attachment.clearColor = MTLClearColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
                attachment.loadAction = .clear
                attachment.storeAction = .store
            }
        })?.set({
            $0.setRenderPipelineState(renderPipeline)
            $0.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            $0.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            $0.endEncoding()
        }) else { return }
		
		// Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
		commandBuffer.present(drawable)
		commandBuffer.commit()
    }
}
