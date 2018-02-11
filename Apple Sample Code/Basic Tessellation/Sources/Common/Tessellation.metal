#include <metal_stdlib>
using namespace metal;

#pragma mark Compute Kernels

/// Triangle compute kernel.
///
/// It populates a per-patch tessellation factors buffer.
kernel void kernel_triangle(constant float& edge_factor    [[buffer(0)]],
                            constant float& inside_factor  [[buffer(1)]],
                            device   MTLTriangleTessellationFactorsHalf* factors [[buffer(2)]],
                            const    uint   pid            [[thread_position_in_grid]]) {
    // Simple passthrough operation.
    // More sophisticated compute kernels might determine the tessellation factors based on the state of the scene (e.g. camera distance).
    half const edge = half(edge_factor);
    half const inside = half(inside_factor);
    
    factors[pid] = MTLTriangleTessellationFactorsHalf {
        // The array is composed of division/sectors along the edges: { right, bottom, left }
        .edgeTessellationFactor = { edge, edge, edge },
        // The number express the divisions/sectors along one of the baricentric lines.
        .insideTessellationFactor = inside
    };
}

/// Quad compute kernel.
///
/// It populates a per-patch tessellation factors buffer.
kernel void kernel_quad(constant float& edge_factor   [[buffer(0)]],
                        constant float& inside_factor [[buffer(1)]],
                        device   MTLQuadTessellationFactorsHalf* factors [[buffer(2)]],
                        const    uint   pid           [[thread_position_in_grid]]) {
    // Simple passthrough operation.
    // More sophisticated compute kernels might determine the tessellation factors based on the state of the scene (e.g. camera distance).
    half const edge = half(edge_factor);
    half const inside = half(inside_factor);
    
    factors[pid] = MTLQuadTessellationFactorsHalf {
        // The array is composed of divisions/sectors along the edges: { left, top, right, bottom }
        .edgeTessellationFactor = { edge, edge, edge, edge },
        // The array is composed of divisions/sectors axis: { horizontal, vertical }
        .insideTessellationFactor = { inside, inside }
    };
}

#pragma mark Post-Tessellation Vertex Functions

// Control Point struct.
struct ControlPoint {
    float4 position [[attribute(0)]];
};

// Patch struct.
struct PatchIn {
    patch_control_point<ControlPoint> control_points;
};

// Vertex-to-Fragment struct.
struct VertexFragmentProperties {
    float4 position [[position]];
    half4  color    [[flat]];
};

/// Triangle post-tessellation vertex function.
///
/// It converts patch coordinates to display coordinates.
[[patch(triangle, 3)]]
vertex VertexFragmentProperties vertex_triangle(PatchIn patchIn     [[stage_in]],
                                                float3  patch_coord [[position_in_patch]]) {
    // Barycentric coordinates.
    float const u = patch_coord.x;
    float const v = patch_coord.y;
    float const w = patch_coord.z;
    
    // Convert to cartesian coordinates.
    float const x = u * patchIn.control_points[0].position.x + v * patchIn.control_points[1].position.x + w * patchIn.control_points[2].position.x;
    float const y = u * patchIn.control_points[0].position.y + v * patchIn.control_points[1].position.y + w * patchIn.control_points[2].position.y;
    
    return VertexFragmentProperties {
        .position = float4(x, y, 0.0, 1.0),
        .color = half4(u, v, w, 1.0)
    };
}

/// Quad post-tessellation vertex function.
///
/// It converts patch coordinates to display coordinates.
[[patch(quad, 4)]]
vertex VertexFragmentProperties vertex_quad(PatchIn patchIn     [[stage_in]],
                                            float2  patch_coord [[position_in_patch]]) {
    // Parameter coordinates.
    float const u = patch_coord.x;
    float const v = patch_coord.y;
    
    // Linear interpolation.
    float2 const upper_middle = mix(patchIn.control_points[0].position.xy, patchIn.control_points[1].position.xy, u);
    float2 const lower_middle = mix(patchIn.control_points[2].position.xy, patchIn.control_points[3].position.xy, 1-u);
    
    return VertexFragmentProperties {
        .position = float4(mix(upper_middle, lower_middle, v), 0.0, 1.0),
        .color = half4(u, v, 1.0-v, 1.0)
    };
}

#pragma mark Fragment Function

/// Common fragment function.
///
/// It outputs a flat color for each vertex position.
/// - parameter fragmentIn: Properties for the targeted fragment passed from the rasterizer.
fragment half4 fragment_both(VertexFragmentProperties fragmentIn [[stage_in]]) {
    return fragmentIn.color;
}
