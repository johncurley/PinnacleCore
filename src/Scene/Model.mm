#include "Model.hpp"
#include "Node.hpp"
#include "Math.hpp"
#include "../../libs/tiny_gltf.h"

#include <Metal/Metal.hpp>

#include <iostream>
#include <vector>

namespace Scene
{
    // Helper to get data from a glTF accessor
    template<typename T>
    std::vector<T> getAccessorData(const tinygltf::Model& model, const tinygltf::Accessor& accessor)
    {
        std::vector<T> data;
        const tinygltf::BufferView& bufferView = model.bufferViews[accessor.bufferView];
        const tinygltf::Buffer& buffer = model.buffers[bufferView.buffer];

        size_t byteOffset = accessor.byteOffset + bufferView.byteOffset;
        size_t byteLength = accessor.count * tinygltf::GetComponentSizeInBytes(static_cast<uint32_t>(accessor.componentType)) * tinygltf::GetNumComponentsInType(static_cast<uint32_t>(accessor.type));

        data.resize(accessor.count * tinygltf::GetNumComponentsInType(static_cast<uint32_t>(accessor.type)) / (sizeof(T) / tinygltf::GetComponentSizeInBytes(static_cast<uint32_t>(accessor.componentType))));
        memcpy(data.data(), buffer.data.data() + byteOffset, byteLength);

        return data;
    }

    Model::Model(MTL::Device* pDevice, const std::string& path)
    {
        loadModel(pDevice, path);
    }

    Model::~Model()
    {
    }

    void Model::loadModel(MTL::Device* pDevice, const std::string& path)
    {
        tinygltf::Model gltfModel;
        tinygltf::TinyGLTF loader;
        std::string err;
        std::string warn;

        bool ret = loader.LoadASCIIFromFile(&gltfModel, &err, &warn, path);
        if (!warn.empty())
        {
            std::cout << "WARN: " << warn << std::endl;
        }

        if (!err.empty())
        {
            std::cerr << "ERR: " << err << std::endl;
        }

        if (!ret)
        {
            std::cerr << "Failed to load glTF: " << path << std::endl;
            return;
        }

        // Load textures
        for (const auto& gltfImage : gltfModel.images)
        {
            // Assuming image data is embedded for simplicity for now
            if (!gltfImage.image.empty())
            {
                m_textures.push_back(std::make_shared<Texture>(pDevice, gltfImage.image.data(), gltfImage.width, gltfImage.height, gltfImage.component));
            }
            else
            {
                std::cerr << "Warning: glTF image not embedded or URI not supported yet: " << gltfImage.uri << std::endl;
                m_textures.push_back(nullptr); // Placeholder for failed texture load
            }
        }

        // Load materials
        for (const auto& gltfMaterial : gltfModel.materials)
        {
            std::shared_ptr<Material> pMaterial = std::make_shared<Material>();
            pMaterial->getPBRMaterial().baseColorFactor = {
                (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[0],
                (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[1],
                (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[2],
                (float)gltfMaterial.pbrMetallicRoughness.baseColorFactor[3]
            };
            pMaterial->getPBRMaterial().metallicFactor = (float)gltfMaterial.pbrMetallicRoughness.metallicFactor;
            pMaterial->getPBRMaterial().roughnessFactor = (float)gltfMaterial.pbrMetallicRoughness.roughnessFactor;

            if (gltfMaterial.pbrMetallicRoughness.baseColorTexture.index > -1)
            {
                pMaterial->getPBRMaterial().baseColorTexture = m_textures[gltfModel.textures[gltfMaterial.pbrMetallicRoughness.baseColorTexture.index].source];
            }
            if (gltfMaterial.pbrMetallicRoughness.metallicRoughnessTexture.index > -1)
            {
                pMaterial->getPBRMaterial().metallicRoughnessTexture = m_textures[gltfModel.textures[gltfMaterial.pbrMetallicRoughness.metallicRoughnessTexture.index].source];
            }
            if (gltfMaterial.normalTexture.index > -1)
            {
                pMaterial->getPBRMaterial().normalTexture = m_textures[gltfModel.textures[gltfMaterial.normalTexture.index].source];
            }
            if (gltfMaterial.occlusionTexture.index > -1)
            {
                pMaterial->getPBRMaterial().occlusionTexture = m_textures[gltfModel.textures[gltfMaterial.occlusionTexture.index].source];
            }
            if (gltfMaterial.emissiveTexture.index > -1)
            {
                pMaterial->getPBRMaterial().emissiveTexture = m_textures[gltfModel.textures[gltfMaterial.emissiveTexture.index].source];
            }
            m_materials.push_back(pMaterial);
        }

        for (const auto& node : gltfModel.nodes)
        {
            auto pNode = std::make_shared<Node>();

            // Process transformation
            if (node.matrix.size() == 16)
            {
                pNode->setTransformation(simd_matrix(simd_float4{(float)node.matrix[0], (float)node.matrix[1], (float)node.matrix[2], (float)node.matrix[3]},
                                                     simd_float4{(float)node.matrix[4], (float)node.matrix[5], (float)node.matrix[6], (float)node.matrix[7]},
                                                     simd_float4{(float)node.matrix[8], (float)node.matrix[9], (float)node.matrix[10], (float)node.matrix[11]},
                                                     simd_float4{(float)node.matrix[12], (float)node.matrix[13], (float)node.matrix[14], (float)node.matrix[15]}));
            }
            else
            {
                simd_float4x4 translation = matrix_identity_float4x4;
                if (node.translation.size() == 3)
                {
                    translation = matrix_from_translation((float)node.translation[0], (float)node.translation[1], (float)node.translation[2]);
                }

                simd_float4x4 rotation = matrix_identity_float4x4;
                if (node.rotation.size() == 4)
                {
                    simd_quatf q = simd_quaternion((float)node.rotation[0], (float)node.rotation[1], (float)node.rotation[2], (float)node.rotation[3]);
                    rotation = simd_matrix4x4(q);
                }

                simd_float4x4 scale = matrix_identity_float4x4;
                if (node.scale.size() == 3)
                {
                    scale = matrix_from_scale((float)node.scale[0], (float)node.scale[1], (float)node.scale[2]);
                }
                
                pNode->setTransformation(matrix_multiply(matrix_multiply(translation, rotation), scale));
            }

            if (node.mesh > -1)
            {
                const tinygltf::Mesh& mesh = gltfModel.meshes[node.mesh];
                for (const auto& primitive : mesh.primitives)
                {
                    std::vector<Vertex> vertices;
                    std::vector<uint16_t> indices;

                    // Get positions
                    const tinygltf::Accessor& posAccessor = gltfModel.accessors[primitive.attributes.find("POSITION")->second];
                    std::vector<float> positions = getAccessorData<float>(gltfModel, posAccessor);

                    // Get normals
                    const tinygltf::Accessor& normAccessor = gltfModel.accessors[primitive.attributes.find("NORMAL")->second];
                    std::vector<float> normals = getAccessorData<float>(gltfModel, normAccessor);

                    // Get texture coordinates
                    const tinygltf::Accessor& uvAccessor = gltfModel.accessors[primitive.attributes.find("TEXCOORD_0")->second];
                    std::vector<float> uvs = getAccessorData<float>(gltfModel, uvAccessor);

                    // Populate vertices
                    vertices.resize(posAccessor.count);
                    for (size_t i = 0; i < posAccessor.count; ++i)
                    {
                        vertices[i].position = {positions[i * 3 + 0], positions[i * 3 + 1], positions[i * 3 + 2]};
                        vertices[i].normal = {normals[i * 3 + 0], normals[i * 3 + 1], normals[i * 3 + 2]};
                        vertices[i].texCoords = {uvs[i * 2 + 0], uvs[i * 2 + 1]};
                    }

                    // Get indices
                    const tinygltf::Accessor& indexAccessor = gltfModel.accessors[primitive.indices];
                    if (indexAccessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_SHORT)
                    {
                        indices = getAccessorData<uint16_t>(gltfModel, indexAccessor);
                    }
                    else if (indexAccessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_INT)
                    {
                        std::vector<uint32_t> uint32_indices = getAccessorData<uint32_t>(gltfModel, indexAccessor);
                        indices.resize(uint32_indices.size());
                        for (size_t i = 0; i < uint32_indices.size(); ++i)
                        {
                            indices[i] = static_cast<uint16_t>(uint32_indices[i]);
                        }
                    }

                    std::shared_ptr<Material> pMeshMaterial = nullptr;
                    if (primitive.material > -1 && primitive.material < m_materials.size())
                    {
                        pMeshMaterial = m_materials[primitive.material];
                    }
                    else
                    {
                        // Use a default material if none is specified or invalid index
                        pMeshMaterial = std::make_shared<Material>();
                    }

                    pNode->addMesh(std::make_shared<Mesh>(pDevice, vertices, indices, pMeshMaterial));
                }
            }
            m_nodes.push_back(pNode);
        }
    }
} // namespace Scene
