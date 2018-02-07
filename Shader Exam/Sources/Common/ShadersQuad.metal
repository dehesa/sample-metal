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

vertex QuadVertexOut vertex_post(QuadVertexIn in [[stage_in]]) {
    return QuadVertexOut {
        .position = float4(in.position, 0, 1),
        .texCoords = in.texCoords
    };
}

// Page 1 shaders
half4 shaderPass(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderMirror(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderSymmetry(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderRotation(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderZoom(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderZoomDistortion(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderRepetition(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderSpirale(const float2 uv, texture2d<float,access::sample> texture, sampler s);
half4 shaderThunder(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
// Page 2 shaders
half4 shaderClamp(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPli(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderColorDirection(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPixelation(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderVague(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderColonne(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderCrash(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderScanline(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderDoubleFrequency(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
// Page 3 shaders
half4 shaderBlackAndWhite(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderThreshold(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderThresholds(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderSonar(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderGrid(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderStamp(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderLocalNegative(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderChromaticAberration(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderChromaKey(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
// Page 4 shaders
half4 shaderVague2(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderChubby(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderSkinny(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderTwist(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderGlitch(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderGlitchVoxel(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderBasicShading(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderToonShading(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderCellShading(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
// Page 5 shaders
half4 shaderSphere(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderSphereRepeat(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPyramid(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderPolarModulo(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderTubeTwist(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderTubeWeb(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderVolumetricCloud(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderStranglerFig(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO
half4 shaderKirby(const float2 uv, texture2d<float,access::sample> texture, sampler s);   // TODO

fragment half4 fragment_post(QuadVertexOut in [[stage_in]], texture2d<float,access::sample> texture [[texture(0)]]) {
    // Constant sampler for the texture.
    constexpr sampler sampler2d(coord::normalized, filter::linear);
    // Texture coordinates range from 0 to 1. X-positive values go from the top-left to the top-right; while Y-positive go from top-left to bottom-left.
    
    // Page 1
    return shaderPass(in.texCoords, texture, sampler2d);
    // return shaderMirror(in.texCoords, texture, sampler2d);
    // return shaderSymmetry(in.texCoords, texture, sampler2d);
    // return shaderRotation(in.texCoords, texture, sampler2d);
    // return shaderZoom(in.texCoords, texture, sampler2d);
    // return shaderZoomDistortion(in.texCoords, texture, sampler2d);
    // return shaderRepetition(in.texCoords, texture, sampler2d);
    
    // Page 2
    // return shaderClamp(in.texCoords, texture, sampler2d);
    // return shaderPli(in.texCoords, texture, sampler2d);
    // return shaderColorDirection(in.texCoords, texture, sampler2d);
    // return shaderPixelation(in.texCoords, texture, sampler2d);
    // return shaderVague(in.texCoords, texture, sampler2d);
    // return shaderColonne(in.texCoords, texture, sampler2d);
    // return shaderCrash(in.texCoords, texture, sampler2d);
    // return shaderScanline(in.texCoords, texture, sampler2d);
    // return shaderDoubleFrequency(in.texCoords, texture, sampler2d);
    
    // Page 3
    // return shaderBlackAndWhite(in.texCoords, texture, sampler2d);
    // return shaderThreshold(in.texCoords, texture, sampler2d);
    // return shaderThresholds(in.texCoords, texture, sampler2d);
    // return shaderSonar(in.texCoords, texture, sampler2d);
    // return shaderGrid(in.texCoords, texture, sampler2d);
    // return shaderStamp(in.texCoords, texture, sampler2d);
    // return shaderLocalNegative(in.texCoords, texture, sampler2d);
    // return shaderChromaticAberration(in.texCoords, texture, sampler2d);
    // return shaderChromaKey(in.texCoords, texture, sampler2d);
    
    // Page 4
    // return shaderVague2(in.texCoords, texture, sampler2d);
    // return shaderChubby(in.texCoords, texture, sampler2d);
    // return shaderSkinny(in.texCoords, texture, sampler2d);
    // return shaderTwist(in.texCoords, texture, sampler2d);
    // return shaderGlitch(in.texCoords, texture, sampler2d);
    // return shaderGlitchVoxel(in.texCoords, texture, sampler2d);
    // return shaderBasicShading(in.texCoords, texture, sampler2d);
    // return shaderToonShading(in.texCoords, texture, sampler2d);
    // return shaderCellShading(in.texCoords, texture, sampler2d);
    
    // Page 5
}
