#import "SceneInspectorBridge.h"
#import <Metal/Metal.h>

#include "../PinnacleMetalRenderer.h"
#include "../Scene/Model.hpp"
#include "../Scene/Mesh.hpp"
#include "../Scene/Material.hpp"

// Implementation of data classes
@implementation SceneStatistics
@end

@implementation MeshInfo
@end

@implementation MaterialInfo
@end

// Bridge implementation
@interface SceneInspectorBridge()
{
    PinnacleMetalRenderer* _renderer;
}
@end

@implementation SceneInspectorBridge

- (instancetype)initWithRenderer:(void*)renderer {
    self = [super init];
    if (self) {
        _renderer = (PinnacleMetalRenderer*)renderer;
    }
    return self;
}

- (BOOL)hasLoadedModel {
    if (!_renderer) return NO;

    // Check if renderer has a model loaded
    // This is a simple check - in production you'd add a method to the renderer
    return YES; // Placeholder
}

- (SceneStatistics*)getStatistics {
    SceneStatistics* stats = [[SceneStatistics alloc] init];

    if (!_renderer) {
        stats.meshCount = 0;
        stats.triangleCount = 0;
        stats.vertexCount = 0;
        stats.materialCount = 0;
        stats.textureCount = 0;
        stats.textureMemoryMB = 0.0;
        stats.boundingBox = @[@0, @0, @0, @0, @0, @0];
        return stats;
    }

    // Get model from renderer
    auto model = _renderer->getModel();
    if (!model) {
        stats.meshCount = 0;
        stats.triangleCount = 0;
        stats.vertexCount = 0;
        stats.materialCount = 0;
        stats.textureCount = 0;
        stats.textureMemoryMB = 0.0;
        stats.boundingBox = @[@0, @0, @0, @0, @0, @0];
        return stats;
    }

    // Calculate statistics from model
    const auto& meshes = model->getMeshes();
    const auto& materials = model->getMaterials();

    stats.meshCount = meshes.size();
    stats.materialCount = materials.size();
    stats.textureCount = 0; // TODO: Count unique textures
    stats.textureMemoryMB = 0.0; // TODO: Calculate texture memory

    // Accumulate triangle and vertex counts
    NSInteger totalTriangles = 0;
    NSInteger totalVertices = 0;
    float minX = INFINITY, minY = INFINITY, minZ = INFINITY;
    float maxX = -INFINITY, maxY = -INFINITY, maxZ = -INFINITY;
    bool hasBounds = false;

    for (const auto& mesh : meshes) {
        totalTriangles += mesh->getIndexCount() / 3;
        totalVertices += mesh->getVertexCount();

        // Get vertex buffer to calculate bounds
        id<MTLBuffer> vertexBuffer = (id<MTLBuffer>)mesh->getVertexBuffer();
        if (vertexBuffer) {
            const Pinnacle::Vertex* vertices = (const Pinnacle::Vertex*)[vertexBuffer contents];
            size_t vertexCount = mesh->getVertexCount();

            for (size_t i = 0; i < vertexCount; ++i) {
                const auto& pos = vertices[i].position;
                minX = std::min(minX, pos.x);
                minY = std::min(minY, pos.y);
                minZ = std::min(minZ, pos.z);
                maxX = std::max(maxX, pos.x);
                maxY = std::max(maxY, pos.y);
                maxZ = std::max(maxZ, pos.z);
                hasBounds = true;
            }
        }
    }

    stats.triangleCount = totalTriangles;
    stats.vertexCount = totalVertices;

    // Bounding box: [minX, minY, minZ, maxX, maxY, maxZ]
    if (hasBounds) {
        stats.boundingBox = @[@(minX), @(minY), @(minZ), @(maxX), @(maxY), @(maxZ)];
    } else {
        stats.boundingBox = @[@0, @0, @0, @0, @0, @0];
    }

    return stats;
}

- (NSArray<MeshInfo*>*)getMeshes {
    NSMutableArray<MeshInfo*>* meshes = [NSMutableArray array];

    if (!_renderer) {
        return meshes;
    }

    // Get meshes from renderer's model
    auto model = _renderer->getModel();
    if (!model) {
        return meshes;
    }

    const auto& modelMeshes = model->getMeshes();
    const auto& materials = model->getMaterials();

    for (size_t i = 0; i < modelMeshes.size(); ++i) {
        const auto& mesh = modelMeshes[i];

        MeshInfo* meshInfo = [[MeshInfo alloc] init];
        meshInfo.name = [NSString stringWithFormat:@"Mesh_%zu", i];
        meshInfo.triangleCount = mesh->getIndexCount() / 3;
        meshInfo.vertexCount = mesh->getVertexCount();

        // Get material name
        auto material = mesh->getMaterial();
        if (material) {
            // Find material index
            for (size_t j = 0; j < materials.size(); ++j) {
                if (materials[j] == material) {
                    meshInfo.materialName = [NSString stringWithFormat:@"Material_%zu", j];
                    break;
                }
            }
        } else {
            meshInfo.materialName = @"None";
        }

        // Check for normals and tex coords by checking the first vertex
        id<MTLBuffer> vertexBuffer = (id<MTLBuffer>)mesh->getVertexBuffer();
        if (vertexBuffer && mesh->getVertexCount() > 0) {
            const Pinnacle::Vertex* vertices = (const Pinnacle::Vertex*)[vertexBuffer contents];

            // Check if normals are non-zero
            bool hasNormals = (vertices[0].normal.x != 0.0f ||
                             vertices[0].normal.y != 0.0f ||
                             vertices[0].normal.z != 0.0f);

            // Check if tex coords are present (can be 0,0 but that's still valid)
            bool hasTexCoords = true; // Always true if we reached here since we always load them

            meshInfo.hasNormals = hasNormals;
            meshInfo.hasTexCoords = hasTexCoords;
        } else {
            meshInfo.hasNormals = NO;
            meshInfo.hasTexCoords = NO;
        }

        [meshes addObject:meshInfo];
    }

    return meshes;
}

- (NSArray<MaterialInfo*>*)getMaterials {
    NSMutableArray<MaterialInfo*>* materials = [NSMutableArray array];

    if (!_renderer) {
        return materials;
    }

    // Get materials from renderer's model
    auto model = _renderer->getModel();
    if (!model) {
        return materials;
    }

    const auto& modelMaterials = model->getMaterials();

    for (size_t i = 0; i < modelMaterials.size(); ++i) {
        const auto& mat = modelMaterials[i];
        const auto& pbr = mat->getPBRMaterial();

        MaterialInfo* materialInfo = [[MaterialInfo alloc] init];
        materialInfo.name = [NSString stringWithFormat:@"Material_%zu", i];
        materialInfo.metallicFactor = pbr.metallicFactor;
        materialInfo.roughnessFactor = pbr.roughnessFactor;
        materialInfo.baseColorFactor = @[
            @(pbr.baseColorFactor.x),
            @(pbr.baseColorFactor.y),
            @(pbr.baseColorFactor.z),
            @(pbr.baseColorFactor.w)
        ];

        materialInfo.hasBaseColorTexture = (pbr.baseColorTexture != nullptr);
        materialInfo.hasMetallicRoughnessTexture = (pbr.metallicRoughnessTexture != nullptr);
        materialInfo.hasNormalTexture = (pbr.normalTexture != nullptr);

        // TODO: Get actual texture path if needed
        materialInfo.baseColorTexturePath = @"";

        [materials addObject:materialInfo];
    }

    return materials;
}

@end
