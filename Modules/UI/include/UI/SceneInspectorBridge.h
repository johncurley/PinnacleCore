#import <Foundation/Foundation.h>

/**
 * Scene statistics for display in inspector
 */
@interface SceneStatistics : NSObject
@property (nonatomic, assign) NSInteger meshCount;
@property (nonatomic, assign) NSInteger triangleCount;
@property (nonatomic, assign) NSInteger vertexCount;
@property (nonatomic, assign) NSInteger materialCount;
@property (nonatomic, assign) NSInteger textureCount;
@property (nonatomic, assign) double textureMemoryMB;
@property (nonatomic, strong) NSArray<NSNumber *> *boundingBox; // [minX, minY, minZ, maxX, maxY, maxZ]
@end

/**
 * Individual mesh information
 */
@interface MeshInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSInteger triangleCount;
@property (nonatomic, assign) NSInteger vertexCount;
@property (nonatomic, strong) NSString *materialName;
@property (nonatomic, assign) BOOL hasNormals;
@property (nonatomic, assign) BOOL hasTexCoords;
@end

/**
 * Material information
 */
@interface MaterialInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) float metallicFactor;
@property (nonatomic, assign) float roughnessFactor;
@property (nonatomic, strong) NSArray<NSNumber *> *baseColorFactor; // [r, g, b, a]
@property (nonatomic, assign) BOOL hasBaseColorTexture;
@property (nonatomic, assign) BOOL hasMetallicRoughnessTexture;
@property (nonatomic, assign) BOOL hasNormalTexture;
@property (nonatomic, strong) NSString *baseColorTexturePath;
@end

/**
 * Bridge for scene inspection
 */
@interface SceneInspectorBridge : NSObject

- (instancetype)initWithRenderer:(void*)renderer;

/**
 * Get overall scene statistics
 */
- (SceneStatistics*)getStatistics;

/**
 * Get list of all meshes in the scene
 */
- (NSArray<MeshInfo*>*)getMeshes;

/**
 * Get list of all materials in the scene
 */
- (NSArray<MaterialInfo*>*)getMaterials;

/**
 * Check if a model is currently loaded
 */
- (BOOL)hasLoadedModel;

@end
