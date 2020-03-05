#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 mvpMatrix;
};

vertex Vertex main_vertex(device Vertex const* const vertices [[buffer(0)]],
                          constant Uniforms* uniforms [[buffer(1)]], uint vid [[vertex_id]]) {
    return Vertex {
        .position = uniforms->mvpMatrix * vertices[vid].position,
        .color = vertices[vid].color
    };
}

fragment float4 main_fragment(Vertex inVertex [[stage_in]]) {
    return inVertex.color;
}
