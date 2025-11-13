#import "MaterialFixerBridge.h"
#include "PinnacleMetalRenderer.h"
#include "Scene/Model.hpp"
#include "Scene/Material.hpp"
#import <Foundation/Foundation.h>

@implementation MaterialIssue
@end

@implementation MaterialValidationResult
@end

@implementation MaterialCreationResult
@end

@implementation MaterialFixerBridge {
    PinnacleMetalRenderer* _renderer;
}

- (instancetype)initWithRenderer:(void*)renderer {
    self = [super init];
    if (self) {
        _renderer = static_cast<PinnacleMetalRenderer*>(renderer);
    }
    return self;
}

// MARK: - Material Validation

- (MaterialValidationResult*)validateMaterials {
    return [self validateMaterialsForEngine:TargetEngineGenericPBR];
}

- (MaterialValidationResult*)validateMaterialsForEngine:(TargetEngine)engine {
    MaterialValidationResult* result = [[MaterialValidationResult alloc] init];
    NSMutableArray<MaterialIssue *>* issues = [NSMutableArray array];

    if (!_renderer) {
        result.isValid = NO;
        result.errorCount = 1;
        result.warningCount = 0;
        result.issues = @[];
        return result;
    }

    auto model = _renderer->getModel();
    if (!model) {
        result.isValid = YES;
        result.errorCount = 0;
        result.warningCount = 0;
        result.issues = @[];
        return result;
    }

    const auto& materials = model->getMaterials();

    NSInteger errorCount = 0;
    NSInteger warningCount = 0;

    for (size_t i = 0; i < materials.size(); ++i) {
        const auto& material = materials[i];
        const auto& pbr = material->getPBRMaterial();

        NSString* materialName = [NSString stringWithFormat:@"Material_%zu", i];

        // Check for invalid metallic/roughness values
        if (pbr.metallicFactor < 0.0f || pbr.metallicFactor > 1.0f) {
            MaterialIssue* issue = [[MaterialIssue alloc] init];
            issue.severity = MaterialIssueSeverityWarning;
            issue.materialName = materialName;
            issue.message = [NSString stringWithFormat:@"Metallic factor out of range: %.2f", pbr.metallicFactor];
            issue.suggestion = @"Metallic values should be between 0.0 and 1.0";
            [issues addObject:issue];
            warningCount++;
        }

        if (pbr.roughnessFactor < 0.0f || pbr.roughnessFactor > 1.0f) {
            MaterialIssue* issue = [[MaterialIssue alloc] init];
            issue.severity = MaterialIssueSeverityWarning;
            issue.materialName = materialName;
            issue.message = [NSString stringWithFormat:@"Roughness factor out of range: %.2f", pbr.roughnessFactor];
            issue.suggestion = @"Roughness values should be between 0.0 and 1.0";
            [issues addObject:issue];
            warningCount++;
        }

        // Check base color values
        if (pbr.baseColorFactor.x < 0.0f || pbr.baseColorFactor.x > 1.0f ||
            pbr.baseColorFactor.y < 0.0f || pbr.baseColorFactor.y > 1.0f ||
            pbr.baseColorFactor.z < 0.0f || pbr.baseColorFactor.z > 1.0f ||
            pbr.baseColorFactor.w < 0.0f || pbr.baseColorFactor.w > 1.0f) {
            MaterialIssue* issue = [[MaterialIssue alloc] init];
            issue.severity = MaterialIssueSeverityWarning;
            issue.materialName = materialName;
            issue.message = @"Base color factor has values out of range [0,1]";
            issue.suggestion = @"Base color RGB and alpha should be in range 0.0-1.0";
            [issues addObject:issue];
            warningCount++;
        }

        // Engine-specific validations
        if (engine == TargetEngineUnityBuiltIn || engine == TargetEngineUnityURP || engine == TargetEngineUnityHDRP) {
            // Unity-specific checks
            if (pbr.metallicFactor > 0.9f && pbr.roughnessFactor < 0.1f) {
                MaterialIssue* issue = [[MaterialIssue alloc] init];
                issue.severity = MaterialIssueSeverityInfo;
                issue.materialName = materialName;
                issue.message = @"Very smooth metallic materials may render differently in Unity";
                issue.suggestion = @"Consider increasing roughness slightly (0.1-0.2) for more realistic Unity rendering";
                [issues addObject:issue];
            }
        }

        if (engine == TargetEngineUnrealEngine) {
            // Unreal-specific checks
            if (!pbr.baseColorTexture && pbr.baseColorFactor.x == 1.0f &&
                pbr.baseColorFactor.y == 1.0f && pbr.baseColorFactor.z == 1.0f) {
                MaterialIssue* issue = [[MaterialIssue alloc] init];
                issue.severity = MaterialIssueSeverityWarning;
                issue.materialName = materialName;
                issue.message = @"Pure white material without texture may not render as expected in Unreal";
                issue.suggestion = @"Add a base color texture or adjust the base color factor";
                [issues addObject:issue];
                warningCount++;
            }
        }

        // Check for missing normal maps on complex materials
        if (!pbr.normalTexture && pbr.baseColorTexture && (pbr.metallicRoughnessTexture || pbr.occlusionTexture)) {
            MaterialIssue* issue = [[MaterialIssue alloc] init];
            issue.severity = MaterialIssueSeverityInfo;
            issue.materialName = materialName;
            issue.message = @"Material has textures but no normal map";
            issue.suggestion = @"Consider adding a normal map for enhanced surface detail";
            [issues addObject:issue];
        }
    }

    result.isValid = (errorCount == 0);
    result.errorCount = errorCount;
    result.warningCount = warningCount;
    result.issues = issues;

    return result;
}

- (NSInteger)autoFixMaterials {
    if (!_renderer) {
        return 0;
    }

    auto model = _renderer->getModel();
    if (!model) {
        return 0;
    }

    const auto& materials = model->getMaterials();
    NSInteger fixedCount = 0;

    for (const auto& material : materials) {
        auto& pbr = material->getPBRMaterial();

        // Clamp metallic factor
        if (pbr.metallicFactor < 0.0f || pbr.metallicFactor > 1.0f) {
            pbr.metallicFactor = std::max(0.0f, std::min(1.0f, pbr.metallicFactor));
            fixedCount++;
        }

        // Clamp roughness factor
        if (pbr.roughnessFactor < 0.0f || pbr.roughnessFactor > 1.0f) {
            pbr.roughnessFactor = std::max(0.0f, std::min(1.0f, pbr.roughnessFactor));
            fixedCount++;
        }

        // Clamp base color
        pbr.baseColorFactor.x = std::max(0.0f, std::min(1.0f, pbr.baseColorFactor.x));
        pbr.baseColorFactor.y = std::max(0.0f, std::min(1.0f, pbr.baseColorFactor.y));
        pbr.baseColorFactor.z = std::max(0.0f, std::min(1.0f, pbr.baseColorFactor.z));
        pbr.baseColorFactor.w = std::max(0.0f, std::min(1.0f, pbr.baseColorFactor.w));
    }

    return fixedCount;
}

// MARK: - Material Creation

+ (MaterialCreationResult*)createMaterialFromTextures:(NSDictionary<NSNumber *, NSString *> *)texturePaths
                                          materialName:(NSString *)materialName {
    MaterialCreationResult* result = [[MaterialCreationResult alloc] init];

    if (!texturePaths || texturePaths.count == 0) {
        result.success = NO;
        result.errorMessage = @"No textures provided";
        return result;
    }

    // For now, we just validate the textures exist
    NSMutableDictionary* assignedTextures = [NSMutableDictionary dictionary];

    for (NSNumber* channelNum in texturePaths) {
        NSString* path = texturePaths[channelNum];

        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            result.success = NO;
            result.errorMessage = [NSString stringWithFormat:@"Texture not found: %@", path];
            return result;
        }

        assignedTextures[channelNum] = path;
    }

    result.success = YES;
    result.materialName = materialName;
    result.assignedTextures = assignedTextures;
    result.errorMessage = nil;

    return result;
}

+ (PBRTextureChannel)detectTextureChannel:(NSString *)filename {
    NSString* lower = [filename lowercaseString];

    // Remove extension
    lower = [[lower lastPathComponent] stringByDeletingPathExtension];

    // Check for common suffixes
    if ([lower containsString:@"basecolor"] || [lower containsString:@"albedo"] ||
        [lower containsString:@"diffuse"] || [lower containsString:@"color"]) {
        return PBRTextureChannelBaseColor;
    }

    if ([lower containsString:@"metallic"] && [lower containsString:@"roughness"]) {
        return PBRTextureChannelMetallicRoughness;
    }

    if ([lower containsString:@"metallic"] || [lower containsString:@"metalness"]) {
        return PBRTextureChannelMetallic;
    }

    if ([lower containsString:@"roughness"] || [lower containsString:@"gloss"]) {
        return PBRTextureChannelRoughness;
    }

    if ([lower containsString:@"normal"] || [lower containsString:@"norm"]) {
        return PBRTextureChannelNormal;
    }

    if ([lower containsString:@"ao"] || [lower containsString:@"occlusion"] ||
        [lower containsString:@"ambient"]) {
        return PBRTextureChannelAmbientOcclusion;
    }

    if ([lower containsString:@"emissive"] || [lower containsString:@"emission"] ||
        [lower containsString:@"glow"]) {
        return PBRTextureChannelEmissive;
    }

    if ([lower containsString:@"height"] || [lower containsString:@"displacement"] ||
        [lower containsString:@"bump"]) {
        return PBRTextureChannelHeight;
    }

    return (PBRTextureChannel)-1; // Unknown
}

+ (NSDictionary<NSString *, id> *)getRecommendedSettingsForEngine:(TargetEngine)engine {
    NSMutableDictionary* settings = [NSMutableDictionary dictionary];

    switch (engine) {
        case TargetEngineUnityBuiltIn:
            settings[@"renderPipeline"] = @"Built-in";
            settings[@"shaderType"] = @"Standard";
            settings[@"coordinateSystem"] = @"Left-handed Y-up";
            settings[@"textureCompression"] = @"DXT5/BC3";
            settings[@"normalMapFormat"] = @"Unity (OpenGL)";
            break;

        case TargetEngineUnityURP:
            settings[@"renderPipeline"] = @"Universal Render Pipeline";
            settings[@"shaderType"] = @"Lit";
            settings[@"coordinateSystem"] = @"Left-handed Y-up";
            settings[@"textureCompression"] = @"ASTC/BC7";
            settings[@"normalMapFormat"] = @"Unity (OpenGL)";
            break;

        case TargetEngineUnityHDRP:
            settings[@"renderPipeline"] = @"High Definition Render Pipeline";
            settings[@"shaderType"] = @"HDRP/Lit";
            settings[@"coordinateSystem"] = @"Left-handed Y-up";
            settings[@"textureCompression"] = @"BC7";
            settings[@"normalMapFormat"] = @"Unity (OpenGL)";
            settings[@"recommendedRoughness"] = @0.15f; // Slightly higher for HDRP
            break;

        case TargetEngineUnrealEngine:
            settings[@"renderPipeline"] = @"Unreal Engine 5";
            settings[@"shaderType"] = @"Material Graph";
            settings[@"coordinateSystem"] = @"Left-handed Z-up";
            settings[@"textureCompression"] = @"BC7";
            settings[@"normalMapFormat"] = @"DirectX";
            settings[@"supportNanite"] = @YES;
            break;

        case TargetEngineGodot:
            settings[@"renderPipeline"] = @"Godot 4.x";
            settings[@"shaderType"] = @"StandardMaterial3D";
            settings[@"coordinateSystem"] = @"Right-handed Y-up";
            settings[@"textureCompression"] = @"BPTC/S3TC";
            settings[@"normalMapFormat"] = @"OpenGL";
            break;

        case TargetEngineGenericPBR:
            settings[@"renderPipeline"] = @"Generic PBR";
            settings[@"shaderType"] = @"PBR Metallic-Roughness";
            settings[@"coordinateSystem"] = @"Right-handed Y-up";
            settings[@"textureCompression"] = @"Platform-dependent";
            settings[@"normalMapFormat"] = @"OpenGL";
            break;
    }

    return settings;
}

@end
