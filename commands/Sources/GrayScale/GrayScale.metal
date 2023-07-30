#include <metal_stdlib>
using namespace metal;

constant float3 kRec709Luma = float3(0.2126, 0.7152, 0.0722);

kernel void grayscale(
  texture2d<float,access::read>  in  [[texture(0)]],
  texture2d<float,access::write> out [[texture(1)]],
  uint2                          gid [[thread_position_in_grid]])
{
  if (gid.x < in.get_width() && gid.y < in.get_height()) {
    float4 const inColor = in.read(gid);
    float const gray = dot(inColor.rgb, kRec709Luma);
    float4 const outColor = float4(gray, gray, gray, inColor.a);
    out.write(outColor, gid);
  }
}
