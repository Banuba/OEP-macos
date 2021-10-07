//
//  OEPShaders.metal
//
//  Copyright © 2021 Banuba. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

namespace BNBOEPShaders
{

struct VertexIn {
    packed_float3 position;
    packed_float2 tex_coord;
};

struct OrinetationInfo {
    uint rot_index;
};

// NOTES:
// - position coordinates has inverted Y axis to compensate input texture orientation. 
// Without that the final flip of Y axis, since we render to the texture also, causes mirroring of image.
constant VertexIn vertices[4][5 * 4] =
{ /* verical flip 0 */
    { // 0
        // positions            // texture coords
        {{1.0f,  -1.0f, 0.0f},  {0.0f, 0.0f}}, // top right
        {{1.0f,   1.0f, 0.0f},  {0.0f, 1.0f}}, // bottom right
        {{-1.0f,  1.0f, 0.0f},  {1.0f, 1.0f}}, // bottom left
        {{-1.0f, -1.0f, 0.0f},  {1.0f, 0.0f}},  // top left
    },
    { // 90
        // positions            // texture coords
        {{1.0f,  -1.0f, 0.0f},  {0.0f, 1.0f}}, // top right
        {{1.0f,   1.0f, 0.0f},  {1.0f, 1.0f}}, // bottom right
        {{-1.0f,  1.0f, 0.0f},  {1.0f, 0.0f}}, // bottom left
        {{-1.0f, -1.0f, 0.0f},  {0.0f, 0.0f}},  // top left
    },
    { // 180
        // positions            // texture coords
        {{1.0f,  -1.0f, 0.0f},  {1.0f, 1.0f}}, // top right
        {{1.0f,   1.0f, 0.0f},  {1.0f, 0.0f}}, // bottom right
        {{-1.0f,  1.0f, 0.0f},  {0.0f, 0.0f}}, // bottom left
        {{-1.0f, -1.0f, 0.0f},  {0.0f, 1.0f}},  // top left
    },
    { // 270
        // positions            // texture coords
        {{1.0f,  -1.0f, 0.0f},  {1.0f, 0.0f}}, // top right
        {{1.0f,   1.0f, 0.0f},  {0.0f, 0.0f}}, // bottom right
        {{-1.0f,  1.0f, 0.0f},  {0.0f, 1.0f}}, // bottom left
        {{-1.0f, -1.0f, 0.0f},  {1.0f, 1.0f}},  // top left
    }
};

struct VertexOut {
    float4 position [[position]];
    float2 tex_coord;
};

vertex VertexOut vertex_main(device const OrinetationInfo& orientation [[buffer(0)]],
                             uint vertexId [[vertex_id]]) {
    VertexOut out;
    out.position = float4(vertices[orientation.rot_index][vertexId].position, 1.0);
    out.tex_coord = vertices[orientation.rot_index][vertexId].tex_coord;
    return out;
}

fragment half4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float, access::sample> textureRGBA [[ texture(0) ]]) {
    constexpr sampler samplr(s_address::clamp_to_edge,
                             t_address::clamp_to_edge,
                             r_address::clamp_to_edge,
                             min_filter::linear,
                             mag_filter::linear
                             );
    return half4(textureRGBA.sample(samplr, in.tex_coord).bgra);
}

} // namespace BNBOEPShaders
