#import "BatchConverterBridge.h"
#import "PinnacleMetalRenderer.h"
#import "MaterialFixerBridge.h"
#import "USDZExportBridge.h"
#import <Metal/Metal.h>

// MARK: - BatchConversionOptions Implementation

@implementation BatchConversionOptions

- (instancetype)init {
    self = [super init];
    if (self) {
        _targetFormat = ConversionFormatGLB;
        _embedTextures = YES;
        _convertCoordinates = NO;
        _targetCoordinateSystem = CoordinateSystemYUpRightHanded;
        _fixMaterials = YES;
        _validateMaterials = YES;
        _targetEngine = TargetEngineGenericPBR;
        _convertNormalMaps = NO;
        _normalMapFormat = NormalMapFormatOpenGL;
        _fixTexturePaths = YES;
        _copyTextures = NO;
        _outputDirectory = nil;
        _filenameSuffix = @"_converted";
        _overwriteExisting = NO;
    }
    return self;
}

@end

// MARK: - FileConversionResult Implementation

@implementation FileConversionResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _inputPath = @"";
        _outputPath = @"";
        _status = ConversionStatusFailed;
        _warnings = @[];
        _errorMessage = nil;
        _processingTime = 0.0;
        _meshCount = 0;
        _materialCount = 0;
        _textureCount = 0;
        _issuesFixed = 0;
    }
    return self;
}

@end

// MARK: - BatchConversionResult Implementation

@implementation BatchConversionResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _results = @[];
        _totalFiles = 0;
        _successCount = 0;
        _warningCount = 0;
        _failureCount = 0;
        _skippedCount = 0;
        _totalTime = 0.0;
    }
    return self;
}

@end

// MARK: - BatchConverterBridge Implementation

@implementation BatchConverterBridge {
    PinnacleMetalRenderer* _renderer;
}

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer {
    self = [super init];
    if (self) {
        _renderer = renderer;
    }
    return self;
}

// MARK: - File Discovery

+ (NSArray<NSString *> *)discoverFilesInDirectory:(NSString *)directory
                                         recursive:(BOOL)recursive
                                        extensions:(NSArray<NSString *> *)extensions {
    NSMutableArray<NSString *> *files = [NSMutableArray array];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSArray *keys = @[NSURLIsDirectoryKey, NSURLIsRegularFileKey];

    NSDirectoryEnumerationOptions options = 0;
    if (!recursive) {
        options = NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    }

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:[NSURL fileURLWithPath:directory]
                                          includingPropertiesForKeys:keys
                                                             options:options
                                                        errorHandler:nil];

    for (NSURL *url in enumerator) {
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if (![isDirectory boolValue]) {
            NSString *ext = [[url pathExtension] lowercaseString];
            if ([extensions containsObject:ext]) {
                [files addObject:[url path]];
            }
        }
    }

    return [files copy];
}

// MARK: - Single File Conversion

- (FileConversionResult *)convertFile:(NSString *)inputPath
                              options:(BatchConversionOptions *)options {
    FileConversionResult *result = [[FileConversionResult alloc] init];
    result.inputPath = inputPath;

    NSDate *startTime = [NSDate date];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];

    @try {
        // Validate input file exists
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:inputPath]) {
            result.status = ConversionStatusFailed;
            result.errorMessage = @"Input file does not exist";
            return result;
        }

        // Generate output path
        NSString *outputPath = [self generateOutputPath:inputPath options:options];
        result.outputPath = outputPath;

        // Check if output exists and overwrite policy
        if ([fileManager fileExistsAtPath:outputPath] && !options.overwriteExisting) {
            result.status = ConversionStatusSkipped;
            result.errorMessage = @"Output file exists and overwrite disabled";
            return result;
        }

        // Load the model
        std::string inputPathStr = [inputPath UTF8String];
        if (!_renderer->loadModelFromFile(inputPathStr)) {
            result.status = ConversionStatusFailed;
            result.errorMessage = @"Failed to load model";
            return result;
        }

        // Get model statistics
        auto model = _renderer->getModel();
        if (model) {
            result.meshCount = (NSInteger)model->getMeshes().size();
            result.materialCount = (NSInteger)model->getMaterials().size();
            result.textureCount = (NSInteger)model->getTextures().size();
        }

        // Fix materials if requested
        if (options.fixMaterials) {
            MaterialFixerBridge *materialFixer = [[MaterialFixerBridge alloc] initWithRenderer:_renderer];
            NSInteger fixedCount = [materialFixer autoFixMaterials];
            result.issuesFixed = fixedCount;

            if (fixedCount > 0) {
                [warnings addObject:[NSString stringWithFormat:@"Fixed %ld material issue(s)", (long)fixedCount]];
            }
        }

        // Validate materials if requested
        if (options.validateMaterials) {
            MaterialFixerBridge *materialFixer = [[MaterialFixerBridge alloc] initWithRenderer:_renderer];
            MaterialValidationResult *validation = [materialFixer validateMaterialsForEngine:options.targetEngine];

            for (MaterialIssue *issue in validation.issues) {
                if (issue.severity == MaterialIssueSeverityWarning || issue.severity == MaterialIssueSeverityError) {
                    [warnings addObject:issue.message];
                }
            }
        }

        // Perform format conversion
        BOOL conversionSuccess = NO;

        switch (options.targetFormat) {
            case ConversionFormatUSDZ: {
                // Use existing USDZ converter
                USDZConversionResult *usdzResult = [USDZExportBridge convertToUSDZ:inputPath
                                                                        outputPath:outputPath];
                conversionSuccess = usdzResult.success;
                if (!conversionSuccess) {
                    result.errorMessage = usdzResult.errorMessage;
                }
                break;
            }

            case ConversionFormatGLTF:
            case ConversionFormatGLB: {
                // For now, if we're converting between glTF formats, just copy
                // TODO: Implement proper glTF/GLB conversion
                ConversionFormat inputFormat = [BatchConverterBridge detectFormat:inputPath];

                if (inputFormat == options.targetFormat) {
                    // Same format, just copy
                    NSError *error = nil;
                    [fileManager copyItemAtPath:inputPath toPath:outputPath error:&error];
                    conversionSuccess = (error == nil);
                    if (!conversionSuccess) {
                        result.errorMessage = [error localizedDescription];
                    }
                } else {
                    // Different glTF format - would need tinygltf writer
                    [warnings addObject:@"glTF/GLB conversion not yet implemented, copied file"];
                    NSError *error = nil;
                    [fileManager copyItemAtPath:inputPath toPath:outputPath error:&error];
                    conversionSuccess = (error == nil);
                    if (!conversionSuccess) {
                        result.errorMessage = [error localizedDescription];
                    }
                }
                break;
            }

            case ConversionFormatOBJ:
            case ConversionFormatFBX: {
                result.errorMessage = @"OBJ and FBX export not yet implemented";
                conversionSuccess = NO;
                break;
            }
        }

        // Copy textures if requested
        if (options.copyTextures && conversionSuccess) {
            // TODO: Implement texture copying
            [warnings addObject:@"Texture copying not yet implemented"];
        }

        // Set final status
        if (conversionSuccess) {
            if ([warnings count] > 0) {
                result.status = ConversionStatusWarning;
            } else {
                result.status = ConversionStatusSuccess;
            }
        } else {
            result.status = ConversionStatusFailed;
            if (!result.errorMessage) {
                result.errorMessage = @"Conversion failed";
            }
        }

    } @catch (NSException *exception) {
        result.status = ConversionStatusFailed;
        result.errorMessage = [NSString stringWithFormat:@"Exception: %@", exception.reason];
    }

    result.warnings = [warnings copy];
    result.processingTime = [[NSDate date] timeIntervalSinceDate:startTime];

    return result;
}

// MARK: - Batch Conversion

- (BatchConversionResult *)convertFiles:(NSArray<NSString *> *)inputPaths
                                options:(BatchConversionOptions *)options
                       progressCallback:(BatchConversionProgressCallback)progressCallback {
    BatchConversionResult *batchResult = [[BatchConversionResult alloc] init];
    NSDate *startTime = [NSDate date];

    NSMutableArray<FileConversionResult *> *results = [NSMutableArray array];
    batchResult.totalFiles = [inputPaths count];

    NSInteger currentIndex = 0;
    for (NSString *inputPath in inputPaths) {
        currentIndex++;

        // Progress callback
        if (progressCallback) {
            NSString *filename = [[inputPath lastPathComponent] copy];
            progressCallback(currentIndex, batchResult.totalFiles, filename);
        }

        // Convert single file
        FileConversionResult *fileResult = [self convertFile:inputPath options:options];
        [results addObject:fileResult];

        // Update counters
        switch (fileResult.status) {
            case ConversionStatusSuccess:
                batchResult.successCount++;
                break;
            case ConversionStatusWarning:
                batchResult.warningCount++;
                break;
            case ConversionStatusFailed:
                batchResult.failureCount++;
                break;
            case ConversionStatusSkipped:
                batchResult.skippedCount++;
                break;
        }
    }

    batchResult.results = [results copy];
    batchResult.totalTime = [[NSDate date] timeIntervalSinceDate:startTime];

    return batchResult;
}

// MARK: - Helper Methods

- (NSString *)generateOutputPath:(NSString *)inputPath
                         options:(BatchConversionOptions *)options {
    NSString *filename = [[inputPath lastPathComponent] stringByDeletingPathExtension];
    NSString *extension = [BatchConverterBridge fileExtensionForFormat:options.targetFormat];

    // Add suffix
    if (options.filenameSuffix && [options.filenameSuffix length] > 0) {
        filename = [filename stringByAppendingString:options.filenameSuffix];
    }

    NSString *outputFilename = [filename stringByAppendingPathExtension:extension];

    // Determine output directory
    NSString *outputDir = options.outputDirectory;
    if (!outputDir || [outputDir length] == 0) {
        outputDir = [inputPath stringByDeletingLastPathComponent];
    }

    return [outputDir stringByAppendingPathComponent:outputFilename];
}

// MARK: - Format Detection

+ (ConversionFormat)detectFormat:(NSString *)filePath {
    NSString *ext = [[filePath pathExtension] lowercaseString];

    if ([ext isEqualToString:@"gltf"]) {
        return ConversionFormatGLTF;
    } else if ([ext isEqualToString:@"glb"]) {
        return ConversionFormatGLB;
    } else if ([ext isEqualToString:@"usdz"]) {
        return ConversionFormatUSDZ;
    } else if ([ext isEqualToString:@"obj"]) {
        return ConversionFormatOBJ;
    } else if ([ext isEqualToString:@"fbx"]) {
        return ConversionFormatFBX;
    }

    return ConversionFormatGLTF; // Default
}

+ (NSString *)fileExtensionForFormat:(ConversionFormat)format {
    switch (format) {
        case ConversionFormatGLTF:
            return @"gltf";
        case ConversionFormatGLB:
            return @"glb";
        case ConversionFormatUSDZ:
            return @"usdz";
        case ConversionFormatOBJ:
            return @"obj";
        case ConversionFormatFBX:
            return @"fbx";
    }
}

// MARK: - Validation

+ (BOOL)canConvertFrom:(ConversionFormat)fromFormat to:(ConversionFormat)toFormat {
    // Currently support glTF/GLB as input
    if (fromFormat != ConversionFormatGLTF && fromFormat != ConversionFormatGLB) {
        return NO;
    }

    // Can convert to USDZ from glTF/GLB
    if (toFormat == ConversionFormatUSDZ) {
        return YES;
    }

    // Can convert between glTF and GLB
    if ((fromFormat == ConversionFormatGLTF || fromFormat == ConversionFormatGLB) &&
        (toFormat == ConversionFormatGLTF || toFormat == ConversionFormatGLB)) {
        return YES;
    }

    // OBJ and FBX not yet supported
    return NO;
}

+ (NSArray<NSString *> *)supportedInputExtensions {
    return @[@"gltf", @"glb", @"usdz"];
}

// MARK: - Export Results

+ (BOOL)exportResultsToLog:(BatchConversionResult *)result
                   filePath:(NSString *)logPath {
    NSMutableString *log = [NSMutableString string];

    // Header
    [log appendString:@"===========================================\n"];
    [log appendString:@"  Pinnacle Batch Conversion Results\n"];
    [log appendString:@"===========================================\n\n"];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [log appendFormat:@"Date: %@\n\n", [formatter stringFromDate:[NSDate date]]];

    // Summary
    [log appendString:@"SUMMARY\n"];
    [log appendString:@"-------\n"];
    [log appendFormat:@"Total Files:     %ld\n", (long)result.totalFiles];
    [log appendFormat:@"Successful:      %ld\n", (long)result.successCount];
    [log appendFormat:@"With Warnings:   %ld\n", (long)result.warningCount];
    [log appendFormat:@"Failed:          %ld\n", (long)result.failureCount];
    [log appendFormat:@"Skipped:         %ld\n", (long)result.skippedCount];
    [log appendFormat:@"Total Time:      %.2f seconds\n\n", result.totalTime];

    // Individual file results
    [log appendString:@"INDIVIDUAL RESULTS\n"];
    [log appendString:@"------------------\n\n"];

    for (FileConversionResult *fileResult in result.results) {
        NSString *statusStr = @"";
        switch (fileResult.status) {
            case ConversionStatusSuccess:
                statusStr = @"SUCCESS";
                break;
            case ConversionStatusWarning:
                statusStr = @"WARNING";
                break;
            case ConversionStatusFailed:
                statusStr = @"FAILED";
                break;
            case ConversionStatusSkipped:
                statusStr = @"SKIPPED";
                break;
        }

        [log appendFormat:@"[%@] %@\n", statusStr, [fileResult.inputPath lastPathComponent]];
        [log appendFormat:@"  Input:  %@\n", fileResult.inputPath];
        [log appendFormat:@"  Output: %@\n", fileResult.outputPath];
        [log appendFormat:@"  Time:   %.2f seconds\n", fileResult.processingTime];

        if (fileResult.meshCount > 0) {
            [log appendFormat:@"  Meshes: %ld, Materials: %ld, Textures: %ld\n",
             (long)fileResult.meshCount, (long)fileResult.materialCount, (long)fileResult.textureCount];
        }

        if (fileResult.issuesFixed > 0) {
            [log appendFormat:@"  Fixed:  %ld issue(s)\n", (long)fileResult.issuesFixed];
        }

        if ([fileResult.warnings count] > 0) {
            [log appendString:@"  Warnings:\n"];
            for (NSString *warning in fileResult.warnings) {
                [log appendFormat:@"    - %@\n", warning];
            }
        }

        if (fileResult.errorMessage) {
            [log appendFormat:@"  Error:  %@\n", fileResult.errorMessage];
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
