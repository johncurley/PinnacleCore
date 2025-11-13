#include "Node.hpp"

namespace Pinnacle
{
    Node::Node()
    {
        // Initialize transformation to identity matrix
        m_transformation = simd_matrix4x4((simd_float4){1, 0, 0, 0},
                                         (simd_float4){0, 1, 0, 0},
                                         (simd_float4){0, 0, 1, 0},
                                         (simd_float4){0, 0, 0, 1});
    }

    Node::~Node()
    {
        // Smart pointers will handle cleanup
    }

    void Node::setTransformation(const simd_float4x4& transformation)
    {
        m_transformation = transformation;
    }

    const simd_float4x4& Node::getTransformation() const
    {
        return m_transformation;
    }

    void Node::addMesh(const std::shared_ptr<Pinnacle::Mesh>& mesh)
    {
        m_meshes.push_back(mesh);
    }

    const std::vector<std::shared_ptr<Pinnacle::Mesh>>& Node::getMeshes() const
    {
        return m_meshes;
    }
} // namespace Pinnacle
