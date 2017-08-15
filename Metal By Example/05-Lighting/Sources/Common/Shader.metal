#include <metal_stdlib>
#include <metal_matrix>
using namespace metal;

struct VertexInput {
    float4 position [[attribute(0)]];
    float4 normal [[attribute(1)]];
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewMatrix;
    float3x3 normalMatrix;
};

struct VertexProjected {
    float4 position [[position]];
    float3 eye;
    float3 normal;
};

vertex VertexProjected main_vertex(const    VertexInput v   [[stage_in]],
                                   constant Uniforms&   u   [[buffer(1)]],
                                            uint        vid [[vertex_id]]) {
    return VertexProjected{
        .position = u.modelViewProjectionMatrix * v.position,
        .eye = -(u.modelViewMatrix * v.position).xyz,
        .normal = u.normalMatrix * v.normal.xyz
    };
}

struct Light {
    float3 direction;
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
};

struct Material {
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
    float specularPower;
};

constant Light light = {
    .direction = { 0.13, 0.72, 0.68 },
    .ambientColor = { 0.05, 0.05, 0.05 },
    .diffuseColor = { 0.9, 0.9, 0.9 },
    .specularColor = { 1, 1, 1 }
};

constant Material material = {
    .ambientColor = { 0.9, 0.1, 0 },
    .diffuseColor = { 0.9, 0.1, 0 },
    .specularColor = { 1, 1, 1 },
    .specularPower = 100
};

fragment float4 main_fragment(const    VertexProjected v [[stage_in]]) {
    float3 ambientTerm = light.ambientColor * material.ambientColor;
    
    float3 normal = normalize(v.normal);
    float diffuseIntensity = saturate(dot(normal, light.direction));
    float3 diffuseTerm = light.diffuseColor * material.diffuseColor * diffuseIntensity;
    
    float3 specularTerm(0);
    if (diffuseIntensity > 0) {
        float3 eyeDirection = normalize(v.eye);
        float3 halfway = normalize(light.direction + eyeDirection);
        float specularFactor = pow(saturate(dot(normal, halfway)), material.specularPower);
        specularTerm = light.specularColor * material.specularColor * specularFactor;
    }
    
    return float4(ambientTerm + diffuseTerm + specularTerm, 1);
}

