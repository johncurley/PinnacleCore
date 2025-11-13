#pragma once

#include "Mesh.hpp"
#include "Texture.hpp"
#include "Material.hpp"

#include <vector>
#include <string>
#include <memory>

#ifdef __OBJC__
#import <Metal/Metal.h>
#else
typedef void* id;
#endif

namespace Pinnacle
{
    class Model
    {
    public:
        Model(id device, const std::string& path);
        ~Model();

        const std::vector<std::shared_ptr<Mesh>>& getMeshes() const { return m_meshes; }
        const std::vector<std::shared_ptr<Material>>& getMaterials() const { return m_materials; }

    private:
        void loadModel(id device, const std::string& path);

        std::vector<std::shared_ptr<Mesh>> m_meshes;
        std::vector<std::shared_ptr<Texture>> m_textures;
        std::vector<std::shared_ptr<Material>> m_materials;
    };
} // namespace Pinnacle
