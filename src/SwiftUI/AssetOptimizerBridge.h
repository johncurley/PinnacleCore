#ifndef AssetOptimizerBridge_h
#define AssetOptimizerBridge_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "MaterialFixerBridge.h"
#import "TextureManagerBridge.h"

// Forward declarations
class PinnacleMetalRenderer;

// MARK: - Optimization Profiles

typedef NS_ENUM(NSInteger, OptimizationProfile) {
    OptimizationProfileCustom,
    OptimizationProfileMobile,         // Aggressive optimization for mobile
    OptimizationProfileDesktop,        // Balanced optimization for desktop
    OptimizationProfileVR,            // VR-specific optimizations
    OptimizationProfileAR,            // AR Quick Look optimizations
    OptimizationProfileWeb,           // WebGL/glTF viewer optimizations
    OptimizationProfileConsole        // Console (PS5, Xbox) optimizations
};

// MARK: - Optimization Settings

@interface OptimizationSettings : NSObject

// Profile
@property (nonatomic, assign) OptimizationProfile profile;
@property (nonatomic, strong) NSString *profileName;

// Materials
@property (nonatomic, assign) BOOL fixMaterials;
@property (nonatomic, assign) BOOL validateMaterials;
@property (nonatomic, assign) TargetEngine targetEngine;

// Textures
@property (nonatomic, assign) BOOL optimizeTextures;
@property (nonatomic, assign) BOOL resizeTextures;
@property (nonatomic, assign) NSInteger maxTextureResolution;
@property (nonatomic, assign) BOOL compressTextures;
@property (nonatomic, assign) BOOL generateMipmaps;
@property (nonatomic, assign) BOOL removeDuplicateTextures;
@property (nonatomic, assign) BOOL removeUnusedTextures;

// Meshes
@property (nonatomic, assign) BOOL optimizeMeshes;
@property (nonatomic, assign) NSInteger maxVerticesPerMesh;
@property (nonatomic, assign) NSInteger maxTrianglesPerMesh;
@property (nonatomic, assign) BOOL removeDegenerateTriangles;
@property (nonatomic, assign) BOOL mergeDuplicateVertices;

// Hierarchy
@property (nonatomic, assign) BOOL optimizeHierarchy;
@property (nonatomic, assign) BOOL flattenHierarchy;
@property (nonatomic, assign) NSInteger maxHierarchyDepth;

// Output
@property (nonatomic, assign) BOOL embedTextures;
@property (nonatomic, assign) BOOL makePathsRelative;

// Create preset profiles
+ (instancetype)mobileProfile;
+ (instancetype)desktopProfile;
+ (instancetype)vrProfile;
+ (instancetype)arProfile;
+ (instancetype)webProfile;
+ (instancetype)consoleProfile;

@end

// MARK: - Optimization Statistics

@interface OptimizationStatistics : NSObject

// Before optimization
@property (nonatomic, assign) NSInteger vertexCountBefore;
@property (nonatomic, assign) NSInteger triangleCountBefore;
@property (nonatomic, assign) unsigned long long textureSizeBefore;
@property (nonatomic, assign) NSInteger drawCallsBefore;
@property (nonatomic, assign) unsigned long long totalSizeBefore;

// After optimization
@property (nonatomic, assign) NSInteger vertexCountAfter;
@property (nonatomic, assign) NSInteger triangleCountAfter;
@property (nonatomic, assign) unsigned long long textureSizeAfter;
@property (nonatomic, assign) NSInteger drawCallsAfter;
@property (nonatomic, assign) unsigned long long totalSizeAfter;

// Savings
@property (nonatomic, assign) NSInteger vertexReduction;
@property (nonatomic, assign) NSInteger triangleReduction;
@property (nonatomic, assign) unsigned long long textureSavings;
@property (nonatomic, assign) NSInteger drawCallReduction;
@property (nonatomic, assign) unsigned long long totalSavings;

// Percentages
@property (nonatomic, assign) float vertexReductionPercent;
@property (nonatomic, assign) float triangleReductionPercent;
@property (nonatomic, assign) float textureSavingsPercent;
@property (nonatomic, assign) float drawCallReductionPercent;
@property (nonatomic, assign) float totalSavingsPercent;

// Categories optimized
@property (nonatomic, assign) NSInteger materialsFixed;
@property (nonatomic, assign) NSInteger texturesOptimized;
@property (nonatomic, assign) NSInteger meshesOptimized;
@property (nonatomic, assign) NSInteger duplicatesRemoved;

@end

// MARK: - Optimization Result

@interface OptimizationResult : NSObject

@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong) NSString *errorMessage;

// Statistics
@property (nonatomic, strong) OptimizationStatistics *statistics;

// Detailed results
@property (nonatomic, strong) NSArray<NSString *> *optimizationsApplied;
@property (nonatomic, strong) NSArray<NSString *> *warnings;
@property (nonatomic, strong) NSArray<NSString *> *errors;

// Processing time
@property (nonatomic, assign) NSTimeInterval processingTime;

@end

// MARK: - Optimization Preview

@interface OptimizationPreview : NSObject

@property (nonatomic, strong) OptimizationStatistics *predictedStatistics;
@property (nonatomic, strong) NSArray<NSString *> *plannedOptimizations;
@property (nonatomic, assign) NSTimeInterval estimatedTime;

@end

// MARK: - Asset Optimizer Bridge

@interface AssetOptimizerBridge : NSObject

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer;

// Profile management
+ (NSArray<NSString *> *)availableProfiles;
+ (OptimizationSettings *)settingsForProfile:(OptimizationProfile)profile;

// Analysis
- (OptimizationStatistics *)analyzeCurrentState;
- (OptimizationPreview *)previewOptimization:(OptimizationSettings *)settings;

// Optimization
- (OptimizationResult *)optimizeWithSettings:(OptimizationSettings *)settings;

// Undo (if possible)
- (BOOL)canUndo;
- (BOOL)undoOptimization;

// Export
+ (BOOL)exportOptimizationReport:(OptimizationResult *)result
                         filePath:(NSString *)logPath;

@end

#endif /* AssetOptimizerBridge_h */
