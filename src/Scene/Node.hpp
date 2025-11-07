#pragma once

#include "Mesh.hpp"

#include <simd/simd.h>
#include <vector>
#include <memory>

namespace Scene
{
    class Node
    {
    public:
        Node();
        ~Node();

        void setTransformation(const simd_float4x4& transformation);
        const simd_float4x4& getTransformation() const;

        void addMesh(const std::shared_ptr<Mesh>& mesh);
        const std::vector<std::shared_ptr<Mesh>>& getMeshes() const;

    private:
        simd_float4x4 m_transformation;
        std::vector<std::shared_ptr<Mesh>> m_meshes;
    };
} // namespace Scene
