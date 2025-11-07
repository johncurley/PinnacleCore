#include <metal_stdlib>
using namespace metal;

struct VertexIn
{
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut
{
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 texCoords;
};

struct PBRMaterial
{
    float4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
};

struct Light
{
    float3 direction;
    float3 color;
    float intensity;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                              constant float4x4& viewProjectionMatrix [[buffer(0)]],
                              constant float4x4& modelMatrix [[buffer(1)]])
{
    VertexOut out;
    float4 worldPos = modelMatrix * float4(in.position, 1.0);
    out.position = viewProjectionMatrix * worldPos;
    out.worldPosition = worldPos.xyz;
    out.worldNormal = (modelMatrix * float4(in.normal, 0.0)).xyz;
    out.texCoords = in.texCoords;
    return out;
}

// PBR utility functions
float DistributionGGX(float NdotH, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH2 = NdotH * NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI_F * denom * denom;

    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float GeometrySmith(float NdotV, float NdotL, float roughness)
{
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

float3 FresnelSchlick(float3 F0, float HdotV)
{
    return F0 + (float3(1.0) - F0) * pow(1.0 - HdotV, 5.0);
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant PBRMaterial& pbrMaterial [[buffer(0)]],
                               constant float3& cameraPosition [[buffer(1)]],
                               constant Light* lights [[buffer(2)]],
                               constant uint& numLights [[buffer(3)]],
                               texture2d<float> baseColorTexture [[texture(0)]],
                               texture2d<float> metallicRoughnessTexture [[texture(1)]],
                               texture2d<float> normalTexture [[texture(2)]],
                               texture2d<float> occlusionTexture [[texture(3)]],
                               texture2d<float> emissiveTexture [[texture(4)]],
                               sampler s [[sampler(0)]])
{
    float3 N = normalize(in.worldNormal);
    float3 V = normalize(cameraPosition - in.worldPosition);

    // Material properties
    float4 baseColorTex = baseColorTexture.sample(s, in.texCoords);
    float3 albedo = baseColorTex.rgb * pbrMaterial.baseColorFactor.rgb;
    float alpha = baseColorTex.a * pbrMaterial.baseColorFactor.a;

    float metallic = pbrMaterial.metallicFactor;
    float roughness = pbrMaterial.roughnessFactor;

    float4 mrTex = metallicRoughnessTexture.sample(s, in.texCoords);
    metallic *= mrTex.b; // Blue channel for metallic
    roughness *= mrTex.g; // Green channel for roughness

    // Normal mapping
    // For now, just use the normal from the normal map directly if available
    // A proper TBN matrix calculation would be needed here.
    float3 normalSample = normalTexture.sample(s, in.texCoords).rgb;
    N = normalize(normalSample * 2.0 - 1.0); // Transform from [0,1] to [-1,1]

    float3 F0 = mix(float3(0.04), albedo, metallic);

    float3 Lo = float3(0.0);

    for (uint i = 0; i < numLights; ++i)
    {
        Light currentLight = lights[i];
        float3 lightDirection = normalize(currentLight.direction);
        float3 lightColor = currentLight.color * currentLight.intensity;

        float3 L = normalize(-lightDirection); // Light direction from fragment to light
        float3 H = normalize(V + L);

        float NdotL = saturate(dot(N, L));
        float NdotV = saturate(dot(N, V));
        float NdotH = saturate(dot(N, H));
        float HdotV = saturate(dot(H, V));

        float D = DistributionGGX(NdotH, roughness);
        float G = GeometrySmith(NdotV, NdotL, roughness);
        float3 F = FresnelSchlick(F0, HdotV);

        float3 numerator = D * G * F;
        float denominator = 4.0 * NdotV * NdotL + 0.0001; // Add epsilon to prevent division by zero
        float3 specular = numerator / denominator;

        float3 kS = F;
        float3 kD = float3(1.0) - kS;
        kD *= 1.0 - metallic;

        Lo += (kD * albedo / M_PI_F + specular) * lightColor * NdotL;
    }

    // Ambient occlusion
    float ao = occlusionTexture.sample(s, in.texCoords).r;
    Lo *= ao;

    // Emissive
    float3 emissiveColor = emissiveTexture.sample(s, in.texCoords).rgb;

    float3 finalColor = Lo + emissiveColor;

    return float4(finalColor, alpha);
}