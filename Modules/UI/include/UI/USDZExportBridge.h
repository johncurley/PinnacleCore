#ifndef USDZExportBridge_h
#define USDZExportBridge_h

#import <Foundation/Foundation.h>

/// Result of USDZ conversion
@interface USDZConversionResult : NSObject

@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong) NSString *outputPath;
@property (nonatomic, strong) NSString *errorMessage;

@end

/// Bridge for USDZ export and AR Quick Look functionality
@interface USDZExportBridge : NSObject

/// Convert glTF/GLB file to USDZ format
/// @param inputPath Path to input glTF or GLB file
/// @param outputPath Path for output USDZ file (optional, will auto-generate if nil)
/// @return Conversion result with success status and output path
+ (USDZConversionResult*)convertToUSDZ:(NSString*)inputPath outputPath:(NSString*)outputPath;

/// Check if usdz_converter is available on the system
+ (BOOL)isUSDZConverterAvailable;

/// Open file in AR Quick Look
/// @param usdzPath Path to USDZ file
+ (void)openInARQuickLook:(NSString*)usdzPath;

@end

#endif /* USDZExportBridge_h */
