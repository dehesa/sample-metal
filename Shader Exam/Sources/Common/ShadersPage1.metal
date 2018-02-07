#include <metal_stdlib>
using namespace metal;

/// Make no changes onto the framebuffer.
half4 shaderPass(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
    const float4 color = texture.sample(s, uv);
    return half4(half3(color.rgb), 1);
}

/// Flips the framebuffer vertically.
half4 shaderMirror(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
    const float2 result = float2(uv.x, 1.0f - uv.y);
    const float4 color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

/// Mirrors the framebuffer over the X-axis from the y values over 0.5.
half4 shaderSymmetry(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
    const float2 result = float2(uv.x, 0.5f - abs(uv.y - 0.5));
    const float4 color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

/// Rotates the framebuffer by `rotationAngle`, which in this case is 𝝉/8 (a.k.a. 45°).
half4 shaderRotation(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
    const float aspect = (float)texture.get_width() / (float)texture.get_height();
    
    float2 transformedCoords = uv - 0.5f;
    transformedCoords.x *= aspect;
    
    const float2 polarCoords = float2(length(transformedCoords), atan2(transformedCoords.y, transformedCoords.x));
    const float rotationAngle = (2.0f*M_PI_F) / 8.0f;
    const float 𝛂 = polarCoords.y - rotationAngle;
    
    float2 result = polarCoords[0] * float2(cos(𝛂), sin(𝛂));
    result.x /= aspect;
    result += 0.5f;
    
    const float4 color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

//half4 shaderRotationVariant(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
//    const float3 position = float3(uv, 1.0f);
//
//    const float t = 0.5f;
//    float3x3 center = float3x3(1);
//    center[2] = float3(t, t, 1.0f);
//    float3x3 reverseCenter = float3x3(1);
//    reverseCenter[2] = float3(-t, -t, 1.0f);
//
//    float 𝝉 = 2.0f*M_PI_F;
//    float 𝛂 = 𝝉 / 8.0f;
//    float3x3 rotation = float3x3(
//        float3( cos(𝛂), sin(𝛂), 0),
//        float3(-sin(𝛂), cos(𝛂), 0),
//        float3(     0,       0, 1)
//    );
//
//    const float2 result = (reverseCenter * rotation * center * position).xy;
//    const float4 color = texture.sample(s, result);
//    return half4(half3(color.rgb), 1);
//}

half4 shaderZoom(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
    float2 shiftToCenter = uv - 0.5f;
    shiftToCenter /= 2.0f;
    float2 result = shiftToCenter + 0.5f;
    
    const float4 color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

half4 shaderZoomDistortion(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
    float2 shiftToCenter = uv - 0.5f;
    
    // Smoothstep(min,max,v) returns 0 if v<=min and 1 if v>=max and performs a smooth Hermite interpolation between 0 and 1 when v€(0,1)
    float2 result = shiftToCenter * smoothstep(0.0f, 0.5f, length(shiftToCenter));
    result += 0.5;
    
    const float4 color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

half4 shaderRepetition(const float2 uv, texture2d<float,access::sample> texture, sampler s) {
    const float reps = 4.0f;
    const float2 result = fmod(uv, float2(1.0f/reps)) * reps;
    
    const float4 color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}
