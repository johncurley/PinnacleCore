#pragma once

#include <simd/simd.h>
#include <string>
#include <vector>
#include <memory>

namespace Pinnacle
{
    class Texture;

    struct PBRMaterial
    {
        simd_float4 baseColorFactor = {1.0f, 1.0f, 1.0f, 1.0f};
        float metallicFactor = 1.0f;
        float roughnessFactor = 1.0f;

        std::shared_ptr<Pinnacle::Texture> baseColorTexture;
        std::shared_ptr<Pinnacle::Texture> metallicRoughnessTexture;
        std::shared_ptr<Pinnacle::Texture> normalTexture;
        std::shared_ptr<Pinnacle::Texture> occlusionTexture;
        std::shared_ptr<Pinnacle::Texture> emissiveTexture;
    };

    class Material
    {
    public:
        Material();
        ~Material();

        PBRMaterial& getPBRMaterial() { return m_pbrMaterial; }
        const PBRMaterial& getPBRMaterial() const { return m_pbrMaterial; }

    private:
        PBRMaterial m_pbrMaterial;
    };
} // namespace Pinnacle
