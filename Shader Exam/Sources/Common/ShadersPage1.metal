#include <metal_stdlib>
using namespace metal;

/// Makes no changes onto the framebuffer.
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderPass(float2 const screen) {
    return screen;
}

/// Flips the framebuffer vertically.
///
/// Notice that the Y-axis goes positive downwards. Thus, when uv.y is negated, the image is reflected over the X-axis.
/// Since the texture coordinates range is [0,1], the reflection is translated a full height (i.e.: 1).
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderMirror(float2 const screen) {
    return float2(screen.x, 1.0f - screen.y);
}

/// Mirrors the framebuffer over the X-axis from the y values at the 0.5 value.
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderSymmetry(float2 const screen) {
    return float2(screen.x, 0.5f - abs(screen.y - 0.5));
}

/// Rotates the framebuffer by `rotationAngle`, which in this case is 𝝉/8 (i.e. 45°).
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - parameter screenSize: Size of the drawing area in pixel numbers.
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderRotation(float2 const screen, float2 const screenSize) {
    float2 const shiftToCenter = screen - 0.5f;
    float2 const texCoords = float2(shiftToCenter.x * screenSize.x, shiftToCenter.y * screenSize.y);
    
    float2 const polarCoords = float2(length(texCoords), atan2(texCoords.y, texCoords.x));
    float const rotationAngle = M_PI_F / 4.0f;       // 𝝉/8 == 45°
    float const 𝛂 = polarCoords[1] - rotationAngle;
    
    float2 const rotatedCoords = polarCoords[0] * float2(cos(𝛂), sin(𝛂));
    float2 const normalizedCoords = float2(rotatedCoords.x / screenSize.x, rotatedCoords.y / screenSize.y);
    return normalizedCoords + 0.5;
}

/// Zooms-in on the center of the texture.
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderZoom(float2 const screen) {
    float2 const shiftToCenter = screen - 0.5f;
    float2 const blowCoords = 0.5 * shiftToCenter;
    return blowCoords + 0.5f;
}

/// Zoom-lens distorion around the center of the texture.
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderZoomDistortion(float2 const screen) {
    float2 const shiftToCenter = screen - 0.5f;
    // Smoothstep(min,max,v) returns 0 if v<=min and 1 if v>=max and performs a smooth Hermite interpolation between 0 and 1 when v€(min,max)
    float2 const distortion = smoothstep(0.0f, 0.5f, length(shiftToCenter)) * shiftToCenter;
    return distortion + 0.5;
}

/// Repetes the texture a given amount of times (both in X- and Y-direction.
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderRepetition(float2 const screen, float const numRepetitions) {
    return fmod(screen, float2(1.0f/numRepetitions)) * numRepetitions;
}

///
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderSpiral(float2 const screen, float2 const screenSize) {
    float2 const shiftToCenter = screen - 0.5f;
    
    float const aspect = (float)screenSize.x / (float)screenSize.y;
    float2 const skewed = float2(shiftToCenter.x * aspect, shiftToCenter.y);
    
    float2 const polarCoords = float2(length(skewed)-0.1f, atan2(skewed.y, skewed.x));
    float const 𝛂 = polarCoords[1] + 10.0f*polarCoords[0];
    
    float2 const spiral = float2(cos(𝛂),sin(𝛂)) * length(skewed);
    return spiral + 0.5;
}

///
/// - parameter screen: Normalized screen coordinate (with range [0,1].
/// - returns: Coordinate specifying the pixel in the texture that will be drawn for the normalized screen coordinates `uv`.
float2 shaderThunder(float2 const screen, float2 const screenSize) {
    float2 const shiftToCenter = screen - 0.5f;
    
    float const aspect = (float)screenSize.x / (float)screenSize.y;
    float2 const skewed = float2(shiftToCenter.x * aspect, shiftToCenter.y);
    
    float2 const polarCoords = float2(exp(length(skewed) + 1.0f), 4.0f*atan2(skewed.y, skewed.x)/M_PI_F);
    return fmod(abs(float2(polarCoords[1], polarCoords[0]))+0.5f, 1.0f);
}
