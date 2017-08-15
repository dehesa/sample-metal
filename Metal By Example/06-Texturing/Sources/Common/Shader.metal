#include <metal_stdlib>
using namespace metal;

constant float3 kSpecularColor= { 1, 1, 1 };
constant float kSpecularPower = 80;

struct VertexInput {
    packed_float4 position;
    packed_float4 normal;
    packed_float2 texCoords;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewMatrix;
    float3x3 normalMatrix;
};

struct VertexProjected {
    float4 position [[position]];
    float3 eyePosition;
    float3 normal;
    float2 texCoords;
};

vertex VertexProjected main_vertex(device   VertexInput* v   [[buffer(0)]],
                                   constant Uniforms&    u   [[buffer(1)]],
                                            uint         vid [[vertex_id]]) {
    float4 position = v[vid].position;
    float4 normal = v[vid].normal;

    return VertexProjected{
        .position = u.modelViewProjectionMatrix * position,
        .eyePosition = -(u.modelViewMatrix * position).xyz,
        .normal = u.normalMatrix * normal.xyz,
        .texCoords = v[vid].texCoords
    };
}

struct Light {
    float3 direction;
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
};

constant Light light = {
    .direction = { 0.13, 0.72, 0.68 },
    .ambientColor = { 0.05, 0.05, 0.05 },
    .diffuseColor = { 1, 1, 1 },
    .specularColor = { 0.2, 0.2, 0.2 }
};

fragment float4 main_fragmemnt(VertexProjected  v              [[stage_in]],
                               texture2d<float> diffuseTexture [[texture(0)]],
                               sampler          samplr         [[sampler(0)]]) {
    float3 diffuseColor = diffuseTexture.sample(samplr, v.texCoords).rgb;
    
    float3 ambientTerm = light.ambientColor * diffuseColor;
    
    float3 normal = normalize(v.normal);
    float diffuseIntensity = saturate(dot(normal, light.direction));
    float3 diffuseTerm = light.diffuseColor * diffuseColor * diffuseIntensity;
    
    float3 specularTerm(0);
    if (diffuseIntensity > 0) {
        float3 eyeDirection = normalize(v.eyePosition);
        float3 halfway = normalize(light.direction + eyeDirection);
        float specularFactor = pow(saturate(dot(normal, halfway)), kSpecularPower);
        specularTerm = light.specularColor * kSpecularColor * specularFactor;
    }
    
    return float4(ambientTerm + diffuseTerm + specularTerm, 1);
}
