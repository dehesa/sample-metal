//: Playground - noun: a place where people can play

import Cocoa
import Metal
import simd

"Int8   (size: \(MemoryLayout<Int8>.size), stride: \(MemoryLayout<Int8>.stride), alignment: \(MemoryLayout<Int8>.alignment))"
"Int16  (size: \(MemoryLayout<Int16>.size), stride: \(MemoryLayout<Int16>.stride), alignment: \(MemoryLayout<Int16>.alignment))"
"Int32  (size: \(MemoryLayout<Int32>.size), stride: \(MemoryLayout<Int32>.stride), alignment: \(MemoryLayout<Int32>.alignment))"
"Int    (size: \(MemoryLayout<Int>.size), stride: \(MemoryLayout<Int>.stride), alignment: \(MemoryLayout<Int>.alignment))"

"UInt8  (size: \(MemoryLayout<UInt8>.size), stride: \(MemoryLayout<UInt8>.stride), alignment: \(MemoryLayout<UInt8>.alignment))"
"UInt16 (size: \(MemoryLayout<UInt16>.size), stride: \(MemoryLayout<UInt16>.stride), alignment: \(MemoryLayout<UInt16>.alignment))"
"UInt32 (size: \(MemoryLayout<UInt32>.size), stride: \(MemoryLayout<UInt32>.stride), alignment: \(MemoryLayout<UInt32>.alignment))"
"UInt   (size: \(MemoryLayout<UInt>.size), stride: \(MemoryLayout<UInt>.stride), alignment: \(MemoryLayout<UInt>.alignment))"

"Half  (size: \(MemoryLayout<UInt16>.size), stride: \(MemoryLayout<UInt16>.stride), alignment: \(MemoryLayout<UInt16>.alignment))"
"Float  (size: \(MemoryLayout<Float>.size), stride: \(MemoryLayout<Float>.stride), alignment: \(MemoryLayout<Float>.alignment))"
"Double (size: \(MemoryLayout<Double>.size), stride: \(MemoryLayout<Double>.stride), alignment: \(MemoryLayout<Double>.alignment))"

let triangleControlPointPositions: [Float] = [
    -0.8, -0.8, 0.0, 1.0,   // lower-left
    0.0,  0.8, 0.0, 1.0,   // upper-middle
    0.8, -0.8, 0.0, 1.0,   // lower-right
]

let quadControlPointPositions: [Float] = [
    -0.8,  0.8, 0.0, 1.0,   // upper-left
    0.8,  0.8, 0.0, 1.0,   // upper-right
    0.8, -0.8, 0.0, 1.0,   // lower-right
    -0.8, -0.8, 0.0, 1.0,   // lower-left
]
