#include <metal_stdlib>
using namespace metal;

struct QuadVertexIn {
    float2 position  [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct QuadVertexOut {
    float4 position [[position]];
    float2 texCoords;
};

vertex QuadVertexOut vertex_post(QuadVertexIn in [[stage_in]])
{
    return QuadVertexOut {
        .position = float4(in.position, 0, 1),
        .texCoords = in.texCoords
    };
}

fragment half4 fragment_post(QuadVertexOut in [[stage_in]],
                             texture2d<float, access::sample> texture [[texture(0)]]) {
    constexpr sampler sampler2d(coord::normalized, filter::linear);
    float2 uv = in.texCoords;
    
    float4 color = texture.sample(sampler2d, uv);
    return half4(half3(color.rgb), 1);
}
