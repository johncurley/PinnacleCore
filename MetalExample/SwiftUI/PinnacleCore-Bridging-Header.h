#import <Cocoa/Cocoa.h>

@objc
@interface MetalView : NSView

@objc
- (void)loadModelAtPath:(NSString*)path;
- (void)drawFrame;

@end
