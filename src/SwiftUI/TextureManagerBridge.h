#ifndef TextureManagerBridge_h
#define TextureManagerBridge_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

// Forward declarations
#ifdef __cplusplus
class PinnacleMetalRenderer;
#else
typedef void PinnacleMetalRenderer;
#endif

// MARK: - Texture Issue Types

typedef NS_ENUM(NSInteger, TextureIssueType) {
    TextureIssueTypeMissing,           // File not found
    TextureIssueTypeInvalidPath,       // Path format issues
    TextureIssueTypeAbsolutePath,      // Should be relative
    TextureIssueTypeWrongFormat,       // Non-optimal format
    TextureIssueTypeOversized,         // Resolution too large
    TextureIssueTypeUncompressed,      // Could benefit from compression
    TextureIssueTypeDuplicate,         // Duplicate content
    TextureIssueTypeUnused,            // Not referenced
    TextureIssueTypeMissingMipmaps,    // No mipmap chain
    TextureIssueTypeNonPowerOfTwo      // Non-POT dimensions
};

typedef NS_ENUM(NSInteger, TextureIssueSeverity) {
    TextureIssueSeverityInfo,
    TextureIssueSeverityWarning,
    TextureIssueSeverityError,
    TextureIssueSeverityCritical
};

// MARK: - Texture Issue

@interface TextureIssue : NSObject

@property (nonatomic, assign) TextureIssueType type;
@property (nonatomic, assign) TextureIssueSeverity severity;
@property (nonatomic, strong) NSString *textureName;
@property (nonatomic, strong) NSString *texturePath;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) NSString *suggestion;
@property (nonatomic, assign) NSInteger textureIndex;

// For duplicates
@property (nonatomic, strong) NSArray<NSNumber *> *duplicateIndices;

@end

// MARK: - Texture Info

@interface TextureInfo : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) BOOL exists;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger channels;
@property (nonatomic, assign) NSInteger bitDepth;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, strong) NSString *format;
@property (nonatomic, assign) BOOL hasMipmaps;
@property (nonatomic, assign) BOOL isPowerOfTwo;
@property (nonatomic, assign) NSInteger referenceCount;  // How many materials use it
@property (nonatomic, strong) NSArray<NSNumber *> *materialIndices;  // Which materials

@end

// MARK: - Texture Analysis Result

@interface TextureAnalysisResult : NSObject

@property (nonatomic, strong) NSArray<TextureInfo *> *textures;
@property (nonatomic, strong) NSArray<TextureIssue *> *issues;
@property (nonatomic, assign) NSInteger totalTextures;
@property (nonatomic, assign) NSInteger missingTextures;
@property (nonatomic, assign) NSInteger duplicateGroups;
@property (nonatomic, assign) NSInteger unusedTextures;
@property (nonatomic, assign) unsigned long long totalMemoryUsage;
@property (nonatomic, assign) unsigned long long potentialSavings;

@end

// MARK: - Texture Optimization Options

typedef NS_ENUM(NSInteger, TextureFormat) {
    TextureFormatPNG,
    TextureFormatJPEG,
    TextureFormatTGA,
    TextureFormatEXR,
    TextureFormatHDR,
    TextureFormatKTX,      // Khronos texture format
    TextureFormatBASIS     // Basis Universal (future)
};

typedef NS_ENUM(NSInteger, TextureResolution) {
    TextureResolution128 = 128,
    TextureResolution256 = 256,
    TextureResolution512 = 512,
    TextureResolution1024 = 1024,
    TextureResolution2048 = 2048,
    TextureResolution4096 = 4096,
    TextureResolution8192 = 8192,
    TextureResolutionOriginal = -1
};

@interface TextureOptimizationOptions : NSObject

// Format conversion
@property (nonatomic, assign) BOOL convertFormat;
@property (nonatomic, assign) TextureFormat targetFormat;
@property (nonatomic, assign) NSInteger jpegQuality;  // 0-100

// Resolution
@property (nonatomic, assign) BOOL scaleResolution;
@property (nonatomic, assign) TextureResolution maxResolution;
@property (nonatomic, assign) BOOL maintainAspectRatio;

// Compression
@property (nonatomic, assign) BOOL generateMipmaps;
@property (nonatomic, assign) BOOL compressTextures;

// Path fixing
@property (nonatomic, assign) BOOL fixPaths;
@property (nonatomic, assign) BOOL makePathsRelative;
@property (nonatomic, strong) NSString *basePath;

// Cleanup
@property (nonatomic, assign) BOOL removeDuplicates;
@property (nonatomic, assign) BOOL removeUnused;

// Output
@property (nonatomic, strong) NSString *outputDirectory;
@property (nonatomic, assign) BOOL copyTexturesToOutput;

@end

// MARK: - Texture Operation Result

@interface TextureOperationResult : NSObject

@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, assign) NSInteger texturesProcessed;
@property (nonatomic, assign) NSInteger texturesFixed;
@property (nonatomic, assign) NSInteger texturesOptimized;
@property (nonatomic, assign) NSInteger duplicatesRemoved;
@property (nonatomic, assign) unsigned long long sizeBefore;
@property (nonatomic, assign) unsigned long long sizeAfter;
@property (nonatomic, strong) NSArray<NSString *> *warnings;

@end

// MARK: - Texture Manager Bridge

@interface TextureManagerBridge : NSObject

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer;

// Analysis
- (TextureAnalysisResult *)analyzeTextures;
- (TextureInfo *)getTextureInfo:(NSInteger)textureIndex;
- (NSArray<TextureIssue *> *)validateTexture:(NSInteger)textureIndex;

// Path operations
- (BOOL)fixTexturePath:(NSInteger)textureIndex suggestedPath:(NSString *)path;
- (NSArray<NSString *> *)searchForMissingTexture:(NSString *)textureName
                                      inDirectory:(NSString *)directory
                                        recursive:(BOOL)recursive;
- (TextureOperationResult *)fixAllTexturePaths:(NSString *)baseDirectory;

// Optimization
- (TextureOperationResult *)optimizeTexture:(NSInteger)textureIndex
                                    options:(TextureOptimizationOptions *)options;
- (TextureOperationResult *)optimizeAllTextures:(TextureOptimizationOptions *)options;

// Cleanup
- (NSArray<NSNumber *> *)findDuplicateTextures;
- (NSArray<NSNumber *> *)findUnusedTextures;
- (TextureOperationResult *)removeDuplicateTextures;
- (TextureOperationResult *)removeUnusedTextures;

// Utilities
+ (NSDictionary<NSString *, id> *)getImageInfo:(NSString *)imagePath;
+ (BOOL)convertImage:(NSString *)inputPath
          outputPath:(NSString *)outputPath
              format:(TextureFormat)format
             quality:(NSInteger)quality;
+ (BOOL)resizeImage:(NSString *)inputPath
         outputPath:(NSString *)outputPath
         maxWidth:(NSInteger)maxWidth
        maxHeight:(NSInteger)maxHeight
  maintainAspect:(BOOL)maintainAspect;

// Export
+ (BOOL)exportAnalysisReport:(TextureAnalysisResult *)result
                     filePath:(NSString *)logPath;

@end

#endif /* TextureManagerBridge_h */
