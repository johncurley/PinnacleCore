#include <metal_stdlib>
using namespace metal;

// Vertex structure matching the C++ Vertex struct
struct Vertex {
    float3 position;
    float3 normal;
    float2 texCoords;
};

// Uniforms for transformation matrices
struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 cameraPosition;
};

// PBR Material properties
struct MaterialUniforms {
    float4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    int hasBaseColorTexture;
    int hasMetallicRoughnessTexture;
    int hasNormalTexture;
};

// Light properties
struct Light {
    float3 direction;
    float3 color;
    float intensity;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoords;
};

// Vertex shader
vertex VertexOut vertexShader(device const Vertex* vertices [[buffer(0)]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              unsigned int vertexId [[vertex_id]]) {
    VertexOut out;

    Vertex v = vertices[vertexId];

    // Transform position
    float4 worldPos = uniforms.modelMatrix * float4(v.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;

    // Transform normal
    float3x3 normalMatrix = float3x3(uniforms.modelMatrix[0].xyz,
                                      uniforms.modelMatrix[1].xyz,
                                      uniforms.modelMatrix[2].xyz);
    out.normal = normalize(normalMatrix * v.normal);

    out.texCoords = v.texCoords;

    return out;
}

// PBR Functions
float distributionGGX(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159265359 * denom * denom;

    return nom / denom;
}

float geometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float geometrySmith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometrySchlickGGX(NdotV, roughness);
    float ggx1 = geometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// Fragment shader with PBR
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant MaterialUniforms& material [[buffer(0)]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              constant Light& light [[buffer(2)]],
                              texture2d<float> baseColorTexture [[texture(0)]]) {

    // Sample base color
    float4 baseColor = material.baseColorFactor;

    if (material.hasBaseColorTexture && !is_null_texture(baseColorTexture)) {
        constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
        baseColor *= baseColorTexture.sample(textureSampler, in.texCoords);
    }

    // Normalize interpolated normal
    float3 N = normalize(in.normal);
    float3 V = normalize(uniforms.cameraPosition - in.worldPosition);

    // Calculate reflectance at normal incidence
    float3 F0 = float3(0.04);
    F0 = mix(F0, baseColor.rgb, material.metallicFactor);

    // Light calculation
    float3 L = normalize(-light.direction);
    float3 H = normalize(V + L);

    float3 radiance = light.color * light.intensity;

    // Cook-Torrance BRDF
    float NDF = distributionGGX(N, H, material.roughnessFactor);
    float G = geometrySmith(N, V, L, material.roughnessFactor);
    float3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);

    float3 kS = F;
    float3 kD = (1.0 - kS) * (1.0 - material.metallicFactor);

    float3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.001;
    float3 specular = numerator / denominator;

    float NdotL = max(dot(N, L), 0.0);
    float3 Lo = (kD * baseColor.rgb / 3.14159265359 + specular) * radiance * NdotL;

    // Ambient lighting
    float3 ambient = float3(0.03) * baseColor.rgb;

    float3 color = ambient + Lo;

    // HDR tonemapping
    color = color / (color + float3(1.0));

    // Gamma correction
    color = pow(color, float3(1.0/2.2));

    return float4(color, baseColor.a);
}