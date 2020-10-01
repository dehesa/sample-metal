#include <metal_stdlib>
using namespace metal;

/// Makes no changes onto the framebuffer.
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderPass(float2 const fragCoords) {
    return fragCoords;
}

/// Flips the framebuffer vertically.
///
/// Notice that the Y-axis goes positive downwards. Thus, when fragCoords.y is negated, the image is reflected over the X-axis.
/// Since the coordinates range is [0,1], the reflection is translated a full height (i.e.: 1).
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderMirror(float2 const fragCoords) {
    return float2(fragCoords.x, 1.0f - fragCoords.y);
}

/// Mirrors the framebuffer over the X-axis from the y values at the 0.5 value.
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderSymmetry(float2 const fragCoords) {
    return float2(fragCoords.x, 0.5f - abs(fragCoords.y - 0.5));
}

/// Rotates the framebuffer by `rotationAngle`, which in this case is 𝝉/8 (i.e. 45°).
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - parameter screenSize: Size of the drawing area in pixel numbers.
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderRotation(float2 const fragCoords, float2 const screenSize) {
    float2 const centered = fragCoords - 0.5f;
    // The fragment coordinates are normalized (range [0,1]). However the viewport is range [w,h].
    // If when rotating, the aspect ratio is not accounted for, we will get a distorted image.
    float2 const absoluteCoords = centered * screenSize;
    
    float2 const polarCoords = float2(length(absoluteCoords), atan2(absoluteCoords.y, absoluteCoords.x));
    float const rotationAngle = M_PI_F / 4.0f;       // 𝝉/8 == 45°
    float const 𝛂 = polarCoords[1] - rotationAngle;
    
    float2 const rotatedCoords = polarCoords[0] * float2(cos(𝛂), sin(𝛂));
    float2 const normalizedCoords = rotatedCoords / screenSize;
    return normalizedCoords + 0.5;
}

/// Zooms-in on the center of the texture.
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderZoom(float2 const fragCoords) {
    float2 const centered = fragCoords - 0.5f;
    float2 const blowCoords = 0.5 * centered;
    return blowCoords + 0.5f;
}

/// Zoom-lens distorion around the center of the texture.
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderZoomDistortion(float2 const fragCoords) {
    float2 const centered = fragCoords - 0.5f;
    // Smoothstep(min,max,v) returns 0 if v<=min and 1 if v>=max and performs a smooth Hermite interpolation between 0 and 1 when v€(min,max)
    float2 const distortion = smoothstep(0.0f, 0.5f, length(centered)) * centered;
    return distortion + 0.5;
}

/// Repetes the texture a given amount of times (both in X- and Y-direction.
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - parameter repetitions: Number of repetitions on the X- and Y-axes.
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderRepetition(float2 const fragCoords, float2 const repetitions) {
    return fmod(fragCoords, 1.0f/repetitions) * repetitions;
}

/// Rotates the framebuffer depending on the polar coordinates length. The farther away from pikachu's center, the more rotated it is.
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderSpiral(float2 const fragCoords) {
    float2 const centered = fragCoords - 0.5f;
    float2 const polarCoords = float2(length(centered), atan2(centered.y, centered.x));
    
    float const lmax = length(float2(0.5f)), anglemax = -M_PI_F;
    float const 𝛂 = polarCoords[1] + smoothstep(0.25*lmax,lmax,polarCoords[0]) * anglemax;
    
    float2 const rotatedCoords = polarCoords[0] * float2(cos(𝛂), sin(𝛂));
    return rotatedCoords + 0.5;
}

///
/// - parameter fragCoords: Fragment coordinate in normalized screen coordinates (range [0,1]).
/// - returns: Pikachu texture coordinate to be drawn on the targeted fragment (`fragCoords`).
float2 shaderThunder(float2 const fragCoords, float2 const screenSize, float const repetitions) {
    float2 const centered = fragCoords - float2(0.5f, 1.0f);
    float2 const absoluteCoords = centered * screenSize;
    float2 const polarCoords = float2(length(absoluteCoords), atan2(absoluteCoords.y, absoluteCoords.x));

    float const l = polarCoords[0];
    float const 𝛂 = //polarCoords[1];
                    fmod(polarCoords[1], 2.0f*M_PI_F/repetitions)*repetitions;
    float2 const rotatedCoords = l * float2(cos(𝛂), sin(𝛂));

    float2 const normalizedCoords = rotatedCoords / screenSize;
    return normalizedCoords + float2(0.5f, 1.0f);
    
//    float2 const centered = fragCoords - 0.5f;
//    float const 𝝉 = 2.0*M_PI_F;
//
//    float const aspect = (float)screenSize.x / (float)screenSize.y;
//    float2 const absoluteCoords = float2(centered.x * aspect, centered.y);
//    float2 const polarCoords = float2(length(absoluteCoords), atan2(absoluteCoords.y, absoluteCoords.x));
//
//    float2 const transCoords = float2(exp(polarCoords[0] + 1.0f), polarCoords[1]/(𝝉/repetitions));
//    float2 const result = abs(float2(transCoords[1], transCoords[0]));
//    return fmod(result + 0.5f, 1.0f);
}
