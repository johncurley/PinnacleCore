#import "ModelValidatorBridge.h"
#import "PinnacleMetalRenderer.h"
#import "MaterialFixerBridge.h"
#import <Metal/Metal.h>

// MARK: - ValidationIssue Implementation

@implementation ValidationIssue

- (instancetype)init {
    self = [super init];
    if (self) {
        _category = ValidationCategoryFormat;
        _severity = ValidationSeverityInfo;
        _title = @"";
        _message = @"";
        _suggestion = @"";
        _affectedObject = @"";
        _objectIndex = -1;
    }
    return self;
}

@end

// MARK: - MeshValidationResult Implementation

@implementation MeshValidationResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _meshName = @"";
        _meshIndex = -1;
        _vertexCount = 0;
        _triangleCount = 0;
        _hasNormals = NO;
        _hasTangents = NO;
        _hasTexCoords = NO;
        _hasColors = NO;
        _isManifold = NO;
        _isWatertight = NO;
        _degenerateTriangles = 0;
        _duplicateVertices = 0;
        _issues = @[];
    }
    return self;
}

@end

// MARK: - PerformanceMetrics Implementation

@implementation PerformanceMetrics

- (instancetype)init {
    self = [super init];
    if (self) {
        _totalVertices = 0;
        _totalTriangles = 0;
        _totalMeshes = 0;
        _totalMaterials = 0;
        _uniqueMaterials = 0;
        _totalTextures = 0;
        _totalTextureMemory = 0;
        _estimatedDrawCalls = 0;
        _totalNodes = 0;
        _maxHierarchyDepth = 0;
        _fileSize = 0;
        _performanceScore = 0;
        _performanceRating = @"Unknown";
    }
    return self;
}

@end

// MARK: - ModelValidationResult Implementation

@implementation ModelValidationResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _modelPath = @"";
        _modelFormat = @"";
        _isValid = NO;
        _isGLTFCompliant = NO;
        _issues = @[];
        _infoCount = 0;
        _warningCount = 0;
        _errorCount = 0;
        _criticalCount = 0;
        _meshResults = @[];
        _metrics = [[PerformanceMetrics alloc] init];
        _recommendations = @[];
    }
    return self;
}

@end

// MARK: - ValidationOptions Implementation

@implementation ValidationOptions

- (instancetype)init {
    self = [super init];
    if (self) {
        _validateFormat = YES;
        _validateMeshTopology = YES;
        _validateMaterials = YES;
        _validateTextures = YES;
        _validateHierarchy = YES;
        _validateAnimations = YES;
        _checkPerformance = YES;
        _checkGLTFCompliance = YES;
        _maxVerticesPerMesh = 65535;
        _maxTrianglesPerMesh = 50000;
        _maxTextureResolution = 4096;
        _maxHierarchyDepth = 10;
        _targetEngine = TargetEngineGenericPBR;
    }
    return self;
}

@end

// MARK: - ModelValidatorBridge Implementation

@implementation ModelValidatorBridge {
    PinnacleMetalRenderer* _renderer;
}

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer {
    self = [super init];
    if (self) {
        _renderer = renderer;
    }
    return self;
}

// MARK: - Format Detection

+ (ModelFormat)detectFormat:(NSString *)filePath {
    NSString *ext = [[filePath pathExtension] lowercaseString];

    if ([ext isEqualToString:@"gltf"]) {
        return ModelFormatGLTF;
    } else if ([ext isEqualToString:@"glb"]) {
        return ModelFormatGLB;
    } else if ([ext isEqualToString:@"usdz"]) {
        return ModelFormatUSDZ;
    } else if ([ext isEqualToString:@"obj"]) {
        return ModelFormatOBJ;
    } else if ([ext isEqualToString:@"fbx"]) {
        return ModelFormatFBX;
    }

    return ModelFormatUnknown;
}

+ (NSString *)formatName:(ModelFormat)format {
    switch (format) {
        case ModelFormatGLTF:
            return @"glTF";
        case ModelFormatGLB:
            return @"GLB (Binary glTF)";
        case ModelFormatUSDZ:
            return @"USDZ";
        case ModelFormatOBJ:
            return @"Wavefront OBJ";
        case ModelFormatFBX:
            return @"Autodesk FBX";
        case ModelFormatUnknown:
        default:
            return @"Unknown";
    }
}

+ (BOOL)isFormatSupported:(ModelFormat)format {
    return (format == ModelFormatGLTF || format == ModelFormatGLB);
}

// MARK: - Validation

- (ModelValidationResult *)validateModel:(ValidationOptions *)options {
    ModelValidationResult *result = [[ModelValidationResult alloc] init];
    NSMutableArray<ValidationIssue *> *issues = [NSMutableArray array];
    NSMutableArray<NSString *> *recommendations = [NSMutableArray array];

    auto model = _renderer->getModel();
    if (!model) {
        ValidationIssue *issue = [[ValidationIssue alloc] init];
        issue.category = ValidationCategoryFormat;
        issue.severity = ValidationSeverityCritical;
        issue.title = @"No Model Loaded";
        issue.message = @"No model is currently loaded in the renderer";
        issue.suggestion = @"Load a model before running validation";
        [issues addObject:issue];

        result.issues = [issues copy];
        result.criticalCount = 1;
        return result;
    }

    // Format validation
    if (options.validateFormat) {
        // TODO: Get model path from renderer
        result.modelFormat = @"glTF";  // Assuming glTF for now
    }

    // Mesh topology validation
    if (options.validateMeshTopology) {
        NSMutableArray<MeshValidationResult *> *meshResults = [NSMutableArray array];
        const auto& meshes = model->getMeshes();

        for (size_t i = 0; i < meshes.size(); ++i) {
            MeshValidationResult *meshResult = [self validateMeshAtIndex:(NSInteger)i
                                                                  options:options];
            [meshResults addObject:meshResult];
            [issues addObjectsFromArray:meshResult.issues];

            // Add mesh-specific recommendations
            if (meshResult.vertexCount > options.maxVerticesPerMesh) {
                [recommendations addObject:[NSString stringWithFormat:
                    @"Mesh '%@' has %ld vertices (limit: %ld). Consider decimation.",
                    meshResult.meshName, (long)meshResult.vertexCount, (long)options.maxVerticesPerMesh]];
            }

            if (meshResult.degenerateTriangles > 0) {
                [recommendations addObject:[NSString stringWithFormat:
                    @"Mesh '%@' has %ld degenerate triangles. Clean up geometry.",
                    meshResult.meshName, (long)meshResult.degenerateTriangles]];
            }
        }

        result.meshResults = [meshResults copy];
    }

    // Material validation
    if (options.validateMaterials) {
        MaterialFixerBridge *materialFixer = [[MaterialFixerBridge alloc] initWithRenderer:_renderer];
        MaterialValidationResult *matResult = [materialFixer validateMaterialsForEngine:options.targetEngine];

        // Convert material issues to validation issues
        for (MaterialIssue *matIssue in matResult.issues) {
            ValidationIssue *issue = [[ValidationIssue alloc] init];
            issue.category = ValidationCategoryMaterial;
            issue.severity = (ValidationSeverity)matIssue.severity;
            issue.title = @"Material Issue";
            issue.message = matIssue.message;
            issue.suggestion = matIssue.suggestion;
            issue.affectedObject = [NSString stringWithFormat:@"Material[%ld]", (long)matIssue.materialIndex];
            issue.objectIndex = matIssue.materialIndex;
            [issues addObject:issue];
        }
    }

    // Performance analysis
    if (options.checkPerformance) {
        PerformanceMetrics *metrics = [self analyzePerformance];
        result.metrics = metrics;

        // Generate performance recommendations
        if (metrics.totalTriangles > 100000) {
            [recommendations addObject:@"High polygon count. Consider using LODs for better performance."];
        }

        if (metrics.estimatedDrawCalls > 50) {
            [recommendations addObject:@"High draw call count. Consider mesh batching or instancing."];
        }

        if (metrics.totalTextureMemory > 100 * 1024 * 1024) {  // 100MB
            [recommendations addObject:@"High texture memory usage. Consider texture compression or atlasing."];
        }

        if (metrics.maxHierarchyDepth > options.maxHierarchyDepth) {
            [recommendations addObject:[NSString stringWithFormat:
                @"Deep hierarchy (%ld levels). Consider flattening for better performance.",
                (long)metrics.maxHierarchyDepth]];
        }
    }

    // Count issues by severity
    for (ValidationIssue *issue in issues) {
        switch (issue.severity) {
            case ValidationSeverityInfo:
                result.infoCount++;
                break;
            case ValidationSeverityWarning:
                result.warningCount++;
                break;
            case ValidationSeverityError:
                result.errorCount++;
                break;
            case ValidationSeverityCritical:
                result.criticalCount++;
                break;
        }
    }

    result.issues = [issues copy];
    result.recommendations = [recommendations copy];
    result.isValid = (result.criticalCount == 0 && result.errorCount == 0);

    return result;
}

- (MeshValidationResult *)validateMesh:(NSInteger)meshIndex {
    ValidationOptions *options = [[ValidationOptions alloc] init];
    return [self validateMeshAtIndex:meshIndex options:options];
}

- (MeshValidationResult *)validateMeshAtIndex:(NSInteger)meshIndex
                                       options:(ValidationOptions *)options {
    MeshValidationResult *result = [[MeshValidationResult alloc] init];
    NSMutableArray<ValidationIssue *> *issues = [NSMutableArray array];

    auto model = _renderer->getModel();
    if (!model) return result;

    const auto& meshes = model->getMeshes();
    if (meshIndex < 0 || meshIndex >= (NSInteger)meshes.size()) {
        return result;
    }

    auto& mesh = meshes[meshIndex];

    // Basic info
    result.meshIndex = meshIndex;
    result.meshName = [NSString stringWithFormat:@"Mesh %ld", (long)meshIndex];
    result.vertexCount = (NSInteger)mesh->getVertexCount();
    result.triangleCount = result.vertexCount / 3;  // Simplified

    // Check vertex count
    if (result.vertexCount > options.maxVerticesPerMesh) {
        ValidationIssue *issue = [[ValidationIssue alloc] init];
        issue.category = ValidationCategoryMesh;
        issue.severity = ValidationSeverityWarning;
        issue.title = @"High Vertex Count";
        issue.message = [NSString stringWithFormat:@"Mesh has %ld vertices (limit: %ld)",
                        (long)result.vertexCount, (long)options.maxVerticesPerMesh];
        issue.suggestion = @"Consider mesh decimation to reduce vertex count";
        issue.affectedObject = result.meshName;
        issue.objectIndex = meshIndex;
        [issues addObject:issue];
    }

    // Check triangle count
    if (result.triangleCount > options.maxTrianglesPerMesh) {
        ValidationIssue *issue = [[ValidationIssue alloc] init];
        issue.category = ValidationCategoryMesh;
        issue.severity = ValidationSeverityWarning;
        issue.title = @"High Triangle Count";
        issue.message = [NSString stringWithFormat:@"Mesh has %ld triangles (limit: %ld)",
                        (long)result.triangleCount, (long)options.maxTrianglesPerMesh];
        issue.suggestion = @"Consider LOD generation or mesh optimization";
        issue.affectedObject = result.meshName;
        issue.objectIndex = meshIndex;
        [issues addObject:issue];
    }

    // TODO: Implement actual topology checks
    // For now, set conservative defaults
    result.hasNormals = YES;
    result.hasTangents = NO;
    result.hasTexCoords = YES;
    result.hasColors = NO;
    result.isManifold = YES;
    result.isWatertight = YES;
    result.degenerateTriangles = 0;
    result.duplicateVertices = 0;

    result.issues = [issues copy];
    return result;
}

// MARK: - Quick Checks

- (BOOL)isModelValid {
    ValidationOptions *options = [[ValidationOptions alloc] init];
    ModelValidationResult *result = [self validateModel:options];
    return result.isValid;
}

- (NSInteger)getTotalIssueCount {
    ValidationOptions *options = [[ValidationOptions alloc] init];
    ModelValidationResult *result = [self validateModel:options];
    return [result.issues count];
}

- (NSArray<ValidationIssue *> *)getCriticalIssues {
    ValidationOptions *options = [[ValidationOptions alloc] init];
    ModelValidationResult *result = [self validateModel:options];

    NSMutableArray<ValidationIssue *> *critical = [NSMutableArray array];
    for (ValidationIssue *issue in result.issues) {
        if (issue.severity == ValidationSeverityCritical) {
            [critical addObject:issue];
        }
    }

    return [critical copy];
}

// MARK: - Performance Analysis

- (PerformanceMetrics *)analyzePerformance {
    PerformanceMetrics *metrics = [[PerformanceMetrics alloc] init];

    auto model = _renderer->getModel();
    if (!model) return metrics;

    const auto& meshes = model->getMeshes();
    const auto& materials = model->getMaterials();
    const auto& textures = model->getTextures();

    // Mesh stats
    metrics.totalMeshes = (NSInteger)meshes.size();
    for (const auto& mesh : meshes) {
        NSInteger vertexCount = (NSInteger)mesh->getVertexCount();
        metrics.totalVertices += vertexCount;
        metrics.totalTriangles += vertexCount / 3;
    }

    // Material stats
    metrics.totalMaterials = (NSInteger)materials.size();
    metrics.uniqueMaterials = (NSInteger)materials.size();  // Simplified

    // Texture stats
    metrics.totalTextures = (NSInteger)textures.size();

    // Estimate texture memory
    for (const auto& texture : textures) {
        // Rough estimate: assume 4 bytes per pixel average
        // TODO: Get actual texture dimensions
        metrics.totalTextureMemory += 2048 * 2048 * 4;  // Assuming 2K textures
    }

    // Draw calls (simplified: one per mesh for now)
    metrics.estimatedDrawCalls = metrics.totalMeshes;

    // Hierarchy
    metrics.totalNodes = metrics.totalMeshes;  // Simplified
    metrics.maxHierarchyDepth = 1;  // Simplified

    // Performance score (0-100)
    NSInteger score = 100;

    // Deduct points for high poly count
    if (metrics.totalTriangles > 1000000) {
        score -= 30;
    } else if (metrics.totalTriangles > 500000) {
        score -= 20;
    } else if (metrics.totalTriangles > 100000) {
        score -= 10;
    }

    // Deduct points for many draw calls
    if (metrics.estimatedDrawCalls > 100) {
        score -= 20;
    } else if (metrics.estimatedDrawCalls > 50) {
        score -= 10;
    }

    // Deduct points for high texture memory
    unsigned long long texMemMB = metrics.totalTextureMemory / (1024 * 1024);
    if (texMemMB > 200) {
        score -= 20;
    } else if (texMemMB > 100) {
        score -= 10;
    }

    metrics.performanceScore = MAX(0, score);

    // Performance rating
    if (metrics.performanceScore >= 80) {
        metrics.performanceRating = @"Excellent";
    } else if (metrics.performanceScore >= 60) {
        metrics.performanceRating = @"Good";
    } else if (metrics.performanceScore >= 40) {
        metrics.performanceRating = @"Fair";
    } else {
        metrics.performanceRating = @"Poor";
    }

    return metrics;
}

- (NSInteger)estimateDrawCalls {
    PerformanceMetrics *metrics = [self analyzePerformance];
    return metrics.estimatedDrawCalls;
}

- (unsigned long long)estimateMemoryUsage {
    PerformanceMetrics *metrics = [self analyzePerformance];

    // Vertex buffer memory
    unsigned long long vertexMem = metrics.totalVertices * sizeof(float) * 14;  // Approx vertex size

    // Index buffer memory
    unsigned long long indexMem = metrics.totalTriangles * 3 * sizeof(uint32_t);

    // Texture memory
    unsigned long long textureMem = metrics.totalTextureMemory;

    return vertexMem + indexMem + textureMem;
}

// MARK: - Mesh Topology Checks

+ (BOOL)isMeshManifold:(NSInteger)meshIndex model:(id)model {
    // TODO: Implement manifold check
    // A mesh is manifold if each edge is shared by exactly 2 faces
    return YES;  // Placeholder
}

+ (BOOL)isMeshWatertight:(NSInteger)meshIndex model:(id)model {
    // TODO: Implement watertight check
    // A mesh is watertight if it has no holes
    return YES;  // Placeholder
}

+ (NSInteger)findDegenerateTriangles:(NSInteger)meshIndex model:(id)model {
    // TODO: Implement degenerate triangle detection
    // Degenerate = zero area or collinear vertices
    return 0;  // Placeholder
}

+ (NSInteger)findDuplicateVertices:(NSInteger)meshIndex model:(id)model {
    // TODO: Implement duplicate vertex detection
    return 0;  // Placeholder
}

// MARK: - Hierarchy Analysis

- (NSInteger)calculateHierarchyDepth {
    // TODO: Implement hierarchy depth calculation
    return 1;  // Placeholder
}

- (NSArray<NSString *> *)findNamingIssues {
    // TODO: Check for unnamed nodes, duplicate names, etc.
    return @[];  // Placeholder
}

// MARK: - Export

+ (BOOL)exportValidationReport:(ModelValidationResult *)result
                       filePath:(NSString *)logPath {
    NSMutableString *log = [NSMutableString string];

    // Header
    [log appendString:@"===========================================\n"];
    [log appendString:@"  Pinnacle Model Validation Report\n"];
    [log appendString:@"===========================================\n\n"];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [log appendFormat:@"Date: %@\n", [formatter stringFromDate:[NSDate date]]];
    [log appendFormat:@"Model: %@\n", result.modelPath];
    [log appendFormat:@"Format: %@\n\n", result.modelFormat];

    // Summary
    [log appendString:@"VALIDATION SUMMARY\n"];
    [log appendString:@"------------------\n"];
    [log appendFormat:@"Status: %@\n", result.isValid ? @"VALID" : @"INVALID"];
    [log appendFormat:@"Info: %ld\n", (long)result.infoCount];
    [log appendFormat:@"Warnings: %ld\n", (long)result.warningCount];
    [log appendFormat:@"Errors: %ld\n", (long)result.errorCount];
    [log appendFormat:@"Critical: %ld\n\n", (long)result.criticalCount];

    // Performance metrics
    if (result.metrics) {
        [log appendString:@"PERFORMANCE METRICS\n"];
        [log appendString:@"-------------------\n"];
        [log appendFormat:@"Performance Score: %ld/100 (%@)\n",
         (long)result.metrics.performanceScore, result.metrics.performanceRating];
        [log appendFormat:@"Total Vertices: %ld\n", (long)result.metrics.totalVertices];
        [log appendFormat:@"Total Triangles: %ld\n", (long)result.metrics.totalTriangles];
        [log appendFormat:@"Total Meshes: %ld\n", (long)result.metrics.totalMeshes];
        [log appendFormat:@"Draw Calls: %ld\n", (long)result.metrics.estimatedDrawCalls];
        [log appendFormat:@"Texture Memory: %.2f MB\n\n",
         result.metrics.totalTextureMemory / (1024.0 * 1024.0)];
    }

    // Issues
    if ([result.issues count] > 0) {
        [log appendString:@"ISSUES\n"];
        [log appendString:@"------\n\n"];

        for (ValidationIssue *issue in result.issues) {
            NSString *severityStr = @"";
            switch (issue.severity) {
                case ValidationSeverityInfo:
                    severityStr = @"INFO";
                    break;
                case ValidationSeverityWarning:
                    severityStr = @"WARNING";
                    break;
                case ValidationSeverityError:
                    severityStr = @"ERROR";
                    break;
                case ValidationSeverityCritical:
                    severityStr = @"CRITICAL";
                    break;
            }

            [log appendFormat:@"[%@] %@\n", severityStr, issue.title];
            [log appendFormat:@"  %@\n", issue.message];
            if (issue.affectedObject && [issue.affectedObject length] > 0) {
                [log appendFormat:@"  Affected: %@\n", issue.affectedObject];
            }
            if (issue.suggestion && [issue.suggestion length] > 0) {
                [log appendFormat:@"  Suggestion: %@\n", issue.suggestion];
            }
            [log appendString:@"\n"];
        }
    }

    // Recommendations
    if ([result.recommendations count] > 0) {
        [log appendString:@"RECOMMENDATIONS\n"];
        [log appendString:@"---------------\n\n"];

        for (NSString *rec in result.recommendations) {
            [log appendFormat:@"• %@\n", rec];
        }
        [log appendString:@"\n"];
    }

    // Mesh details
    if ([result.meshResults count] > 0) {
        [log appendString:@"MESH DETAILS\n"];
        [log appendString:@"------------\n\n"];

        for (MeshValidationResult *meshResult in result.meshResults) {
            [log appendFormat:@"[%ld] %@\n", (long)meshResult.meshIndex, meshResult.meshName];
            [log appendFormat:@"  Vertices: %ld\n", (long)meshResult.vertexCount];
            [log appendFormat:@"  Triangles: %ld\n", (long)meshResult.triangleCount];
            [log appendFormat:@"  Normals: %@\n", meshResult.hasNormals ? @"YES" : @"NO"];
            [log appendFormat:@"  Tex Coords: %@\n", meshResult.hasTexCoords ? @"YES" : @"NO"];
            [log appendFormat:@"  Manifold: %@\n", meshResult.isManifold ? @"YES" : @"NO"];
            [log appendFormat:@"  Watertight: %@\n", meshResult.isWatertight ? @"YES" : @"NO"];
            [log appendString:@"\n"];
        }
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
