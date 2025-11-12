#pragma once

#include <simd/simd.h>
#include <vector>
#include <memory>

// Forward declarations for Metal types
namespace MTL
{
    class Device;
    class Buffer;
}

namespace NS
{
    using UInteger = unsigned long;
}

namespace Pinnacle
{
    class Material;

    struct Vertex
    {
        simd_float3 position;
        simd_float3 normal;
        simd_float2 texCoords;
    };

    class Mesh
    {
    public:
        Mesh(MTL::Device* pDevice, const std::vector<Vertex>& vertices, const std::vector<uint16_t>& indices, std::shared_ptr<Pinnacle::Material> pMaterial);
        ~Mesh();

        MTL::Buffer* getVertexBuffer() const { return m_pVertexBuffer; }
        MTL::Buffer* getIndexBuffer() const { return m_pIndexBuffer; }
        NS::UInteger getIndexCount() const { return m_indexCount; }
        std::shared_ptr<Pinnacle::Material> getMaterial() const { return m_pMaterial; }

    private:
        MTL::Buffer* m_pVertexBuffer;
        MTL::Buffer* m_pIndexBuffer;
        NS::UInteger m_indexCount;
        std::shared_ptr<Pinnacle::Material> m_pMaterial;
    };
} // namespace Pinnacle
