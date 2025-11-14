#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "Model.hpp"
#include "Mesh.hpp"
#include "Material.hpp"
#include "Texture.hpp"
#include "AssimpLoader.hpp"

#include <iostream>

namespace Pinnacle
{
    Model::Model(id device, const std::string& path)
    {
        loadModel(device, path);
    }

    Model::~Model()
    {
        // Smart pointers will handle cleanup
    }

    void Model::loadModel(id device, const std::string& path)
    {
        // Detect file format by extension
        std::string ext;
        size_t dotPos = path.find_last_of('.');
        if (dotPos != std::string::npos) {
            ext = path.substr(dotPos + 1);
            // Convert to lowercase
            for (char& c : ext) {
                c = std::tolower(c);
            }
        }

        // Use Assimp for all supported formats (FBX, OBJ, glTF, GLB, etc.)
        AssimpLoader assimpLoader;
        if (assimpLoader.loadFromFile(device, path, m_meshes, m_materials, m_textures)) {
            std::cout << "Successfully loaded " << ext << " file: " << path << std::endl;
            return;
        } else {
            std::cerr << "Failed to load " << ext << " file: " << path << std::endl;
            std::cerr << "Error: " << assimpLoader.getLastError() << std::endl;
            return;
        }
    }
} // namespace Pinnacle
