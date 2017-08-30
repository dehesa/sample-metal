#include <metal_stdlib>
using namespace metal;

constant float3 kLightDirection(0, 0, -1);

struct VertexInput {
    float4 position  [[attribute(0)]];
    float4 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct Uniforms {
    float4x4 modelMatrix;
    float3x3 normalMatrix;
    float4x4 modelViewProjectionMatrix;
};

struct VertexProjected {
    float4 position [[position]];
    float3 normal [[user(normal)]];
    float2 texCoords [[user(tex_coords)]];
};

vertex VertexProjected main_vertex(const    VertexInput v   [[stage_in]],
                                   constant Uniforms&   u   [[buffer(1)]]) {
    return VertexProjected {
        .position = u.modelViewProjectionMatrix * v.position,
        .normal = u.normalMatrix * v.normal.xyz,
        .texCoords = v.texCoords
    };
}

fragment half4 main_fragment(VertexProjected                 vert       [[stage_in]],
                             texture2d<float,access::sample> texture    [[texture(0)]],
                             sampler                         texSampler [[sampler(0)]]) {
    float diffuseIntensity = max(0.33, dot(normalize(vert.normal), -kLightDirection));
    float4 diffuseColor = texture.sample(texSampler, vert.texCoords);
    float4 color = diffuseColor * diffuseIntensity;
    return half4(color.r, color.g, color.b, 1);
}

