#import "AssetOptimizerBridge.h"
#import "PinnacleMetalRenderer.h"
#import "MaterialFixerBridge.h"
#import "TextureManagerBridge.h"
#import "ModelValidatorBridge.h"
#import <Metal/Metal.h>

// MARK: - OptimizationSettings Implementation

@implementation OptimizationSettings

- (instancetype)init {
    self = [super init];
    if (self) {
        _profile = OptimizationProfileCustom;
        _profileName = @"Custom";
        _fixMaterials = YES;
        _validateMaterials = YES;
        _targetEngine = TargetEngineGenericPBR;
        _optimizeTextures = YES;
        _resizeTextures = YES;
        _maxTextureResolution = 2048;
        _compressTextures = NO;
        _generateMipmaps = YES;
        _removeDuplicateTextures = YES;
        _removeUnusedTextures = YES;
        _optimizeMeshes = YES;
        _maxVerticesPerMesh = 65535;
        _maxTrianglesPerMesh = 50000;
        _removeDegenerateTriangles = YES;
        _mergeDuplicateVertices = YES;
        _optimizeHierarchy = YES;
        _flattenHierarchy = NO;
        _maxHierarchyDepth = 10;
        _embedTextures = NO;
        _makePathsRelative = YES;
    }
    return self;
}

+ (instancetype)mobileProfile {
    OptimizationSettings *settings = [[OptimizationSettings alloc] init];
    settings.profile = OptimizationProfileMobile;
    settings.profileName = @"Mobile";

    // Aggressive texture optimization
    settings.optimizeTextures = YES;
    settings.resizeTextures = YES;
    settings.maxTextureResolution = 1024;  // Smaller for mobile
    settings.compressTextures = YES;
    settings.generateMipmaps = YES;
    settings.removeDuplicateTextures = YES;
    settings.removeUnusedTextures = YES;

    // Aggressive mesh optimization
    settings.optimizeMeshes = YES;
    settings.maxVerticesPerMesh = 30000;  // Lower limit
    settings.maxTrianglesPerMesh = 20000;
    settings.removeDegenerateTriangles = YES;
    settings.mergeDuplicateVertices = YES;

    // Hierarchy optimization
    settings.optimizeHierarchy = YES;
    settings.flattenHierarchy = YES;  // Flatten for mobile
    settings.maxHierarchyDepth = 5;

    // Materials
    settings.fixMaterials = YES;
    settings.validateMaterials = YES;
    settings.targetEngine = TargetEngineUnityURP;  // Common mobile engine

    return settings;
}

+ (instancetype)desktopProfile {
    OptimizationSettings *settings = [[OptimizationSettings alloc] init];
    settings.profile = OptimizationProfileDesktop;
    settings.profileName = @"Desktop";

    // Balanced texture optimization
    settings.optimizeTextures = YES;
    settings.resizeTextures = YES;
    settings.maxTextureResolution = 2048;
    settings.compressTextures = NO;  // Desktop can handle uncompressed
    settings.generateMipmaps = YES;
    settings.removeDuplicateTextures = YES;
    settings.removeUnusedTextures = YES;

    // Moderate mesh optimization
    settings.optimizeMeshes = YES;
    settings.maxVerticesPerMesh = 65535;
    settings.maxTrianglesPerMesh = 50000;
    settings.removeDegenerateTriangles = YES;
    settings.mergeDuplicateVertices = YES;

    // Hierarchy
    settings.optimizeHierarchy = YES;
    settings.flattenHierarchy = NO;
    settings.maxHierarchyDepth = 10;

    // Materials
    settings.fixMaterials = YES;
    settings.validateMaterials = YES;
    settings.targetEngine = TargetEngineGenericPBR;

    return settings;
}

+ (instancetype)vrProfile {
    OptimizationSettings *settings = [[OptimizationSettings alloc] init];
    settings.profile = OptimizationProfileVR;
    settings.profileName = @"VR";

    // VR needs consistent 90fps, aggressive optimization
    settings.optimizeTextures = YES;
    settings.resizeTextures = YES;
    settings.maxTextureResolution = 2048;
    settings.compressTextures = YES;
    settings.generateMipmaps = YES;
    settings.removeDuplicateTextures = YES;
    settings.removeUnusedTextures = YES;

    // Aggressive mesh optimization for stereo rendering
    settings.optimizeMeshes = YES;
    settings.maxVerticesPerMesh = 40000;
    settings.maxTrianglesPerMesh = 30000;
    settings.removeDegenerateTriangles = YES;
    settings.mergeDuplicateVertices = YES;

    // Flatten hierarchy for performance
    settings.optimizeHierarchy = YES;
    settings.flattenHierarchy = YES;
    settings.maxHierarchyDepth = 5;

    // Materials
    settings.fixMaterials = YES;
    settings.validateMaterials = YES;
    settings.targetEngine = TargetEngineUnrealEngine;  // Common VR engine

    return settings;
}

+ (instancetype)arProfile {
    OptimizationSettings *settings = [[OptimizationSettings alloc] init];
    settings.profile = OptimizationProfileAR;
    settings.profileName = @"AR (USDZ)";

    // AR Quick Look requirements
    settings.optimizeTextures = YES;
    settings.resizeTextures = YES;
    settings.maxTextureResolution = 2048;  // Apple recommends 2K max
    settings.compressTextures = NO;  // USDZ handles compression
    settings.generateMipmaps = YES;
    settings.removeDuplicateTextures = YES;
    settings.removeUnusedTextures = YES;

    // AR performance requirements
    settings.optimizeMeshes = YES;
    settings.maxVerticesPerMesh = 50000;
    settings.maxTrianglesPerMesh = 40000;
    settings.removeDegenerateTriangles = YES;
    settings.mergeDuplicateVertices = YES;

    // Keep hierarchy for AR interaction
    settings.optimizeHierarchy = YES;
    settings.flattenHierarchy = NO;
    settings.maxHierarchyDepth = 8;

    // Materials
    settings.fixMaterials = YES;
    settings.validateMaterials = YES;
    settings.targetEngine = TargetEngineGenericPBR;

    // USDZ-specific
    settings.embedTextures = YES;  // USDZ needs embedded textures

    return settings;
}

+ (instancetype)webProfile {
    OptimizationSettings *settings = [[OptimizationSettings alloc] init];
    settings.profile = OptimizationProfileWeb;
    settings.profileName = @"Web (glTF Viewer)";

    // Web needs small file sizes
    settings.optimizeTextures = YES;
    settings.resizeTextures = YES;
    settings.maxTextureResolution = 2048;
    settings.compressTextures = YES;
    settings.generateMipmaps = YES;
    settings.removeDuplicateTextures = YES;
    settings.removeUnusedTextures = YES;

    // Optimize for download size
    settings.optimizeMeshes = YES;
    settings.maxVerticesPerMesh = 50000;
    settings.maxTrianglesPerMesh = 40000;
    settings.removeDegenerateTriangles = YES;
    settings.mergeDuplicateVertices = YES;

    // Flatten for web performance
    settings.optimizeHierarchy = YES;
    settings.flattenHierarchy = YES;
    settings.maxHierarchyDepth = 5;

    // Materials
    settings.fixMaterials = YES;
    settings.validateMaterials = YES;
    settings.targetEngine = TargetEngineGenericPBR;

    // Web-specific
    settings.embedTextures = NO;  // External for lazy loading
    settings.makePathsRelative = YES;

    return settings;
}

+ (instancetype)consoleProfile {
    OptimizationSettings *settings = [[OptimizationSettings alloc] init];
    settings.profile = OptimizationProfileConsole;
    settings.profileName = @"Console (PS5/Xbox)";

    // High-end but still optimize
    settings.optimizeTextures = YES;
    settings.resizeTextures = YES;
    settings.maxTextureResolution = 4096;  // Consoles can handle 4K
    settings.compressTextures = YES;
    settings.generateMipmaps = YES;
    settings.removeDuplicateTextures = YES;
    settings.removeUnusedTextures = YES;

    // High quality meshes
    settings.optimizeMeshes = YES;
    settings.maxVerticesPerMesh = 100000;
    settings.maxTrianglesPerMesh = 80000;
    settings.removeDegenerateTriangles = YES;
    settings.mergeDuplicateVertices = YES;

    // Keep hierarchy for gameplay
    settings.optimizeHierarchy = YES;
    settings.flattenHierarchy = NO;
    settings.maxHierarchyDepth = 15;

    // Materials
    settings.fixMaterials = YES;
    settings.validateMaterials = YES;
    settings.targetEngine = TargetEngineUnrealEngine;

    return settings;
}

@end

// MARK: - OptimizationStatistics Implementation

@implementation OptimizationStatistics

- (instancetype)init {
    self = [super init];
    if (self) {
        _vertexCountBefore = 0;
        _triangleCountBefore = 0;
        _textureSizeBefore = 0;
        _drawCallsBefore = 0;
        _totalSizeBefore = 0;

        _vertexCountAfter = 0;
        _triangleCountAfter = 0;
        _textureSizeAfter = 0;
        _drawCallsAfter = 0;
        _totalSizeAfter = 0;

        _vertexReduction = 0;
        _triangleReduction = 0;
        _textureSavings = 0;
        _drawCallReduction = 0;
        _totalSavings = 0;

        _vertexReductionPercent = 0.0f;
        _triangleReductionPercent = 0.0f;
        _textureSavingsPercent = 0.0f;
        _drawCallReductionPercent = 0.0f;
        _totalSavingsPercent = 0.0f;

        _materialsFixed = 0;
        _texturesOptimized = 0;
        _meshesOptimized = 0;
        _duplicatesRemoved = 0;
    }
    return self;
}

@end

// MARK: - OptimizationResult Implementation

@implementation OptimizationResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _success = NO;
        _errorMessage = nil;
        _statistics = [[OptimizationStatistics alloc] init];
        _optimizationsApplied = @[];
        _warnings = @[];
        _errors = @[];
        _processingTime = 0.0;
    }
    return self;
}

@end

// MARK: - OptimizationPreview Implementation

@implementation OptimizationPreview

- (instancetype)init {
    self = [super init];
    if (self) {
        _predictedStatistics = [[OptimizationStatistics alloc] init];
        _plannedOptimizations = @[];
        _estimatedTime = 0.0;
    }
    return self;
}

@end

// MARK: - AssetOptimizerBridge Implementation

@implementation AssetOptimizerBridge {
    PinnacleMetalRenderer* _renderer;
}

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer {
    self = [super init];
    if (self) {
        _renderer = renderer;
    }
    return self;
}

// MARK: - Profile Management

+ (NSArray<NSString *> *)availableProfiles {
    return @[
        @"Mobile",
        @"Desktop",
        @"VR",
        @"AR (USDZ)",
        @"Web (glTF Viewer)",
        @"Console (PS5/Xbox)",
        @"Custom"
    ];
}

+ (OptimizationSettings *)settingsForProfile:(OptimizationProfile)profile {
    switch (profile) {
        case OptimizationProfileMobile:
            return [OptimizationSettings mobileProfile];
        case OptimizationProfileDesktop:
            return [OptimizationSettings desktopProfile];
        case OptimizationProfileVR:
            return [OptimizationSettings vrProfile];
        case OptimizationProfileAR:
            return [OptimizationSettings arProfile];
        case OptimizationProfileWeb:
            return [OptimizationSettings webProfile];
        case OptimizationProfileConsole:
            return [OptimizationSettings consoleProfile];
        case OptimizationProfileCustom:
        default:
            return [[OptimizationSettings alloc] init];
    }
}

// MARK: - Analysis

- (OptimizationStatistics *)analyzeCurrentState {
    OptimizationStatistics *stats = [[OptimizationStatistics alloc] init];

    auto model = _renderer->getModel();
    if (!model) return stats;

    // Mesh statistics
    const auto& meshes = model->getMeshes();
    for (const auto& mesh : meshes) {
        NSInteger vertexCount = (NSInteger)mesh->getVertexCount();
        stats.vertexCountBefore += vertexCount;
        stats.triangleCountBefore += vertexCount / 3;
    }
    stats.drawCallsBefore = (NSInteger)meshes.size();

    // Texture statistics
    const auto& textures = model->getTextures();
    for (const auto& texture : textures) {
        // Estimate texture size (2K assumed)
        stats.textureSizeBefore += 2048 * 2048 * 4;
    }

    // Total size estimate
    stats.totalSizeBefore = stats.textureSizeBefore + (stats.vertexCountBefore * sizeof(float) * 14);

    return stats;
}

- (OptimizationPreview *)previewOptimization:(OptimizationSettings *)settings {
    OptimizationPreview *preview = [[OptimizationPreview alloc] init];
    NSMutableArray<NSString *> *planned = [NSMutableArray array];

    // Analyze current state
    OptimizationStatistics *current = [self analyzeCurrentState];
    preview.predictedStatistics.vertexCountBefore = current.vertexCountBefore;
    preview.predictedStatistics.triangleCountBefore = current.triangleCountBefore;
    preview.predictedStatistics.textureSizeBefore = current.textureSizeBefore;
    preview.predictedStatistics.drawCallsBefore = current.drawCallsBefore;
    preview.predictedStatistics.totalSizeBefore = current.totalSizeBefore;

    // Predict optimizations
    NSInteger vertexAfter = current.vertexCountBefore;
    NSInteger triangleAfter = current.triangleCountBefore;
    unsigned long long textureAfter = current.textureSizeBefore;
    NSInteger drawCallsAfter = current.drawCallsBefore;

    if (settings.fixMaterials) {
        [planned addObject:@"Fix and validate materials"];
    }

    if (settings.optimizeTextures) {
        if (settings.resizeTextures) {
            float resizeRatio = (float)settings.maxTextureResolution / 2048.0f;
            textureAfter = (unsigned long long)(textureAfter * resizeRatio * resizeRatio);
            [planned addObject:[NSString stringWithFormat:@"Resize textures to %ldx%ld",
                              (long)settings.maxTextureResolution, (long)settings.maxTextureResolution]];
        }
        if (settings.removeDuplicateTextures) {
            textureAfter = (unsigned long long)(textureAfter * 0.9);  // Assume 10% duplicates
            [planned addObject:@"Remove duplicate textures"];
        }
        if (settings.removeUnusedTextures) {
            textureAfter = (unsigned long long)(textureAfter * 0.95);  // Assume 5% unused
            [planned addObject:@"Remove unused textures"];
        }
    }

    if (settings.optimizeMeshes) {
        if (settings.removeDegenerateTriangles) {
            triangleAfter = (NSInteger)(triangleAfter * 0.98);  // Assume 2% degenerate
            [planned addObject:@"Remove degenerate triangles"];
        }
        if (settings.mergeDuplicateVertices) {
            vertexAfter = (NSInteger)(vertexAfter * 0.85);  // Assume 15% duplicates
            [planned addObject:@"Merge duplicate vertices"];
        }
    }

    if (settings.optimizeHierarchy && settings.flattenHierarchy) {
        drawCallsAfter = MAX(1, drawCallsAfter / 2);  // Assume 50% reduction from batching
        [planned addObject:@"Flatten hierarchy and batch meshes"];
    }

    // Set predicted values
    preview.predictedStatistics.vertexCountAfter = vertexAfter;
    preview.predictedStatistics.triangleCountAfter = triangleAfter;
    preview.predictedStatistics.textureSizeAfter = textureAfter;
    preview.predictedStatistics.drawCallsAfter = drawCallsAfter;
    preview.predictedStatistics.totalSizeAfter = textureAfter + (vertexAfter * sizeof(float) * 14);

    // Calculate savings
    preview.predictedStatistics.vertexReduction = current.vertexCountBefore - vertexAfter;
    preview.predictedStatistics.triangleReduction = current.triangleCountBefore - triangleAfter;
    preview.predictedStatistics.textureSavings = current.textureSizeBefore - textureAfter;
    preview.predictedStatistics.drawCallReduction = current.drawCallsBefore - drawCallsAfter;
    preview.predictedStatistics.totalSavings = current.totalSizeBefore - preview.predictedStatistics.totalSizeAfter;

    // Calculate percentages
    if (current.vertexCountBefore > 0) {
        preview.predictedStatistics.vertexReductionPercent =
            (float)preview.predictedStatistics.vertexReduction / current.vertexCountBefore * 100.0f;
    }
    if (current.triangleCountBefore > 0) {
        preview.predictedStatistics.triangleReductionPercent =
            (float)preview.predictedStatistics.triangleReduction / current.triangleCountBefore * 100.0f;
    }
    if (current.textureSizeBefore > 0) {
        preview.predictedStatistics.textureSavingsPercent =
            (float)preview.predictedStatistics.textureSavings / current.textureSizeBefore * 100.0f;
    }
    if (current.totalSizeBefore > 0) {
        preview.predictedStatistics.totalSavingsPercent =
            (float)preview.predictedStatistics.totalSavings / current.totalSizeBefore * 100.0f;
    }

    preview.plannedOptimizations = [planned copy];
    preview.estimatedTime = [planned count] * 0.5;  // Estimate 0.5s per operation

    return preview;
}

// MARK: - Optimization

- (OptimizationResult *)optimizeWithSettings:(OptimizationSettings *)settings {
    OptimizationResult *result = [[OptimizationResult alloc] init];
    NSDate *startTime = [NSDate date];
    NSMutableArray<NSString *> *applied = [NSMutableArray array];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    NSMutableArray<NSString *> *errors = [NSMutableArray array];

    // Capture before state
    result.statistics = [self analyzeCurrentState];

    @try {
        // 1. Fix materials
        if (settings.fixMaterials) {
            MaterialFixerBridge *materialFixer = [[MaterialFixerBridge alloc] initWithRenderer:_renderer];
            NSInteger fixed = [materialFixer autoFixMaterials];
            result.statistics.materialsFixed = fixed;

            if (fixed > 0) {
                [applied addObject:[NSString stringWithFormat:@"Fixed %ld material issue(s)", (long)fixed]];
            }
        }

        // 2. Optimize textures
        if (settings.optimizeTextures) {
            TextureManagerBridge *textureMgr = [[TextureManagerBridge alloc] initWithRenderer:_renderer];

            if (settings.removeDuplicateTextures) {
                TextureOperationResult *dupResult = [textureMgr removeDuplicateTextures];
                result.statistics.duplicatesRemoved += dupResult.duplicatesRemoved;
                if (dupResult.duplicatesRemoved > 0) {
                    [applied addObject:[NSString stringWithFormat:@"Removed %ld duplicate texture(s)",
                                      (long)dupResult.duplicatesRemoved]];
                }
            }

            if (settings.removeUnusedTextures) {
                TextureOperationResult *unusedResult = [textureMgr removeUnusedTextures];
                result.statistics.texturesOptimized += unusedResult.texturesProcessed;
                if (unusedResult.texturesProcessed > 0) {
                    [applied addObject:[NSString stringWithFormat:@"Removed %ld unused texture(s)",
                                      (long)unusedResult.texturesProcessed]];
                }
            }

            // TODO: Implement actual texture resizing and compression
            if (settings.resizeTextures) {
                [warnings addObject:@"Texture resizing not yet fully implemented"];
            }
            if (settings.compressTextures) {
                [warnings addObject:@"Texture compression not yet fully implemented"];
            }
        }

        // 3. Optimize meshes
        if (settings.optimizeMeshes) {
            // TODO: Implement mesh optimization
            [warnings addObject:@"Mesh optimization not yet fully implemented"];
        }

        // 4. Optimize hierarchy
        if (settings.optimizeHierarchy) {
            // TODO: Implement hierarchy optimization
            [warnings addObject:@"Hierarchy optimization not yet fully implemented"];
        }

        // Capture after state
        OptimizationStatistics *afterStats = [self analyzeCurrentState];
        result.statistics.vertexCountAfter = afterStats.vertexCountBefore;  // Using 'before' as current
        result.statistics.triangleCountAfter = afterStats.triangleCountBefore;
        result.statistics.textureSizeAfter = afterStats.textureSizeBefore;
        result.statistics.drawCallsAfter = afterStats.drawCallsBefore;
        result.statistics.totalSizeAfter = afterStats.totalSizeBefore;

        // Calculate actual savings
        result.statistics.vertexReduction = result.statistics.vertexCountBefore - result.statistics.vertexCountAfter;
        result.statistics.triangleReduction = result.statistics.triangleCountBefore - result.statistics.triangleCountAfter;
        result.statistics.textureSavings = result.statistics.textureSizeBefore - result.statistics.textureSizeAfter;
        result.statistics.drawCallReduction = result.statistics.drawCallsBefore - result.statistics.drawCallsAfter;
        result.statistics.totalSavings = result.statistics.totalSizeBefore - result.statistics.totalSizeAfter;

        // Calculate percentages
        if (result.statistics.vertexCountBefore > 0) {
            result.statistics.vertexReductionPercent =
                (float)result.statistics.vertexReduction / result.statistics.vertexCountBefore * 100.0f;
        }
        if (result.statistics.triangleCountBefore > 0) {
            result.statistics.triangleReductionPercent =
                (float)result.statistics.triangleReduction / result.statistics.triangleCountBefore * 100.0f;
        }
        if (result.statistics.textureSizeBefore > 0) {
            result.statistics.textureSavingsPercent =
                (float)result.statistics.textureSavings / result.statistics.textureSizeBefore * 100.0f;
        }
        if (result.statistics.totalSizeBefore > 0) {
            result.statistics.totalSavingsPercent =
                (float)result.statistics.totalSavings / result.statistics.totalSizeBefore * 100.0f;
        }

        result.success = YES;

    } @catch (NSException *exception) {
        result.success = NO;
        result.errorMessage = [NSString stringWithFormat:@"Optimization failed: %@", exception.reason];
        [errors addObject:result.errorMessage];
    }

    result.optimizationsApplied = [applied copy];
    result.warnings = [warnings copy];
    result.errors = [errors copy];
    result.processingTime = [[NSDate date] timeIntervalSinceDate:startTime];

    return result;
}

// MARK: - Undo

- (BOOL)canUndo {
    // TODO: Implement undo support
    return NO;
}

- (BOOL)undoOptimization {
    // TODO: Implement undo
    return NO;
}

// MARK: - Export

+ (BOOL)exportOptimizationReport:(OptimizationResult *)result
                         filePath:(NSString *)logPath {
    NSMutableString *log = [NSMutableString string];

    // Header
    [log appendString:@"===========================================\n"];
    [log appendString:@"  Pinnacle Asset Optimization Report\n"];
    [log appendString:@"===========================================\n\n"];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [log appendFormat:@"Date: %@\n", [formatter stringFromDate:[NSDate date]]];
    [log appendFormat:@"Processing Time: %.2f seconds\n\n", result.processingTime];

    // Summary
    [log appendString:@"OPTIMIZATION SUMMARY\n"];
    [log appendString:@"--------------------\n"];
    [log appendFormat:@"Status: %@\n", result.success ? @"SUCCESS" : @"FAILED"];
    [log appendFormat:@"Optimizations Applied: %ld\n\n", (long)[result.optimizationsApplied count]];

    OptimizationStatistics *stats = result.statistics;

    // Before/After comparison
    [log appendString:@"BEFORE OPTIMIZATION\n"];
    [log appendString:@"-------------------\n"];
    [log appendFormat:@"Vertices: %ld\n", (long)stats.vertexCountBefore];
    [log appendFormat:@"Triangles: %ld\n", (long)stats.triangleCountBefore];
    [log appendFormat:@"Texture Size: %.2f MB\n", stats.textureSizeBefore / (1024.0 * 1024.0)];
    [log appendFormat:@"Draw Calls: %ld\n", (long)stats.drawCallsBefore];
    [log appendFormat:@"Total Size: %.2f MB\n\n", stats.totalSizeBefore / (1024.0 * 1024.0)];

    [log appendString:@"AFTER OPTIMIZATION\n"];
    [log appendString:@"------------------\n"];
    [log appendFormat:@"Vertices: %ld\n", (long)stats.vertexCountAfter];
    [log appendFormat:@"Triangles: %ld\n", (long)stats.triangleCountAfter];
    [log appendFormat:@"Texture Size: %.2f MB\n", stats.textureSizeAfter / (1024.0 * 1024.0)];
    [log appendFormat:@"Draw Calls: %ld\n", (long)stats.drawCallsAfter];
    [log appendFormat:@"Total Size: %.2f MB\n\n", stats.totalSizeAfter / (1024.0 * 1024.0)];

    [log appendString:@"SAVINGS\n"];
    [log appendString:@"-------\n"];
    [log appendFormat:@"Vertices Reduced: %ld (%.1f%%)\n",
     (long)stats.vertexReduction, stats.vertexReductionPercent];
    [log appendFormat:@"Triangles Reduced: %ld (%.1f%%)\n",
     (long)stats.triangleReduction, stats.triangleReductionPercent];
    [log appendFormat:@"Texture Savings: %.2f MB (%.1f%%)\n",
     stats.textureSavings / (1024.0 * 1024.0), stats.textureSavingsPercent];
    [log appendFormat:@"Draw Calls Reduced: %ld\n", (long)stats.drawCallReduction];
    [log appendFormat:@"Total Savings: %.2f MB (%.1f%%)\n\n",
     stats.totalSavings / (1024.0 * 1024.0), stats.totalSavingsPercent];

    // Optimizations applied
    if ([result.optimizationsApplied count] > 0) {
        [log appendString:@"OPTIMIZATIONS APPLIED\n"];
        [log appendString:@"---------------------\n"];
        for (NSString *opt in result.optimizationsApplied) {
            [log appendFormat:@"• %@\n", opt];
        }
        [log appendString:@"\n"];
    }

    // Warnings
    if ([result.warnings count] > 0) {
        [log appendString:@"WARNINGS\n"];
        [log appendString:@"--------\n"];
        for (NSString *warning in result.warnings) {
            [log appendFormat:@"⚠ %@\n", warning];
        }
        [log appendString:@"\n"];
    }

    // Errors
    if ([result.errors count] > 0) {
        [log appendString:@"ERRORS\n"];
        [log appendString:@"------\n"];
        for (NSString *error in result.errors) {
            [log appendFormat:@"❌ %@\n", error];
        }
        [log appendString:@"\n"];
    }

    // Write to file
    NSError *error = nil;
    BOOL success = [log writeToFile:logPath
                         atomically:YES
                           encoding:NSUTF8StringEncoding
                              error:&error];

    return success;
}

@end
