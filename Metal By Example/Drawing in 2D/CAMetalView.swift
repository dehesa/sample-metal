#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Metal

#if os(macOS)
/// Custom `NSView` holding the `CAMetalLayer` where the drawing will end up.
@MainActor final class CAMetalView: NSView {
  private let state: MetalState

  init(device: any MTLDevice, queue: any MTLCommandQueue) {
    self.state = MetalState(device: device, queue: queue)!
    super.init(frame: .zero)

    self.wantsLayer = true
    self.state.layer = (layer as? CAMetalLayer)!.configure {
      $0.device = device
      $0.pixelFormat = .bgra8Unorm
      $0.framebufferOnly = true
    }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override func makeBackingLayer() -> CALayer {
    CAMetalLayer()
  }

  override func viewDidMoveToWindow() {
    self.state.timer = .none
    super.viewDidMoveToWindow()

    guard let window else { return }
    self.state.layer.contentsScale = window.backingScaleFactor
    self.state.timer = FrameTimer { [unowned(unsafe) self] (now, out) in
      self.draw(now: now, frame: out)
    }
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    self.state.layer.drawableSize = self.convertToBacking(self.bounds).size
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.state.layer.drawableSize = self.convertToBacking(self.bounds).size
  }
}
#elseif canImport(UIKit)
/// Custom `UIView` holding the `CAMetalLayer` where the drawing will end up.
@MainActor final class CAMetalView: UIView {
  private let state: MetalState

  init(device: any MTLDevice, queue: any MTLCommandQueue) {
    self.state = MetalState(device: device, queue: queue)!
    super.init(frame: .zero)

    self.state.layer = (layer as? CAMetalLayer)!.configure {
      $0.device = device
      $0.pixelFormat = .bgra8Unorm
      $0.framebufferOnly = true
    }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override static var layerClass: AnyClass {
    CAMetalLayer.self
  }

  override func didMoveToWindow() {
    self.state.timer = .none
    super.didMoveToWindow()

    guard let window else { return }
    self.state.layer.contentsScale = window.screen.nativeScale
    self.state.timer = FrameTimer { [unowned(unsafe) self] (now, out) in
      self.draw(now: now, frame: out)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
    self.state.layer.configure {
      let scale = $0.contentsScale
      $0.drawableSize = self.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
  }
}
#endif

// MARK: - Shared

extension CAMetalView {
  nonisolated func draw(now: Double, frame: Double) {
    let layer = self.state.layer
    guard layer.drawableSize.allSatisfy({ $0 > .zero }),
          let drawable = layer.nextDrawable(),
          let commandBuffer = state.queue.makeCommandBuffer() else { return }

    let renderPass = MTLRenderPassDescriptor().configure {
      $0.colorAttachments[0].configure {
        $0.texture = drawable.texture
        $0.clearColor = MTLClearColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        $0.loadAction = .clear
        $0.storeAction = .store
      }
    }

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
    encoder.setRenderPipelineState(self.state.pipeline)
    encoder.setVertexBuffer(self.state.buffer, offset: 0, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

private extension CAMetalView {
  final class MetalState: @unchecked Sendable {
    /// The GPU doing the rendering.
    let device: any MTLDevice
    /// The queue serializing the tasks to be performed in the GPU.
    let queue: any MTLCommandQueue
    /// The render pipeline state (with MSL functions) to use when drawing the triangle.
    let pipeline: any MTLRenderPipelineState
    /// The buffer containing the triangle vertices in normalize coordinates (that is x: `[-1,1]`, y: `[-1,1]`, z: `[0,1]`)
    let buffer: any MTLBuffer
    /// Pointer to the Metal layer of the view.
    private let layerPointer: UnsafeMutablePointer<CAMetalLayer>
    /// The lock used to synchronize the changes in timer.
    private let lock: NSLock
    /// The timer synchronized with the screen refresh.
    private var _timer: FrameTimer?

    init?(device: any MTLDevice, queue: any MTLCommandQueue) {
      self.device = device
      self.queue = queue

      guard let library = device.makeDefaultLibrary(),
            let vertexFunc = library.makeFunction(name: "main_vertex"),
            let fragmentFunc = library.makeFunction(name: "main_fragment") else { return nil }

      let descriptor = MTLRenderPipelineDescriptor().configure {
        $0.label = .identifier("pipeline.render.triangle")
        $0.vertexFunction = vertexFunc
        $0.fragmentFunction = fragmentFunc
        $0.colorAttachments[0].pixelFormat = .bgra8Unorm // 8-bit unsigned integer [0, 255]
      }

      guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
      self.pipeline = pipeline

      let vertices: [ShaderVertex] = [
        ShaderVertex(position: [   0,  0.5, 0, 1], color: [1, 0, 0, 1]), // Top vertex
        ShaderVertex(position: [-0.5, -0.5, 0, 1], color: [0, 1, 0, 1]), // Left vertex
        ShaderVertex(position: [ 0.5, -0.5, 0, 1], color: [0, 0, 1, 1])  // Right vertex
      ]

      let length = vertices.count * MemoryLayout<ShaderVertex>.stride
      guard let buffer = device.makeBuffer(bytes: vertices, length: length, options: .cpuCacheModeWriteCombined) else { return nil }
      self.buffer = buffer.configure { $0.label = .identifier("buffer", "vertices") }

      self.layerPointer = .allocate(capacity: 1)
      self.lock = NSLock().configure { $0.name = .identifier("cametalview", "lock") }
    }

    deinit {
      self.layerPointer.deinitialize(count: 1)
      self.layerPointer.deallocate()
    }

    var layer: CAMetalLayer {
      get { self.layerPointer.pointee }
      set { self.layerPointer.pointee = newValue }
    }

    var timer: FrameTimer? {
      get { lock.withLock { self._timer } }
      set { lock.withLock { self._timer = newValue } }
    }
  }
}
