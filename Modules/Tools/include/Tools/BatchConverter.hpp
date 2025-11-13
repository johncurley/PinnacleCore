#ifndef BatchConverterBridge_h
#define BatchConverterBridge_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

// Forward declarations
class PinnacleMetalRenderer;

// MARK: - Conversion Types

typedef NS_ENUM(NSInteger, ConversionFormat) {
    ConversionFormatGLTF,           // glTF with external files
    ConversionFormatGLB,            // glTF binary
    ConversionFormatUSDZ,           // Apple USDZ for AR
    ConversionFormatOBJ,            // Wavefront OBJ (future)
    ConversionFormatFBX             // Autodesk FBX (future)
};

typedef NS_ENUM(NSInteger, CoordinateSystem) {
    CoordinateSystemYUpRightHanded,  // glTF standard (Y-up, right-handed)
    CoordinateSystemYUpLeftHanded,   // Unity (Y-up, left-handed)
    CoordinateSystemZUpRightHanded,  // Blender (Z-up, right-handed)
    CoordinateSystemZUpLeftHanded    // Unreal (Z-up, left-handed)
};

typedef NS_ENUM(NSInteger, NormalMapFormat) {
    NormalMapFormatOpenGL,           // Standard OpenGL (glTF)
    NormalMapFormatDirectX           // DirectX (Y-inverted)
};

// MARK: - Conversion Options

@interface BatchConversionOptions : NSObject

// Format conversion
@property (nonatomic, assign) ConversionFormat targetFormat;
@property (nonatomic, assign) BOOL embedTextures;  // For glTF/GLB

// Coordinate system
@property (nonatomic, assign) BOOL convertCoordinates;
@property (nonatomic, assign) CoordinateSystem targetCoordinateSystem;

// Material options
@property (nonatomic, assign) BOOL fixMaterials;
@property (nonatomic, assign) BOOL validateMaterials;
@property (nonatomic, assign) TargetEngine targetEngine;  // From MaterialFixerBridge

// Normal maps
@property (nonatomic, assign) BOOL convertNormalMaps;
@property (nonatomic, assign) NormalMapFormat normalMapFormat;

// Texture options
@property (nonatomic, assign) BOOL fixTexturePaths;
@property (nonatomic, assign) BOOL copyTextures;

// Output options
@property (nonatomic, strong) NSString *outputDirectory;
@property (nonatomic, strong) NSString *filenameSuffix;  // e.g., "_converted"
@property (nonatomic, assign) BOOL overwriteExisting;

@end

// MARK: - Conversion Result

typedef NS_ENUM(NSInteger, ConversionStatus) {
    ConversionStatusSuccess,
    ConversionStatusWarning,        // Completed with warnings
    ConversionStatusFailed,
    ConversionStatusSkipped
};

@interface FileConversionResult : NSObject

@property (nonatomic, strong) NSString *inputPath;
@property (nonatomic, strong) NSString *outputPath;
@property (nonatomic, assign) ConversionStatus status;
@property (nonatomic, strong) NSArray<NSString *> *warnings;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, assign) NSTimeInterval processingTime;

// Statistics
@property (nonatomic, assign) NSInteger meshCount;
@property (nonatomic, assign) NSInteger materialCount;
@property (nonatomic, assign) NSInteger textureCount;
@property (nonatomic, assign) NSInteger issuesFixed;

@end

@interface BatchConversionResult : NSObject

@property (nonatomic, strong) NSArray<FileConversionResult *> *results;
@property (nonatomic, assign) NSInteger totalFiles;
@property (nonatomic, assign) NSInteger successCount;
@property (nonatomic, assign) NSInteger warningCount;
@property (nonatomic, assign) NSInteger failureCount;
@property (nonatomic, assign) NSInteger skippedCount;
@property (nonatomic, assign) NSTimeInterval totalTime;

@end

// MARK: - Progress Callback

typedef void (^BatchConversionProgressCallback)(NSInteger currentFile, NSInteger totalFiles, NSString *currentFilename);

// MARK: - Batch Converter Bridge

@interface BatchConverterBridge : NSObject

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer;

// File discovery
+ (NSArray<NSString *> *)discoverFilesInDirectory:(NSString *)directory
                                         recursive:(BOOL)recursive
                                        extensions:(NSArray<NSString *> *)extensions;

// Single file conversion
- (FileConversionResult *)convertFile:(NSString *)inputPath
                              options:(BatchConversionOptions *)options;

// Batch conversion
- (BatchConversionResult *)convertFiles:(NSArray<NSString *> *)inputPaths
                                options:(BatchConversionOptions *)options
                       progressCallback:(BatchConversionProgressCallback)progressCallback;

// Format detection
+ (ConversionFormat)detectFormat:(NSString *)filePath;
+ (NSString *)fileExtensionForFormat:(ConversionFormat)format;

// Validation
+ (BOOL)canConvertFrom:(ConversionFormat)fromFormat to:(ConversionFormat)toFormat;
+ (NSArray<NSString *> *)supportedInputExtensions;

// Export results
+ (BOOL)exportResultsToLog:(BatchConversionResult *)result
                   filePath:(NSString *)logPath;

@end

#endif /* BatchConverterBridge_h */
