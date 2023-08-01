#if os(macOS)
import Cocoa
#elseif canImport(UIKit)
import UIKit
#endif
import Metal

#if os(macOS)
@MainActor final class LowLevelView: NSView {
  private let metalState: MetalState

  init(device: MTLDevice, queue: MTLCommandQueue) {
    self.metalState = MetalState(device: device, queue: queue)!
    super.init(frame: .zero)

    self.wantsLayer = true
    self.metalState.layer = (layer as? CAMetalLayer)?.configure {
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
    self.metalState.timer = .none
    super.viewDidMoveToWindow()

    guard let window else { return }
    self.metalState.layer!.contentsScale = window.backingScaleFactor
    self.metalState.timer = FrameTimer { [unowned(unsafe) self] (now, out) in
      self.redraw(now: now, frame: out)
    }
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    self.metalState.layer!.drawableSize = self.convertToBacking(self.bounds).size
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.metalState.layer!.drawableSize = self.convertToBacking(self.bounds).size
  }
}
#elseif canImport(UIKit)
@MainActor final class LowLevelView: UIView {
  private let metalState: MetalState

  init(device: MTLDevice, queue: MTLCommandQueue) {
    self.metalState = MetalState(device: device, queue: queue)!
    super.init(frame: .zero)

    self.metalState.layer = (layer as? CAMetalLayer)?.configure {
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
    self.metalState.timer = .none
    super.didMoveToWindow()

    guard let window else { return }
    self.metalState.layer!.contentsScale = window.screen.nativeScale
    self.metalState.timer = FrameTimer { [unowned(unsafe) self] (now, out) in
      Task(priority: .high) { @MainActor [self] in
        self.redraw(now: now, frame: out)
      }
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
    let scale = self.metalState.layer!.contentsScale
    let size = self.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
    self.metalState.layer!.drawableSize = size
  }
}
#endif

// MARK: - Shared

extension LowLevelView {
  nonisolated func redraw(now: Double, frame: Double) {
    guard let metalLayer = self.metalState.layer,
          metalLayer.drawableSize.allSatisfy({ $0 > .zero }),
          let drawable = metalLayer.nextDrawable(),
          let commandBuffer = metalState.queue.makeCommandBuffer() else { return }

    let renderPass = MTLRenderPassDescriptor().configure {
      $0.colorAttachments[0].configure {
        $0.texture = drawable.texture
        $0.clearColor = MTLClearColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        $0.loadAction = .clear
        $0.storeAction = .store
      }
    }

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
    encoder.setRenderPipelineState(self.metalState.pipeline)
    encoder.setVertexBuffer(self.metalState.buffer, offset: 0, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

private extension LowLevelView {
  final class MetalState {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let buffer: MTLBuffer
    weak var layer: CAMetalLayer?
    var timer: FrameTimer?

    init?(device: MTLDevice, queue: MTLCommandQueue) {
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
        ShaderVertex(position: [ 0.0,  0.5, 0, 1], color: [1, 0, 0, 1]), // Top vertex
        ShaderVertex(position: [-0.5, -0.5, 0, 1], color: [0, 1, 0, 1]), // Left vertex
        ShaderVertex(position: [ 0.5, -0.5, 0, 1], color: [0, 0, 1, 1])  // Right vertex
      ]

      let length = vertices.count * MemoryLayout<ShaderVertex>.stride
      guard let buffer = device.makeBuffer(bytes: vertices, length: length, options: .cpuCacheModeWriteCombined) else { return nil }
      self.buffer = buffer.configure {
        $0.label = .identifier("buffer.vertices")
      }
    }
  }
}
