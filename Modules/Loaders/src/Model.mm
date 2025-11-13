#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "Loaders/Model.hpp"
#include "Core/Mesh.hpp"
#include "Core/Material.hpp"
#include "Core/Texture.hpp"
#include "Loaders/AssimpLoader.hpp"

#define TINYGLTF_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "tiny_gltf.h"

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

        // Use Assimp for FBX and OBJ files
        if (ext == "fbx" || ext == "obj") {
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

        // Use tinygltf for glTF/GLB files
        tinygltf::TinyGLTF loader;
        tinygltf::Model gltfModel;
        std::string err;
        std::string warn;

        bool isBinary = (ext == "glb");

        // Load based on format
        bool res = false;
        if (isBinary) {
            res = loader.LoadBinaryFromFile(&gltfModel, &err, &warn, path);
        } else {
            res = loader.LoadASCIIFromFile(&gltfModel, &err, &warn, path);
        }

        if (!warn.empty()) {
            std::cout << "glTF Warning: " << warn << std::endl;
        }

        if (!err.empty()) {
            std::cerr << "glTF Error: " << err << std::endl;
        }

        if (!res) {
            std::cerr << "Failed to load " << (isBinary ? "GLB" : "glTF") << ": " << path << std::endl;
            return;
        }

        std::cout << "Successfully loaded " << (isBinary ? "GLB" : "glTF") << ": " << path << std::endl;

        // Get the directory path for loading textures
        std::string directory = path.substr(0, path.find_last_of('/') + 1);

        // Load textures
        m_textures.resize(gltfModel.textures.size());
        for (size_t i = 0; i < gltfModel.textures.size(); ++i) {
            const tinygltf::Texture& gltfTexture = gltfModel.textures[i];
            if (gltfTexture.source >= 0 && gltfTexture.source < gltfModel.images.size()) {
                const tinygltf::Image& image = gltfModel.images[gltfTexture.source];

                if (image.image.empty()) {
                    // Image is from file
                    std::string imagePath = directory + image.uri;
                    m_textures[i] = std::make_shared<Texture>(device, imagePath);
                } else {
                    // Image is embedded
                    m_textures[i] = std::make_shared<Texture>(
                        device,
                        image.image.data(),
                        image.width,
                        image.height,
                        image.component
                    );
                }
            }
        }

        // Load materials
        m_materials.resize(gltfModel.materials.size());
        for (size_t i = 0; i < gltfModel.materials.size(); ++i) {
            const tinygltf::Material& gltfMaterial = gltfModel.materials[i];
            auto material = std::make_shared<Material>();

            PBRMaterial& pbr = material->getPBRMaterial();

            // Base color factor
            if (gltfMaterial.pbrMetallicRoughness.baseColorFactor.size() == 4) {
                pbr.baseColorFactor = {
                    (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[0],
                    (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[1],
                    (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[2],
                    (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[3]
                };
            }

            // Metallic and roughness factors
            pbr.metallicFactor = (float)gltfMaterial.pbrMetallicRoughness.metallicFactor;
            pbr.roughnessFactor = (float)gltfMaterial.pbrMetallicRoughness.roughnessFactor;

            // Base color texture
            int baseColorTexIndex = gltfMaterial.pbrMetallicRoughness.baseColorTexture.index;
            if (baseColorTexIndex >= 0 && baseColorTexIndex < m_textures.size()) {
                pbr.baseColorTexture = m_textures[baseColorTexIndex];
            }

            // Metallic roughness texture
            int metallicRoughnessTexIndex = gltfMaterial.pbrMetallicRoughness.metallicRoughnessTexture.index;
            if (metallicRoughnessTexIndex >= 0 && metallicRoughnessTexIndex < m_textures.size()) {
                pbr.metallicRoughnessTexture = m_textures[metallicRoughnessTexIndex];
            }

            // Normal texture
            int normalTexIndex = gltfMaterial.normalTexture.index;
            if (normalTexIndex >= 0 && normalTexIndex < m_textures.size()) {
                pbr.normalTexture = m_textures[normalTexIndex];
            }

            // Occlusion texture
            int occlusionTexIndex = gltfMaterial.occlusionTexture.index;
            if (occlusionTexIndex >= 0 && occlusionTexIndex < m_textures.size()) {
                pbr.occlusionTexture = m_textures[occlusionTexIndex];
            }

            // Emissive texture
            int emissiveTexIndex = gltfMaterial.emissiveTexture.index;
            if (emissiveTexIndex >= 0 && emissiveTexIndex < m_textures.size()) {
                pbr.emissiveTexture = m_textures[emissiveTexIndex];
            }

            m_materials[i] = material;
        }

        // Load meshes
        for (const auto& gltfMesh : gltfModel.meshes) {
            for (const auto& primitive : gltfMesh.primitives) {
                std::vector<Vertex> vertices;
                std::vector<uint32_t> indices;

                // Get position accessor
                auto posIter = primitive.attributes.find("POSITION");
                if (posIter == primitive.attributes.end()) {
                    continue; // Skip if no positions
                }

                const tinygltf::Accessor& posAccessor = gltfModel.accessors[posIter->second];
                const tinygltf::BufferView& posBufferView = gltfModel.bufferViews[posAccessor.bufferView];
                const tinygltf::Buffer& posBuffer = gltfModel.buffers[posBufferView.buffer];
                const float* positions = reinterpret_cast<const float*>(
                    posBuffer.data.data() + posBufferView.byteOffset + posAccessor.byteOffset
                );

                // Get normal accessor (optional)
                const float* normals = nullptr;
                auto normIter = primitive.attributes.find("NORMAL");
                if (normIter != primitive.attributes.end()) {
                    const tinygltf::Accessor& normAccessor = gltfModel.accessors[normIter->second];
                    const tinygltf::BufferView& normBufferView = gltfModel.bufferViews[normAccessor.bufferView];
                    const tinygltf::Buffer& normBuffer = gltfModel.buffers[normBufferView.buffer];
                    normals = reinterpret_cast<const float*>(
                        normBuffer.data.data() + normBufferView.byteOffset + normAccessor.byteOffset
                    );
                }

                // Get texture coordinate accessor (optional)
                const float* texCoords = nullptr;
                auto texCoordIter = primitive.attributes.find("TEXCOORD_0");
                if (texCoordIter != primitive.attributes.end()) {
                    const tinygltf::Accessor& texCoordAccessor = gltfModel.accessors[texCoordIter->second];
                    const tinygltf::BufferView& texCoordBufferView = gltfModel.bufferViews[texCoordAccessor.bufferView];
                    const tinygltf::Buffer& texCoordBuffer = gltfModel.buffers[texCoordBufferView.buffer];
                    texCoords = reinterpret_cast<const float*>(
                        texCoordBuffer.data.data() + texCoordBufferView.byteOffset + texCoordAccessor.byteOffset
                    );
                }

                // Build vertices
                vertices.resize(posAccessor.count);
                for (size_t i = 0; i < posAccessor.count; ++i) {
                    Vertex vertex;

                    // Position
                    vertex.position = {
                        positions[i * 3 + 0],
                        positions[i * 3 + 1],
                        positions[i * 3 + 2]
                    };

                    // Normal
                    if (normals) {
                        vertex.normal = {
                            normals[i * 3 + 0],
                            normals[i * 3 + 1],
                            normals[i * 3 + 2]
                        };
                    } else {
                        vertex.normal = {0.0f, 1.0f, 0.0f}; // Default up
                    }

                    // Texture coordinates
                    if (texCoords) {
                        vertex.texCoords = {
                            texCoords[i * 2 + 0],
                            texCoords[i * 2 + 1]
                        };
                    } else {
                        vertex.texCoords = {0.0f, 0.0f};
                    }

                    vertices[i] = vertex;
                }

                // Get indices
                if (primitive.indices >= 0) {
                    const tinygltf::Accessor& indexAccessor = gltfModel.accessors[primitive.indices];
                    const tinygltf::BufferView& indexBufferView = gltfModel.bufferViews[indexAccessor.bufferView];
                    const tinygltf::Buffer& indexBuffer = gltfModel.buffers[indexBufferView.buffer];
                    const unsigned char* indexData = indexBuffer.data.data() + indexBufferView.byteOffset + indexAccessor.byteOffset;

                    indices.resize(indexAccessor.count);

                    if (indexAccessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_SHORT) {
                        const uint16_t* indices16 = reinterpret_cast<const uint16_t*>(indexData);
                        for (size_t i = 0; i < indexAccessor.count; ++i) {
                            indices[i] = indices16[i];
                        }
                    } else if (indexAccessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_INT) {
                        const uint32_t* indices32 = reinterpret_cast<const uint32_t*>(indexData);
                        for (size_t i = 0; i < indexAccessor.count; ++i) {
                            indices[i] = indices32[i];
                        }
                    }
                }

                // Get material
                std::shared_ptr<Material> material;
                if (primitive.material >= 0 && primitive.material < m_materials.size()) {
                    material = m_materials[primitive.material];
                } else {
                    material = std::make_shared<Material>(); // Default material
                }

                // Create mesh
                auto mesh = std::make_shared<Mesh>(device, vertices, indices, material);
                m_meshes.push_back(mesh);
            }
        }

        std::cout << "Loaded " << m_meshes.size() << " meshes, "
                  << m_materials.size() << " materials, "
                  << m_textures.size() << " textures" << std::endl;
    }
} // namespace Pinnacle
