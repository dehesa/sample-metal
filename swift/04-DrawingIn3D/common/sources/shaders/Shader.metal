#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

vertex Vertex main_vertex(device   Vertex*   vertices [[buffer(0)]],
                          constant Uniforms* uniforms [[buffer(1)]],
							       uint      vid	  [[vertex_id]]) {
    Vertex vertexOut;
    vertexOut.position = uniforms->modelViewProjectionMatrix *vertices[vid].position;
    vertexOut.color = vertices[vid].color;
    return vertexOut;
}

fragment float4 main_fragment(Vertex inVertex [[stage_in]]) {
    return inVertex.color;
}
