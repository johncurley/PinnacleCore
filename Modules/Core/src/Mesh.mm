#import <Metal/Metal.h>
#include "Mesh.hpp"
#include "Material.hpp"

namespace Pinnacle
{
    Mesh::Mesh(id device, const std::vector<Vertex>& vertices, const std::vector<uint32_t>& indices, std::shared_ptr<Pinnacle::Material> pMaterial)
        : m_pVertexBuffer(nil), m_pIndexBuffer(nil), m_indexCount(indices.size()), m_vertexCount(vertices.size()), m_pMaterial(pMaterial)
    {
        id<MTLDevice> mtlDevice = (id<MTLDevice>)device;

        // Create vertex buffer
        if (!vertices.empty()) {
            m_pVertexBuffer = [mtlDevice newBufferWithBytes:vertices.data()
                                                     length:vertices.size() * sizeof(Vertex)
                                                    options:MTLResourceStorageModeShared];
        }

        // Create index buffer
        if (!indices.empty()) {
            m_pIndexBuffer = [mtlDevice newBufferWithBytes:indices.data()
                                                    length:indices.size() * sizeof(uint32_t)
                                                   options:MTLResourceStorageModeShared];
        }
    }

    Mesh::~Mesh()
    {
        if (m_pVertexBuffer) {
            id<MTLBuffer> buffer = (id<MTLBuffer>)m_pVertexBuffer;
            [buffer release];
            m_pVertexBuffer = nil;
        }

        if (m_pIndexBuffer) {
            id<MTLBuffer> buffer = (id<MTLBuffer>)m_pIndexBuffer;
            [buffer release];
            m_pIndexBuffer = nil;
        }
    }
} // namespace Pinnacle
