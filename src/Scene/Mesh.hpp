#pragma once

#include <simd/simd.h>
#include <vector>
#include <memory>

#ifdef __OBJC__
#import <Metal/Metal.h>
#else
typedef void* id;
#endif

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
        Mesh(id device, const std::vector<Vertex>& vertices, const std::vector<uint32_t>& indices, std::shared_ptr<Pinnacle::Material> pMaterial);
        ~Mesh();

        id getVertexBuffer() const { return m_pVertexBuffer; }
        id getIndexBuffer() const { return m_pIndexBuffer; }
        size_t getIndexCount() const { return m_indexCount; }
        std::shared_ptr<Pinnacle::Material> getMaterial() const { return m_pMaterial; }

    private:
        id m_pVertexBuffer; // id<MTLBuffer>
        id m_pIndexBuffer; // id<MTLBuffer>
        size_t m_indexCount;
        std::shared_ptr<Pinnacle::Material> m_pMaterial;
    };
} // namespace Pinnacle
