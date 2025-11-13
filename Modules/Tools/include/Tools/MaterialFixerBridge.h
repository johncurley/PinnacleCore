#ifndef MaterialFixerBridge_h
#define MaterialFixerBridge_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

/// Material validation issue severity
typedef NS_ENUM(NSInteger, MaterialIssueSeverity) {
    MaterialIssueSeverityInfo,
    MaterialIssueSeverityWarning,
    MaterialIssueSeverityError
};

/// Material validation issue
@interface MaterialIssue : NSObject

@property (nonatomic, assign) MaterialIssueSeverity severity;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) NSString *materialName;
@property (nonatomic, strong) NSString *suggestion;

@end

/// Material validation result
@interface MaterialValidationResult : NSObject

@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, assign) NSInteger errorCount;
@property (nonatomic, assign) NSInteger warningCount;
@property (nonatomic, strong) NSArray<MaterialIssue *> *issues;

@end

/// Target engine for material conversion
typedef NS_ENUM(NSInteger, TargetEngine) {
    TargetEngineUnityBuiltIn,
    TargetEngineUnityURP,
    TargetEngineUnityHDRP,
    TargetEngineUnrealEngine,
    TargetEngineGodot,
    TargetEngineGenericPBR
};

/// PBR texture channel type
typedef NS_ENUM(NSInteger, PBRTextureChannel) {
    PBRTextureChannelBaseColor,
    PBRTextureChannelMetallic,
    PBRTextureChannelRoughness,
    PBRTextureChannelMetallicRoughness,
    PBRTextureChannelNormal,
    PBRTextureChannelAmbientOcclusion,
    PBRTextureChannelEmissive,
    PBRTextureChannelHeight
};

/// Material creation from textures
@interface MaterialCreationResult : NSObject

@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong) NSString *materialName;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, strong) NSDictionary<NSNumber *, NSString *> *assignedTextures;

@end

/// Bridge for material fixing and validation
@interface MaterialFixerBridge : NSObject

/// Initialize with renderer pointer
- (instancetype)initWithRenderer:(void*)renderer;

/// Validate materials in current model
- (MaterialValidationResult*)validateMaterials;

/// Validate materials for specific target engine
- (MaterialValidationResult*)validateMaterialsForEngine:(TargetEngine)engine;

/// Auto-fix common material issues
- (NSInteger)autoFixMaterials;

/// Create PBR material from drag-and-dropped textures
/// @param texturePaths Dictionary mapping PBRTextureChannel -> file path
/// @param materialName Name for the new material
+ (MaterialCreationResult*)createMaterialFromTextures:(NSDictionary<NSNumber *, NSString *> *)texturePaths
                                          materialName:(NSString *)materialName;

/// Detect texture channel type from filename
/// @param filename Texture filename (e.g., "wood_basecolor.png")
/// @return Detected channel type or -1 if unknown
+ (PBRTextureChannel)detectTextureChannel:(NSString *)filename;

/// Get recommended settings for target engine
+ (NSDictionary<NSString *, id> *)getRecommendedSettingsForEngine:(TargetEngine)engine;

@end

#endif /* MaterialFixerBridge_h */
