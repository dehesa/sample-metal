#include <metal_stdlib>
using namespace metal;

/// Make no changes onto the framebuffer.
half4 shaderPass(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float4 const color = texture.sample(s, uv);
    
    return half4(half3(color.rgb), 1);
}

/// Flips the framebuffer vertically.
half4 shaderMirror(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float2 const result = float2(uv.x, 1.0f - uv.y);
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

/// Mirrors the framebuffer over the X-axis from the y values over 0.5.
half4 shaderSymmetry(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float2 const result = float2(uv.x, 0.5f - abs(uv.y - 0.5));
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

/// Rotates the framebuffer by `rotationAngle`, which in this case is 𝝉/8 (a.k.a. 45°).
half4 shaderRotation(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float2 const shiftToCenter = uv - 0.5f;
    
    float const aspect = (float)texture.get_width() / (float)texture.get_height();
    float2 const skewed = float2(shiftToCenter.x * aspect, shiftToCenter.y);
    
    float2 const polarCoords = float2(length(skewed), atan2(skewed.y, skewed.x));
    float const rotationAngle = M_PI_F / 4.0f;       // π/4 == 𝝉/8 == 45°
    float const 𝛂 = polarCoords[1] - rotationAngle;
    
    float2 const rotation = polarCoords[0] * float2(cos(𝛂), sin(𝛂));
    float2 const result = float2(rotation.x / aspect, rotation.y) + 0.5;
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

half4 shaderZoom(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float2 const shiftToCenter = uv - 0.5f;
    float2 const result = (0.5f * shiftToCenter) + 0.5f;
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

half4 shaderZoomDistortion(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float2 const shiftToCenter = uv - 0.5f;
    // Smoothstep(min,max,v) returns 0 if v<=min and 1 if v>=max and performs a smooth Hermite interpolation between 0 and 1 when v€(0,1)
    float2 const distortion = shiftToCenter * smoothstep(0.0f, 0.5f, length(shiftToCenter));
    float2 const result = distortion + 0.5;
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

half4 shaderRepetition(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float const reps = 4.0f;
    float2 const result = fmod(uv, float2(1.0f/reps)) * reps;
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

half4 shaderSpiral(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float2 const shiftToCenter = uv - 0.5f;
    
    float const aspect = (float)texture.get_width() / (float)texture.get_height();
    float2 const skewed = float2(shiftToCenter.x * aspect, shiftToCenter.y);
    
    float2 const polarCoords = float2(length(skewed)-0.1f, atan2(skewed.y, skewed.x));
    float const 𝛂 = polarCoords[1] + 10.0f*polarCoords[0];
    
    float2 const spiral = float2(cos(𝛂),sin(𝛂)) * length(skewed);
    float2 const result = spiral + 0.5;
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}

half4 shaderThunder(float2 const uv, texture2d<float,access::sample> texture, sampler s) {
    float2 const shiftToCenter = uv - 0.5f;
    
    float const aspect = (float)texture.get_width() / (float)texture.get_height();
    float2 const skewed = float2(shiftToCenter.x * aspect, shiftToCenter.y);
    
    float2 const polarCoords = float2(exp(length(skewed) + 1.0f), 4.0f*atan2(skewed.y, skewed.x)/M_PI_F);
    float2 const result = fmod(abs(float2(polarCoords[1], polarCoords[0]))+0.5f, 1.0f);
    
    float4 const color = texture.sample(s, result);
    return half4(half3(color.rgb), 1);
}
