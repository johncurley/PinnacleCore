#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4 modelColor;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertexShader(device const float3* positions [[buffer(0)]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              unsigned int vertexId [[vertex_id]]) {
    VertexOut out;
    out.position = float4(positions[vertexId], 1.0);
    out.color = uniforms.modelColor;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}