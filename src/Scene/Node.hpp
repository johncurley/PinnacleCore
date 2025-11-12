#pragma once

#include "Mesh.hpp"

#include <simd/simd.h>
#include <vector>
#include <memory>

namespace Pinnacle
{
    class Node
    {
    public:
        Node();
        ~Node();

        void setTransformation(const simd_float4x4& transformation);
        const simd_float4x4& getTransformation() const;

        void addMesh(const std::shared_ptr<Pinnacle::Mesh>& mesh);
        const std::vector<std::shared_ptr<Pinnacle::Mesh>>& getMeshes() const;

    private:
        simd_float4x4 m_transformation;
        std::vector<std::shared_ptr<Pinnacle::Mesh>> m_meshes;
    };
} // namespace Pinnacle
