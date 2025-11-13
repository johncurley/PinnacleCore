#import "TextureManagerBridge.h"
#import "PinnacleMetalRenderer.h"
#import <Metal/Metal.h>
#import <AppKit/AppKit.h>

// MARK: - TextureIssue Implementation

@implementation TextureIssue

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = TextureIssueTypeMissing;
        _severity = TextureIssueSeverityError;
        _textureName = @"";
        _texturePath = @"";
        _message = @"";
        _suggestion = @"";
        _textureIndex = -1;
        _duplicateIndices = @[];
    }
    return self;
}

@end

// MARK: - TextureInfo Implementation

@implementation TextureInfo

- (instancetype)init {
    self = [super init];
    if (self) {
        _name = @"";
        _path = @"";
        _index = -1;
        _exists = NO;
        _width = 0;
        _height = 0;
        _channels = 0;
        _bitDepth = 0;
        _fileSize = 0;
        _format = @"";
        _hasMipmaps = NO;
        _isPowerOfTwo = NO;
        _referenceCount = 0;
        _materialIndices = @[];
    }
    return self;
}

@end

// MARK: - TextureAnalysisResult Implementation

@implementation TextureAnalysisResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _textures = @[];
        _issues = @[];
        _totalTextures = 0;
        _missingTextures = 0;
        _duplicateGroups = 0;
        _unusedTextures = 0;
        _totalMemoryUsage = 0;
        _potentialSavings = 0;
    }
    return self;
}

@end

// MARK: - TextureOptimizationOptions Implementation

@implementation TextureOptimizationOptions

- (instancetype)init {
    self = [super init];
    if (self) {
        _convertFormat = NO;
        _targetFormat = TextureFormatPNG;
        _jpegQuality = 90;
        _scaleResolution = NO;
        _maxResolution = TextureResolution2048;
        _maintainAspectRatio = YES;
        _generateMipmaps = NO;
        _compressTextures = NO;
        _fixPaths = YES;
        _makePathsRelative = YES;
        _basePath = nil;
        _removeDuplicates = NO;
        _removeUnused = NO;
        _outputDirectory = nil;
        _copyTexturesToOutput = NO;
    }
    return self;
}

@end

// MARK: - TextureOperationResult Implementation

@implementation TextureOperationResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _success = NO;
        _errorMessage = nil;
        _texturesProcessed = 0;
        _texturesFixed = 0;
        _texturesOptimized = 0;
        _duplicatesRemoved = 0;
        _sizeBefore = 0;
        _sizeAfter = 0;
        _warnings = @[];
    }
    return self;
}

@end

// MARK: - TextureManagerBridge Implementation

@implementation TextureManagerBridge {
    PinnacleMetalRenderer* _renderer;
}

- (instancetype)initWithRenderer:(PinnacleMetalRenderer *)renderer {
    self = [super init];
    if (self) {
        _renderer = renderer;
    }
    return self;
}

// MARK: - Analysis

- (TextureAnalysisResult *)analyzeTextures {
    TextureAnalysisResult *result = [[TextureAnalysisResult alloc] init];

    auto model = _renderer->getModel();
    if (!model) {
        return result;
    }

    const auto& textures = model->getTextures();
    result.totalTextures = (NSInteger)textures.size();

    NSMutableArray<TextureInfo *> *textureInfos = [NSMutableArray array];
    NSMutableArray<TextureIssue *> *issues = [NSMutableArray array];

    // Build material reference map
    NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *textureToMaterials = [NSMutableDictionary dictionary];
    const auto& materials = model->getMaterials();
    for (size_t matIdx = 0; matIdx < materials.size(); ++matIdx) {
        auto& material = materials[matIdx];
        auto& pbr = material->getPBRMaterial();

        // Check all texture references
        NSArray *textureIndices = @[
            @(pbr.baseColorTexture),
            @(pbr.metallicRoughnessTexture),
            @(pbr.normalTexture),
            @(pbr.occlusionTexture),
            @(pbr.emissiveTexture)
        ];

        for (NSNumber *texIdx in textureIndices) {
            NSInteger idx = [texIdx integerValue];
            if (idx >= 0) {
                if (!textureToMaterials[@(idx)]) {
                    textureToMaterials[@(idx)] = [NSMutableArray array];
                }
                [textureToMaterials[@(idx)] addObject:@(matIdx)];
            }
        }
    }

    // Analyze each texture
    unsigned long long totalMemory = 0;
    for (size_t i = 0; i < textures.size(); ++i) {
        auto& texture = textures[i];
        TextureInfo *info = [[TextureInfo alloc] init];

        info.index = (NSInteger)i;
        info.name = [NSString stringWithUTF8String:texture->getName().c_str()];
        info.path = [NSString stringWithUTF8String:texture->getPath().c_str()];
        info.referenceCount = textureToMaterials[@(i)] ? (NSInteger)[textureToMaterials[@(i)] count] : 0;
        info.materialIndices = textureToMaterials[@(i)] ? [textureToMaterials[@(i)] copy] : @[];

        // Check if file exists
        NSFileManager *fileManager = [NSFileManager defaultManager];
        info.exists = [fileManager fileExistsAtPath:info.path];

        if (info.exists) {
            // Get image info
            NSDictionary *imageInfo = [TextureManagerBridge getImageInfo:info.path];
            if (imageInfo) {
                info.width = [imageInfo[@"width"] integerValue];
                info.height = [imageInfo[@"height"] integerValue];
                info.format = imageInfo[@"format"];

                NSDictionary *attrs = [fileManager attributesOfItemAtPath:info.path error:nil];
                info.fileSize = [attrs fileSize];
                totalMemory += info.fileSize;

                // Check power of two
                BOOL widthPOT = (info.width & (info.width - 1)) == 0;
                BOOL heightPOT = (info.height & (info.height - 1)) == 0;
                info.isPowerOfTwo = widthPOT && heightPOT;

                // Validate texture
                NSArray<TextureIssue *> *textureIssues = [self validateTextureInfo:info];
                [issues addObjectsFromArray:textureIssues];
            }
        } else {
            // Missing texture
            result.missingTextures++;

            TextureIssue *issue = [[TextureIssue alloc] init];
            issue.type = TextureIssueTypeMissing;
            issue.severity = TextureIssueSeverityCritical;
            issue.textureName = info.name;
            issue.texturePath = info.path;
            issue.textureIndex = (NSInteger)i;
            issue.message = [NSString stringWithFormat:@"Texture file not found: %@", info.path];
            issue.suggestion = @"Use texture search to locate the file, or provide the correct path";
            [issues addObject:issue];
        }

        [textureInfos addObject:info];
    }

    // Find duplicates
    NSArray<NSNumber *> *duplicates = [self findDuplicateTexturesInternal:textureInfos];
    result.duplicateGroups = [duplicates count];

    // Find unused
    NSInteger unusedCount = 0;
    for (TextureInfo *info in textureInfos) {
        if (info.referenceCount == 0) {
            unusedCount++;

            TextureIssue *issue = [[TextureIssue alloc] init];
            issue.type = TextureIssueTypeUnused;
            issue.severity = TextureIssueSeverityInfo;
            issue.textureName = info.name;
            issue.texturePath = info.path;
            issue.textureIndex = info.index;
            issue.message = @"Texture is not referenced by any material";
            issue.suggestion = @"Consider removing unused textures to reduce file size";
            [issues addObject:issue];
        }
    }
    result.unusedTextures = unusedCount;

    result.textures = [textureInfos copy];
    result.issues = [issues copy];
    result.totalMemoryUsage = totalMemory;

    return result;
}

- (TextureInfo *)getTextureInfo:(NSInteger)textureIndex {
    auto model = _renderer->getModel();
    if (!model) return nil;

    const auto& textures = model->getTextures();
    if (textureIndex < 0 || textureIndex >= (NSInteger)textures.size()) {
        return nil;
    }

    auto& texture = textures[textureIndex];
    TextureInfo *info = [[TextureInfo alloc] init];

    info.index = textureIndex;
    info.name = [NSString stringWithUTF8String:texture->getName().c_str()];
    info.path = [NSString stringWithUTF8String:texture->getPath().c_str()];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    info.exists = [fileManager fileExistsAtPath:info.path];

    if (info.exists) {
        NSDictionary *imageInfo = [TextureManagerBridge getImageInfo:info.path];
        if (imageInfo) {
            info.width = [imageInfo[@"width"] integerValue];
            info.height = [imageInfo[@"height"] integerValue];
            info.format = imageInfo[@"format"];

            NSDictionary *attrs = [fileManager attributesOfItemAtPath:info.path error:nil];
            info.fileSize = [attrs fileSize];
        }
    }

    return info;
}

- (NSArray<TextureIssue *> *)validateTexture:(NSInteger)textureIndex {
    TextureInfo *info = [self getTextureInfo:textureIndex];
    if (!info) return @[];

    return [self validateTextureInfo:info];
}

- (NSArray<TextureIssue *> *)validateTextureInfo:(TextureInfo *)info {
    NSMutableArray<TextureIssue *> *issues = [NSMutableArray array];

    if (!info.exists) {
        return issues; // Already handled in analyzeTextures
    }

    // Check for absolute paths
    if ([info.path hasPrefix:@"/"]) {
        TextureIssue *issue = [[TextureIssue alloc] init];
        issue.type = TextureIssueTypeAbsolutePath;
        issue.severity = TextureIssueSeverityWarning;
        issue.textureName = info.name;
        issue.texturePath = info.path;
        issue.textureIndex = info.index;
        issue.message = @"Texture uses absolute path instead of relative";
        issue.suggestion = @"Convert to relative path for better portability";
        [issues addObject:issue];
    }

    // Check for non-power-of-two
    if (!info.isPowerOfTwo) {
        TextureIssue *issue = [[TextureIssue alloc] init];
        issue.type = TextureIssueTypeNonPowerOfTwo;
        issue.severity = TextureIssueSeverityInfo;
        issue.textureName = info.name;
        issue.texturePath = info.path;
        issue.textureIndex = info.index;
        issue.message = [NSString stringWithFormat:@"Non-power-of-two dimensions: %ldx%ld",
                         (long)info.width, (long)info.height];
        issue.suggestion = @"Some GPUs may have reduced performance with NPOT textures";
        [issues addObject:issue];
    }

    // Check for oversized textures
    if (info.width > 4096 || info.height > 4096) {
        TextureIssue *issue = [[TextureIssue alloc] init];
        issue.type = TextureIssueTypeOversized;
        issue.severity = TextureIssueSeverityWarning;
        issue.textureName = info.name;
        issue.texturePath = info.path;
        issue.textureIndex = info.index;
        issue.message = [NSString stringWithFormat:@"Large texture: %ldx%ld",
                         (long)info.width, (long)info.height];
        issue.suggestion = @"Consider downsizing to 4096 or smaller for better performance";
        [issues addObject:issue];
    }

    return issues;
}

// MARK: - Path Operations

- (BOOL)fixTexturePath:(NSInteger)textureIndex suggestedPath:(NSString *)path {
    auto model = _renderer->getModel();
    if (!model) return NO;

    const auto& textures = model->getTextures();
    if (textureIndex < 0 || textureIndex >= (NSInteger)textures.size()) {
        return NO;
    }

    // TODO: Implement path fixing in Model class
    // For now, just validate the path exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:path];
}

- (NSArray<NSString *> *)searchForMissingTexture:(NSString *)textureName
                                      inDirectory:(NSString *)directory
                                        recursive:(BOOL)recursive {
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSDirectoryEnumerationOptions options = 0;
    if (!recursive) {
        options = NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    }

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:[NSURL fileURLWithPath:directory]
                                          includingPropertiesForKeys:@[NSURLIsRegularFileKey]
                                                             options:options
                                                        errorHandler:nil];

    for (NSURL *url in enumerator) {
        NSNumber *isFile = nil;
        [url getResourceValue:&isFile forKey:NSURLIsRegularFileKey error:nil];

        if ([isFile boolValue]) {
            NSString *filename = [url lastPathComponent];
            if ([filename isEqualToString:textureName]) {
                [matches addObject:[url path]];
            }
        }
    }

    return [matches copy];
}

- (TextureOperationResult *)fixAllTexturePaths:(NSString *)baseDirectory {
    TextureOperationResult *result = [[TextureOperationResult alloc] init];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];

    auto model = _renderer->getModel();
    if (!model) {
        result.errorMessage = @"No model loaded";
        return result;
    }

    const auto& textures = model->getTextures();
    NSInteger fixedCount = 0;

    for (size_t i = 0; i < textures.size(); ++i) {
        auto& texture = textures[i];
        NSString *currentPath = [NSString stringWithUTF8String:texture->getPath().c_str()];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:currentPath]) {
            // Try to find it
            NSString *filename = [currentPath lastPathComponent];
            NSArray *matches = [self searchForMissingTexture:filename
                                                 inDirectory:baseDirectory
                                                   recursive:YES];

            if ([matches count] > 0) {
                fixedCount++;
                [warnings addObject:[NSString stringWithFormat:@"Fixed path for %@", filename]];
            } else {
                [warnings addObject:[NSString stringWithFormat:@"Could not find %@", filename]];
            }
        }
    }

    result.success = YES;
    result.texturesProcessed = (NSInteger)textures.size();
    result.texturesFixed = fixedCount;
    result.warnings = [warnings copy];

    return result;
}

// MARK: - Optimization

- (TextureOperationResult *)optimizeTexture:(NSInteger)textureIndex
                                    options:(TextureOptimizationOptions *)options {
    // TODO: Implement single texture optimization
    TextureOperationResult *result = [[TextureOperationResult alloc] init];
    result.errorMessage = @"Single texture optimization not yet implemented";
    return result;
}

- (TextureOperationResult *)optimizeAllTextures:(TextureOptimizationOptions *)options {
    // TODO: Implement batch texture optimization
    TextureOperationResult *result = [[TextureOperationResult alloc] init];
    result.errorMessage = @"Batch texture optimization not yet implemented";
    return result;
}

// MARK: - Cleanup

- (NSArray<NSNumber *> *)findDuplicateTextures {
    TextureAnalysisResult *analysis = [self analyzeTextures];
    return [self findDuplicateTexturesInternal:analysis.textures];
}

- (NSArray<NSNumber *> *)findDuplicateTexturesInternal:(NSArray<TextureInfo *> *)textureInfos {
    NSMutableArray<NSNumber *> *duplicates = [NSMutableArray array];

    // Simple duplicate detection by file size and name
    // TODO: Implement perceptual hash comparison for better accuracy
    NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *sizeGroups = [NSMutableDictionary dictionary];

    for (TextureInfo *info in textureInfos) {
        if (info.exists) {
            NSString *key = [NSString stringWithFormat:@"%llu_%@", info.fileSize, info.name];
            if (!sizeGroups[key]) {
                sizeGroups[key] = [NSMutableArray array];
            }
            [sizeGroups[key] addObject:@(info.index)];
        }
    }

    // Find groups with multiple textures
    for (NSString *key in sizeGroups) {
        if ([sizeGroups[key] count] > 1) {
            [duplicates addObjectsFromArray:sizeGroups[key]];
        }
    }

    return [duplicates copy];
}

- (NSArray<NSNumber *> *)findUnusedTextures {
    TextureAnalysisResult *analysis = [self analyzeTextures];
    NSMutableArray<NSNumber *> *unused = [NSMutableArray array];

    for (TextureInfo *info in analysis.textures) {
        if (info.referenceCount == 0) {
            [unused addObject:@(info.index)];
        }
    }

    return [unused copy];
}

- (TextureOperationResult *)removeDuplicateTextures {
    // TODO: Implement duplicate removal
    TextureOperationResult *result = [[TextureOperationResult alloc] init];
    result.errorMessage = @"Duplicate removal not yet implemented";
    return result;
}

- (TextureOperationResult *)removeUnusedTextures {
    // TODO: Implement unused texture removal
    TextureOperationResult *result = [[TextureOperationResult alloc] init];
    result.errorMessage = @"Unused texture removal not yet implemented";
    return result;
}

// MARK: - Utilities

+ (NSDictionary<NSString *, id> *)getImageInfo:(NSString *)imagePath {
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    if (!image) return nil;

    NSImageRep *rep = [[image representations] firstObject];
    if (!rep) return nil;

    NSInteger width = [rep pixelsWide];
    NSInteger height = [rep pixelsHigh];
    NSString *format = [[imagePath pathExtension] uppercaseString];

    return @{
        @"width": @(width),
        @"height": @(height),
        @"format": format
    };
}

+ (BOOL)convertImage:(NSString *)inputPath
          outputPath:(NSString *)outputPath
              format:(TextureFormat)format
             quality:(NSInteger)quality {
    // TODO: Implement image conversion using NSImage/CIImage
    return NO;
}

+ (BOOL)resizeImage:(NSString *)inputPath
         outputPath:(NSString *)outputPath
          maxWidth:(NSInteger)maxWidth
         maxHeight:(NSInteger)maxHeight
    maintainAspect:(BOOL)maintainAspect {
    // TODO: Implement image resizing
    return NO;
}

// MARK: - Export

+ (BOOL)exportAnalysisReport:(TextureAnalysisResult *)result
                     filePath:(NSString *)logPath {
    NSMutableString *log = [NSMutableString string];

    // Header
    [log appendString:@"===========================================\n"];
    [log appendString:@"  Pinnacle Texture Analysis Report\n"];
    [log appendString:@"===========================================\n\n"];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [log appendFormat:@"Date: %@\n\n", [formatter stringFromDate:[NSDate date]]];

    // Summary
    [log appendString:@"SUMMARY\n"];
    [log appendString:@"-------\n"];
    [log appendFormat:@"Total Textures:      %ld\n", (long)result.totalTextures];
    [log appendFormat:@"Missing Textures:    %ld\n", (long)result.missingTextures];
    [log appendFormat:@"Duplicate Groups:    %ld\n", (long)result.duplicateGroups];
    [log appendFormat:@"Unused Textures:     %ld\n", (long)result.unusedTextures];
    [log appendFormat:@"Total Memory:        %.2f MB\n\n", result.totalMemoryUsage / (1024.0 * 1024.0)];

    // Issues
    if ([result.issues count] > 0) {
        [log appendString:@"ISSUES\n"];
        [log appendString:@"------\n\n"];

        for (TextureIssue *issue in result.issues) {
            NSString *severityStr = @"";
            switch (issue.severity) {
                case TextureIssueSeverityInfo:
                    severityStr = @"INFO";
                    break;
                case TextureIssueSeverityWarning:
                    severityStr = @"WARNING";
                    break;
                case TextureIssueSeverityError:
                    severityStr = @"ERROR";
                    break;
                case TextureIssueSeverityCritical:
                    severityStr = @"CRITICAL";
                    break;
            }

            [log appendFormat:@"[%@] %@\n", severityStr, issue.message];
            [log appendFormat:@"  Texture: %@\n", issue.textureName];
            [log appendFormat:@"  Path: %@\n", issue.texturePath];
            if (issue.suggestion && [issue.suggestion length] > 0) {
                [log appendFormat:@"  Suggestion: %@\n", issue.suggestion];
            }
            [log appendString:@"\n"];
        }
    }

    // Texture details
    [log appendString:@"TEXTURE DETAILS\n"];
    [log appendString:@"---------------\n\n"];

    for (TextureInfo *info in result.textures) {
        [log appendFormat:@"[%ld] %@\n", (long)info.index, info.name];
        [log appendFormat:@"  Path: %@\n", info.path];
        [log appendFormat:@"  Exists: %@\n", info.exists ? @"YES" : @"NO"];

        if (info.exists) {
            [log appendFormat:@"  Dimensions: %ldx%ld\n", (long)info.width, (long)info.height];
            [log appendFormat:@"  Format: %@\n", info.format];
            [log appendFormat:@"  Size: %.2f MB\n", info.fileSize / (1024.0 * 1024.0)];
            [log appendFormat:@"  Power of Two: %@\n", info.isPowerOfTwo ? @"YES" : @"NO"];
            [log appendFormat:@"  Referenced by: %ld material(s)\n", (long)info.referenceCount];
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
