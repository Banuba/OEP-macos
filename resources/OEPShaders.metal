//
//  OEPShaders.metal
//
//  Copyright © 2021 Banuba. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

namespace BNBOEPShaders
{

struct Vertex {
    float4 position [[position]];
    float2 tex_coord;
};

struct OrinetationInfo {
    uint rot_index;
};
    
Vertex getVertex(uint vertexId, uint orientation) {
    // NOTES:
    // - position coordinates has inverted Y axis to compensate input texture orientation.
    // Without that the final flip of Y axis, since we render to the texture also, causes mirroring of image.

    // When vertices is a global contstant array it results in an error for iOS 12.3 - 12.4,
    // because the array is used in two functions and treats as inline.
    Vertex vertices[4][6 * 4] =
    { /* verical flip 0 */
        { // 0
            // positions            // texture coords
            {{1.0f,  -1.0f, 0.0f, 1.0f},  {0.0f, 0.0f}}, // top right
            {{1.0f,   1.0f, 0.0f, 1.0f},  {0.0f, 1.0f}}, // bottom right
            {{-1.0f,  1.0f, 0.0f, 1.0f},  {1.0f, 1.0f}}, // bottom left
            {{-1.0f, -1.0f, 0.0f, 1.0f},  {1.0f, 0.0f}},  // top left
        },
        { // 90
            // positions            // texture coords
            {{1.0f,  -1.0f, 0.0f, 1.0f},  {0.0f, 1.0f}}, // top right
            {{1.0f,   1.0f, 0.0f, 1.0f},  {1.0f, 1.0f}}, // bottom right
            {{-1.0f,  1.0f, 0.0f, 1.0f},  {1.0f, 0.0f}}, // bottom left
            {{-1.0f, -1.0f, 0.0f, 1.0f},  {0.0f, 0.0f}},  // top left
        },
        { // 180
            // positions            // texture coords
            {{1.0f,  -1.0f, 0.0f, 1.0f},  {1.0f, 1.0f}}, // top right
            {{1.0f,   1.0f, 0.0f, 1.0f},  {1.0f, 0.0f}}, // bottom right
            {{-1.0f,  1.0f, 0.0f, 1.0f},  {0.0f, 0.0f}}, // bottom left
            {{-1.0f, -1.0f, 0.0f, 1.0f},  {0.0f, 1.0f}},  // top left
        },
        { // 270
            // positions            // texture coords
            {{1.0f,  -1.0f, 0.0f, 1.0f},  {1.0f, 0.0f}}, // top right
            {{1.0f,   1.0f, 0.0f, 1.0f},  {0.0f, 0.0f}}, // bottom right
            {{-1.0f,  1.0f, 0.0f, 1.0f},  {0.0f, 1.0f}}, // bottom left
            {{-1.0f, -1.0f, 0.0f, 1.0f},  {1.0f, 1.0f}},  // top left
        }
    };
    
    return vertices[orientation][vertexId];
}

vertex Vertex vertex_main(device const OrinetationInfo& orientation [[buffer(0)]],
                             uint vertexId [[vertex_id]]) {
    return getVertex(vertexId, orientation.rot_index);
}

fragment half4 fragment_main(Vertex in [[stage_in]],
                              texture2d<float, access::sample> textureRGBA [[ texture(0) ]]) {
    constexpr sampler samplr(s_address::clamp_to_edge,
                             t_address::clamp_to_edge,
                             r_address::clamp_to_edge,
                             min_filter::linear,
                             mag_filter::linear
                             );
    return half4(textureRGBA.sample(samplr, in.tex_coord).bgra);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// i420 conversion shaders
struct VertexOuti420 {
    float4 position [[position]];
    float2 tex_coord;
    float4 plane_coef;
    float2 pixel_step;
};

vertex VertexOuti420 vertex_i420(device const OrinetationInfo& orientation [[buffer(0)]],
                             device const packed_float4& plane_coef [[buffer(1)]],
                             device const float2& pixel_step [[buffer(2)]],
                             uint vertexId [[vertex_id]]) {
    Vertex out = getVertex(vertexId, orientation.rot_index);
    
    VertexOuti420 out_i420;
    out_i420.position = out.position;
    out_i420.tex_coord = out.tex_coord;
    out_i420.plane_coef = float4(plane_coef[0], plane_coef[1], plane_coef[2], plane_coef[3]);
    out_i420.pixel_step = float2(pixel_step[0], pixel_step[1]);
    return out_i420;
}

fragment half4 fragment_i420(VertexOuti420 in [[stage_in]],
                             texture2d<float, access::sample> textureRGBA [[ texture(0) ]]) {
    constexpr sampler samplr(s_address::clamp_to_edge,
                             t_address::clamp_to_edge,
                             r_address::clamp_to_edge,
                             min_filter::linear,
                             mag_filter::linear
                             );
    half4 res;
    res.b = in.plane_coef.a + dot(in.plane_coef.rgb, textureRGBA.sample(samplr, in.tex_coord - 1.5 * in.pixel_step).rgb);
    res.g = in.plane_coef.a + dot(in.plane_coef.rgb, textureRGBA.sample(samplr, in.tex_coord - 0.5 * in.pixel_step).rgb);
    res.r = in.plane_coef.a + dot(in.plane_coef.rgb, textureRGBA.sample(samplr, in.tex_coord + 0.5 * in.pixel_step).rgb);
    res.a = in.plane_coef.a + dot(in.plane_coef.rgb, textureRGBA.sample(samplr, in.tex_coord + 1.5 * in.pixel_step).rgb);

    return res.rgba;
}

} // namespace BNBOEPShaders
