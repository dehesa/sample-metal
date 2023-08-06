import SwiftUI

@main struct Page1App: App {
  @State private var exercise: Exercise = .passthrough

  var body: some Scene {
    WindowGroup {
      MetalView(exercise: self.exercise)
        .toolbar {
          Picker("Exercise", selection: self.$exercise) {
            ForEach(Exercise.allCases) {
              Text($0.description)
            }
          }
        }.navigationTitle("Page 1")
        .ignoresSafeArea()
    }
  }
}

enum Exercise: Identifiable, CustomStringConvertible, CaseIterable {
  case passthrough
  case mirror
  case symmetry
  case rotation
  case zoom
  case zoomDistortion
  case repetition
  case spiral
  case thunder

  var id: Self {
    self
  }

  var description: String {
    switch self {
    case .passthrough: "Passthrough"
    case .mirror: "Mirror"
    case .symmetry: "Symmetry"
    case .rotation: "Rotation"
    case .zoom: "Zoom"
    case .zoomDistortion: "Zoom Distortion"
    case .repetition: "Repetition"
    case .spiral: "Spiral"
    case .thunder: "Thunder"
    }
  }
}
