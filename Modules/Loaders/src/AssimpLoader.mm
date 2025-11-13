#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "Loaders/AssimpLoader.hpp"
#include "Core/Mesh.hpp"
#include "Core/Material.hpp"
#include "Core/Texture.hpp"

// Assimp includes
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>

#include <iostream>

namespace Pinnacle
{
    AssimpLoader::AssimpLoader()
    {
    }

    AssimpLoader::~AssimpLoader()
    {
    }

    bool AssimpLoader::loadFromFile(id device,
                                     const std::string& path,
                                     std::vector<std::shared_ptr<Mesh>>& outMeshes,
                                     std::vector<std::shared_ptr<Material>>& outMaterials,
                                     std::vector<std::shared_ptr<Texture>>& outTextures)
    {
        Assimp::Importer importer;

        // Import flags for optimal processing
        unsigned int flags = aiProcess_Triangulate |           // Convert to triangles
                            aiProcess_GenNormals |             // Generate normals if missing
                            aiProcess_CalcTangentSpace |       // Calculate tangents for normal mapping
                            aiProcess_JoinIdenticalVertices |  // Optimize by merging identical vertices
                            aiProcess_FlipUVs;                 // Flip UVs for Metal (top-left origin)

        const aiScene* scene = importer.ReadFile(path, flags);

        if (!scene || scene->mFlags & AI_SCENE_FLAGS_INCOMPLETE || !scene->mRootNode)
        {
            m_lastError = std::string("Assimp Error: ") + importer.GetErrorString();
            std::cerr << m_lastError << std::endl;
            return false;
        }

        std::cout << "Successfully loaded with Assimp: " << path << std::endl;
        std::cout << "  Meshes: " << scene->mNumMeshes << std::endl;
        std::cout << "  Materials: " << scene->mNumMaterials << std::endl;

        // Get directory for texture loading
        std::string directory = path.substr(0, path.find_last_of('/') + 1);

        // Process materials first
        processMaterials(device, scene, directory, outMaterials, outTextures);

        // Process meshes
        processMeshes(device, scene, outMaterials, outMeshes);

        return true;
    }

    void AssimpLoader::processMaterials(id device,
                                        const aiScene* scene,
                                        const std::string& directory,
                                        std::vector<std::shared_ptr<Material>>& outMaterials,
                                        std::vector<std::shared_ptr<Texture>>& outTextures)
    {
        // Texture cache to avoid loading duplicates
        std::unordered_map<std::string, std::shared_ptr<Texture>> textureCache;

        for (unsigned int i = 0; i < scene->mNumMaterials; ++i)
        {
            const aiMaterial* assimpMat = scene->mMaterials[i];
            auto material = std::make_shared<Material>();

            // Get material name
            aiString name;
            if (assimpMat->Get(AI_MATKEY_NAME, name) == AI_SUCCESS)
            {
                material->setName(name.C_Str());
            }
            else
            {
                material->setName("Material_" + std::to_string(i));
            }

            auto& pbr = material->getPBRMaterial();

            // Base color
            aiColor3D diffuseColor(1.0f, 1.0f, 1.0f);
            assimpMat->Get(AI_MATKEY_COLOR_DIFFUSE, diffuseColor);
            pbr.baseColorFactor = simd_make_float4(diffuseColor.r, diffuseColor.g, diffuseColor.b, 1.0f);

            // Metallic (try PBR workflow first)
            float metallic = 0.0f;
            if (assimpMat->Get(AI_MATKEY_METALLIC_FACTOR, metallic) == AI_SUCCESS)
            {
                pbr.metallicFactor = metallic;
            }
            else
            {
                // Fallback: check if it's a specular material
                aiColor3D specular;
                if (assimpMat->Get(AI_MATKEY_COLOR_SPECULAR, specular) == AI_SUCCESS)
                {
                    // High specular = low roughness, but not necessarily metallic
                    float specularIntensity = (specular.r + specular.g + specular.b) / 3.0f;
                    pbr.metallicFactor = 0.0f;  // Assume non-metallic for legacy materials
                    pbr.roughnessFactor = 1.0f - specularIntensity;
                }
            }

            // Roughness
            float roughness = 0.5f;
            if (assimpMat->Get(AI_MATKEY_ROUGHNESS_FACTOR, roughness) == AI_SUCCESS)
            {
                pbr.roughnessFactor = roughness;
            }
            else
            {
                // Fallback: use shininess to estimate roughness
                float shininess = 0.0f;
                if (assimpMat->Get(AI_MATKEY_SHININESS, shininess) == AI_SUCCESS)
                {
                    // Convert Phong shininess (0-128) to roughness (0-1)
                    pbr.roughnessFactor = 1.0f - (shininess / 128.0f);
                }
            }

            // Emissive color
            aiColor3D emissive(0.0f, 0.0f, 0.0f);
            assimpMat->Get(AI_MATKEY_COLOR_EMISSIVE, emissive);
            pbr.emissiveFactor = simd_make_float3(emissive.r, emissive.g, emissive.b);

            // Load textures
            auto loadTextureType = [&](aiTextureType type, int& outIndex) {
                if (assimpMat->GetTextureCount(type) > 0)
                {
                    aiString texPath;
                    if (assimpMat->GetTexture(type, 0, &texPath) == AI_SUCCESS)
                    {
                        std::string texPathStr = texPath.C_Str();

                        // Check cache first
                        if (textureCache.find(texPathStr) == textureCache.end())
                        {
                            auto texture = loadTexture(device, texPathStr, directory);
                            if (texture)
                            {
                                textureCache[texPathStr] = texture;
                                outTextures.push_back(texture);
                            }
                        }

                        // Find texture index
                        auto it = std::find(outTextures.begin(), outTextures.end(), textureCache[texPathStr]);
                        if (it != outTextures.end())
                        {
                            outIndex = (int)std::distance(outTextures.begin(), it);
                        }
                    }
                }
            };

            // Load different texture types
            loadTextureType(aiTextureType_DIFFUSE, pbr.baseColorTexture);          // Base color
            loadTextureType(aiTextureType_METALNESS, pbr.metallicRoughnessTexture); // Metallic
            loadTextureType(aiTextureType_NORMALS, pbr.normalTexture);             // Normal map
            loadTextureType(aiTextureType_AMBIENT_OCCLUSION, pbr.occlusionTexture); // AO
            loadTextureType(aiTextureType_EMISSIVE, pbr.emissiveTexture);          // Emissive

            // If metallic-roughness texture not found, try separate textures
            if (pbr.metallicRoughnessTexture == -1)
            {
                loadTextureType(aiTextureType_DIFFUSE_ROUGHNESS, pbr.metallicRoughnessTexture);
            }

            outMaterials.push_back(material);
        }
    }

    void AssimpLoader::processMeshes(id device,
                                     const aiScene* scene,
                                     const std::vector<std::shared_ptr<Material>>& materials,
                                     std::vector<std::shared_ptr<Mesh>>& outMeshes)
    {
        for (unsigned int i = 0; i < scene->mNumMeshes; ++i)
        {
            const aiMesh* assimpMesh = scene->mMeshes[i];
            auto mesh = convertMesh(device, assimpMesh, materials);
            if (mesh)
            {
                outMeshes.push_back(mesh);
            }
        }
    }

    std::shared_ptr<Mesh> AssimpLoader::convertMesh(id device,
                                                      const aiMesh* assimpMesh,
                                                      const std::vector<std::shared_ptr<Material>>& materials)
    {
        // Prepare vertex data
        std::vector<Vertex> vertices;
        vertices.reserve(assimpMesh->mNumVertices);

        for (unsigned int i = 0; i < assimpMesh->mNumVertices; ++i)
        {
            Vertex vertex;

            // Position
            vertex.position = simd_make_float3(
                assimpMesh->mVertices[i].x,
                assimpMesh->mVertices[i].y,
                assimpMesh->mVertices[i].z
            );

            // Normal
            if (assimpMesh->HasNormals())
            {
                vertex.normal = simd_make_float3(
                    assimpMesh->mNormals[i].x,
                    assimpMesh->mNormals[i].y,
                    assimpMesh->mNormals[i].z
                );
            }
            else
            {
                vertex.normal = simd_make_float3(0.0f, 1.0f, 0.0f);
            }

            // Texture coordinates
            if (assimpMesh->HasTextureCoords(0))
            {
                vertex.texCoord = simd_make_float2(
                    assimpMesh->mTextureCoords[0][i].x,
                    assimpMesh->mTextureCoords[0][i].y
                );
            }
            else
            {
                vertex.texCoord = simd_make_float2(0.0f, 0.0f);
            }

            // Tangent
            if (assimpMesh->HasTangentsAndBitangents())
            {
                vertex.tangent = simd_make_float3(
                    assimpMesh->mTangents[i].x,
                    assimpMesh->mTangents[i].y,
                    assimpMesh->mTangents[i].z
                );
            }
            else
            {
                vertex.tangent = simd_make_float3(1.0f, 0.0f, 0.0f);
            }

            vertices.push_back(vertex);
        }

        // Prepare index data
        std::vector<uint32_t> indices;
        for (unsigned int i = 0; i < assimpMesh->mNumFaces; ++i)
        {
            const aiFace& face = assimpMesh->mFaces[i];
            for (unsigned int j = 0; j < face.mNumIndices; ++j)
            {
                indices.push_back(face.mIndices[j]);
            }
        }

        // Get material index
        int materialIndex = -1;
        if (assimpMesh->mMaterialIndex < materials.size())
        {
            materialIndex = assimpMesh->mMaterialIndex;
        }

        // Create mesh name
        std::string meshName = assimpMesh->mName.C_Str();
        if (meshName.empty())
        {
            meshName = "Mesh";
        }

        // Create Metal buffers
        id<MTLDevice> mtlDevice = (id<MTLDevice>)device;

        id<MTLBuffer> vertexBuffer = [mtlDevice newBufferWithBytes:vertices.data()
                                                           length:vertices.size() * sizeof(Vertex)
                                                          options:MTLResourceStorageModeShared];

        id<MTLBuffer> indexBuffer = [mtlDevice newBufferWithBytes:indices.data()
                                                          length:indices.size() * sizeof(uint32_t)
                                                         options:MTLResourceStorageModeShared];

        auto mesh = std::make_shared<Mesh>(
            (void*)vertexBuffer,
            (void*)indexBuffer,
            (uint32_t)indices.size(),
            meshName,
            vertices.size()
        );

        if (materialIndex >= 0)
        {
            mesh->setMaterialIndex(materialIndex);
        }

        return mesh;
    }

    std::shared_ptr<Texture> AssimpLoader::loadTexture(id device,
                                                         const std::string& path,
                                                         const std::string& directory)
    {
        std::string fullPath = directory + path;

        // Check if file exists
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:[NSString stringWithUTF8String:fullPath.c_str()]])
        {
            std::cerr << "Texture not found: " << fullPath << std::endl;
            return nullptr;
        }

        auto texture = std::make_shared<Texture>(device, fullPath);
        return texture;
    }

} // namespace Pinnacle
