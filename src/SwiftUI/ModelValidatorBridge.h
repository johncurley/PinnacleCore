#ifndef ModelValidatorBridge_h
#define ModelValidatorBridge_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

// Forward declarations
class PinnacleMetalRenderer;

// MARK: - Validation Categories

typedef NS_ENUM(NSInteger, ValidationCategory) {
    ValidationCategoryFormat,           // File format issues
    ValidationCategoryMesh,             // Mesh topology issues
    ValidationCategoryMaterial,         // Material issues
    ValidationCategoryTexture,          // Texture issues
    ValidationCategoryHierarchy,        // Scene hierarchy issues
    ValidationCategoryAnimation,        // Animation issues
    ValidationCategoryPerformance,      // Performance concerns
    ValidationCategoryCompliance        // glTF spec compliance
};

typedef NS_ENUM(NSInteger, ValidationSeverity) {
    ValidationSeverityInfo,
    ValidationSeverityWarning,
    ValidationSeverityError,
    ValidationSeverityCritical
};

// MARK: - Validation Issue

@interface ValidationIssue : NSObject

@property (nonatomic, assign) ValidationCategory category;
@property (nonatomic, assign) ValidationSeverity severity;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) NSString *suggestion;
@property (nonatomic, strong) NSString *affectedObject;  // e.g., "Mesh[0]", "Material[2]"
@property (nonatomic, assign) NSInteger objectIndex;

@end

// MARK: - Mesh Validation

@interface MeshValidationResult : NSObject

@property (nonatomic, strong) NSString *meshName;
@property (nonatomic, assign) NSInteger meshIndex;
@property (nonatomic, assign) NSInteger vertexCount;
@property (nonatomic, assign) NSInteger triangleCount;
@property (nonatomic, assign) BOOL hasNormals;
@property (nonatomic, assign) BOOL hasTangents;
@property (nonatomic, assign) BOOL hasTexCoords;
@property (nonatomic, assign) BOOL hasColors;
@property (nonatomic, assign) BOOL isManifold;
@property (nonatomic, assign) BOOL isWatertight;
@property (nonatomic, assign) NSInteger degenerateTriangles;
@property (nonatomic, assign) NSInteger duplicateVertices;
@property (nonatomic, strong) NSArray<ValidationIssue *> *issues;

@end

// MARK: - Performance Metrics

@interface PerformanceMetrics : NSObject

// Mesh stats
@property (nonatomic, assign) NSInteger totalVertices;
@property (nonatomic, assign) NSInteger totalTriangles;
@property (nonatomic, assign) NSInteger totalMeshes;

// Material stats
@property (nonatomic, assign) NSInteger totalMaterials;
@property (nonatomic, assign) NSInteger uniqueMaterials;

// Texture stats
@property (nonatomic, assign) NSInteger totalTextures;
@property (nonatomic, assign) unsigned long long totalTextureMemory;

// Draw calls
@property (nonatomic, assign) NSInteger estimatedDrawCalls;

// Hierarchy
@property (nonatomic, assign) NSInteger totalNodes;
@property (nonatomic, assign) NSInteger maxHierarchyDepth;

// File size
@property (nonatomic, assign) unsigned long long fileSize;

// Performance rating (0-100)
@property (nonatomic, assign) NSInteger performanceScore;
@property (nonatomic, strong) NSString *performanceRating;  // "Excellent", "Good", "Fair", "Poor"

@end

// MARK: - Model Validation Result

@interface ModelValidationResult : NSObject

@property (nonatomic, strong) NSString *modelPath;
@property (nonatomic, strong) NSString *modelFormat;  // "glTF", "GLB", "USDZ"
@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, assign) BOOL isGLTFCompliant;

// Issue tracking
@property (nonatomic, strong) NSArray<ValidationIssue *> *issues;
@property (nonatomic, assign) NSInteger infoCount;
@property (nonatomic, assign) NSInteger warningCount;
@property (nonatomic, assign) NSInteger errorCount;
@property (nonatomic, assign) NSInteger criticalCount;

// Detailed results
@property (nonatomic, strong) NSArray<MeshValidationResult *> *meshResults;
@property (nonatomic, strong) PerformanceMetrics *metrics;

// Recommendations
@property (nonatomic, strong) NSArray<NSString *> *recommendations;

@end

// MARK: - Validation Options

@interface ValidationOptions : NSObject

// What to validate
@property (nonatomic, assign) BOOL validateFormat;
@property (nonatomic, assign) BOOL validateMeshTopology;
@property (nonatomic, assign) BOOL validateMaterials;
@property (nonatomic, assign) BOOL validateTextures;
@property (nonatomic, assign) BOOL validateHierarchy;
@property (nonatomic, assign) BOOL validateAnimations;
@property (nonatomic, assign) BOOL checkPerformance;
@property (nonatomic, assign) BOOL checkGLTFCompliance;

// Thresholds
@property (nonatomic, assign) NSInteger maxVerticesPerMesh;     // Default: 65535
@property (nonatomic, assign) NSInteger maxTrianglesPerMesh;    // Default: 50000
@property (nonatomic, assign) NSInteger maxTextureResolution;   // Default: 4096
@property (nonatomic, assign) NSInteger maxHierarchyDepth;      // Default: 10

// Target platform (affects performance checks)
@property (nonatomic, assign) TargetEngine targetEngine;  // From MaterialFixerBridge

@end

// MARK: - Format Support

typedef NS_ENUM(NSInteger, ModelFormat) {
    ModelFormatUnknown,
    ModelFormatGLTF,
    ModelFormatGLB,
    ModelFormatUSDZ,
    ModelFormatOBJ,
    ModelFormatFBX
};

// MARK: - Model Validator Bridge

@interface ModelValidatorBridge : NSObject

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer;

// Format detection and loading
+ (ModelFormat)detectFormat:(NSString *)filePath;
+ (NSString *)formatName:(ModelFormat)format;
+ (BOOL)isFormatSupported:(ModelFormat)format;

// Validation
- (ModelValidationResult *)validateModel:(ValidationOptions *)options;
- (MeshValidationResult *)validateMesh:(NSInteger)meshIndex;

// Quick checks
- (BOOL)isModelValid;
- (NSInteger)getTotalIssueCount;
- (NSArray<ValidationIssue *> *)getCriticalIssues;

// Performance analysis
- (PerformanceMetrics *)analyzePerformance;
- (NSInteger)estimateDrawCalls;
- (unsigned long long)estimateMemoryUsage;

// Mesh topology checks
+ (BOOL)isMeshManifold:(NSInteger)meshIndex model:(id)model;
+ (BOOL)isMeshWatertight:(NSInteger)meshIndex model:(id)model;
+ (NSInteger)findDegenerateTriangles:(NSInteger)meshIndex model:(id)model;
+ (NSInteger)findDuplicateVertices:(NSInteger)meshIndex model:(id)model;

// Hierarchy analysis
- (NSInteger)calculateHierarchyDepth;
- (NSArray<NSString *> *)findNamingIssues;

// Export
+ (BOOL)exportValidationReport:(ModelValidationResult *)result
                       filePath:(NSString *)logPath;

@end

#endif /* ModelValidatorBridge_h */
