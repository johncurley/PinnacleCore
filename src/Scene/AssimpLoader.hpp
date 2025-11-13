#pragma once

#include <string>
#include <vector>
#include <memory>

#ifdef __OBJC__
#import <Metal/Metal.h>
#else
typedef void* id;
#endif

namespace Pinnacle
{
    // Forward declarations
    class Mesh;
    class Material;
    class Texture;

    class AssimpLoader
    {
    public:
        AssimpLoader();
        ~AssimpLoader();

        // Load FBX/OBJ files using Assimp
        bool loadFromFile(id device,
                         const std::string& path,
                         std::vector<std::shared_ptr<Mesh>>& outMeshes,
                         std::vector<std::shared_ptr<Material>>& outMaterials,
                         std::vector<std::shared_ptr<Texture>>& outTextures);

        // Get last error message
        std::string getLastError() const { return m_lastError; }

    private:
        std::string m_lastError;

        // Helper methods for conversion
        void processMaterials(id device,
                            const struct aiScene* scene,
                            const std::string& directory,
                            std::vector<std::shared_ptr<Material>>& outMaterials,
                            std::vector<std::shared_ptr<Texture>>& outTextures);

        void processMeshes(id device,
                          const struct aiScene* scene,
                          const std::vector<std::shared_ptr<Material>>& materials,
                          std::vector<std::shared_ptr<Mesh>>& outMeshes);

        std::shared_ptr<Mesh> convertMesh(id device,
                                          const struct aiMesh* assimpMesh,
                                          const std::vector<std::shared_ptr<Material>>& materials);

        std::shared_ptr<Texture> loadTexture(id device,
                                             const std::string& path,
                                             const std::string& directory);
    };

} // namespace Pinnacle
