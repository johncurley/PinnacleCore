#include "Node.hpp"

namespace Scene
{
    Node::Node()
    {
        m_transformation = matrix_identity_float4x4;
    }

    Node::~Node()
    {
    }

    void Node::setTransformation(const simd_float4x4& transformation)
    {
        m_transformation = transformation;
    }

    const simd_float4x4& Node::getTransformation() const
    {
        return m_transformation;
    }

    void Node::addMesh(const std::shared_ptr<Mesh>& mesh)
    {
        m_meshes.push_back(mesh);
    }

    const std::vector<std::shared_ptr<Mesh>>& Node::getMeshes() const
    {
        return m_meshes;
    }
} // namespace Scene
