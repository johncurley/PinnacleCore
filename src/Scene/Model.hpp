#pragma once

#include "Node.hpp"
#include "Texture.hpp"
#include "Material.hpp"
#include "tiny_gltf.h"

#include <vector>
#include <string>
#include <memory>

// Forward declarations for Metal types
namespace MTL
{
    class Device;
}

namespace Pinnacle
{
    class Model
    {
    public:
        Model(MTL::Device* pDevice, const std::string& path);
        ~Model();

        const std::vector<std::shared_ptr<Node>>& getNodes() const { return m_nodes; }
        const std::vector<std::shared_ptr<Material>>& getMaterials() const { return m_materials; }

    private:
        void loadModel(MTL::Device* pDevice, const std::string& path);

        std::vector<std::shared_ptr<Node>> m_nodes;
        std::vector<std::shared_ptr<Texture>> m_textures;
        std::vector<std::shared_ptr<Material>> m_materials;
        std::unique_ptr<tinygltf::Model> m_gltfModel;
        std::shared_ptr<Texture> m_pDefaultTexture;
    };
} // namespace Pinnacle
