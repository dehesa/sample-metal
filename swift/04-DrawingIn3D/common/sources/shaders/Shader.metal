#include <metal_stdlib>
using namespace metal;

struct Vertex {
    // [[position]] attribute is used to signify to Metal which value should be regarded as the clip-space position of the vertex returned by the vertex shader.
    // When returning a custom struct from a vertex shader, exactly one member of the struct must have this attribute. Alternatively, you may return a `float4` from your vertex function, which is implicitly assumed to be the vertex's position.
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

vertex Vertex vertex_main(device Vertex* vertices [[buffer(0)]], constant Uniforms *uniforms [[buffer(1)]], uint vid [[vertex_id]]) {
    Vertex vertexOut;
    vertexOut.position = uniforms->modelViewProjectionMatrix * vertices[vid].position;
    vertexOut.color = vertices[vid].color;
    return vertexOut;
}

// [[stage_in]] attribute identifies it as per-fragment data rather than data that is constant accross a draw call. The Vertex here is an interpolated value.
fragment half4 fragment_main(Vertex vertexIn [[stage_in]]) {
    return half4(vertexIn.color);
}
