#include "Mesh.hpp"
#include "Material.hpp"

#include <Metal/Metal.hpp>

namespace Scene
{
    Mesh::Mesh(MTL::Device* pDevice, const std::vector<Vertex>& vertices, const std::vector<uint16_t>& indices, std::shared_ptr<Material> pMaterial)
    :   m_pVertexBuffer(nullptr),
        m_pIndexBuffer(nullptr),
        m_indexCount(0),
        m_pMaterial(pMaterial)
    {
        m_pVertexBuffer = pDevice->newBuffer(vertices.data(), vertices.size() * sizeof(Vertex), MTL::ResourceOptionCPUCacheModeWriteCombined);
        m_pIndexBuffer = pDevice->newBuffer(indices.data(), indices.size() * sizeof(uint16_t), MTL::ResourceOptionCPUCacheModeWriteCombined);
        m_indexCount = indices.size();
    }

    Mesh::~Mesh()
    {
        m_pVertexBuffer->release();
        m_pIndexBuffer->release();
    }
} // namespace Scene
