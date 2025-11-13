#import "USDZExportBridge.h"
#import <Quartz/Quartz.h>

@implementation USDZConversionResult
@end

@implementation USDZExportBridge

+ (USDZConversionResult*)convertToUSDZ:(NSString*)inputPath outputPath:(NSString*)outputPath {
    USDZConversionResult* result = [[USDZConversionResult alloc] init];

    // Check if input file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:inputPath]) {
        result.success = NO;
        result.errorMessage = [NSString stringWithFormat:@"Input file not found: %@", inputPath];
        return result;
    }

    // Generate output path if not provided
    NSString* finalOutputPath = outputPath;
    if (!finalOutputPath || [finalOutputPath length] == 0) {
        NSString* inputFileName = [[inputPath lastPathComponent] stringByDeletingPathExtension];
        NSString* tempDir = NSTemporaryDirectory();
        finalOutputPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.usdz", inputFileName]];
    }

    // Check if usdz_converter is available
    if (![self isUSDZConverterAvailable]) {
        result.success = NO;
        result.errorMessage = @"usdz_converter not found. Please install Xcode Command Line Tools.";
        return result;
    }

    // Create NSTask to run usdz_converter
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/xcrun"];
    [task setArguments:@[@"usdz_converter", inputPath, finalOutputPath]];

    // Capture output
    NSPipe* outputPipe = [NSPipe pipe];
    NSPipe* errorPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:errorPipe];

    // Launch the task
    @try {
        [task launch];
        [task waitUntilExit];

        int terminationStatus = [task terminationStatus];

        if (terminationStatus == 0) {
            // Success
            result.success = YES;
            result.outputPath = finalOutputPath;
            result.errorMessage = nil;
        } else {
            // Failure - read error output
            NSData* errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
            NSString* errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];

            result.success = NO;
            result.errorMessage = [NSString stringWithFormat:@"Conversion failed with status %d: %@",
                                  terminationStatus, errorString];
        }
    }
    @catch (NSException* exception) {
        result.success = NO;
        result.errorMessage = [NSString stringWithFormat:@"Exception during conversion: %@", exception.reason];
    }

    return result;
}

+ (BOOL)isUSDZConverterAvailable {
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/xcrun"];
    [task setArguments:@[@"--find", @"usdz_converter"]];

    // Redirect output to avoid displaying
    NSPipe* pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];

    @try {
        [task launch];
        [task waitUntilExit];
        return [task terminationStatus] == 0;
    }
    @catch (NSException* exception) {
        return NO;
    }
}

+ (void)openInARQuickLook:(NSString*)usdzPath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:usdzPath]) {
        NSLog(@"USDZ file not found: %@", usdzPath);
        return;
    }

    NSURL* fileURL = [NSURL fileURLWithPath:usdzPath];

    // Use QLPreviewPanel for AR Quick Look
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSWorkspace sharedWorkspace] openURL:fileURL];
    });
}

@end
