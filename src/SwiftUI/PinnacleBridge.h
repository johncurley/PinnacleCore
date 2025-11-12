#ifndef PinnacleBridge_h
#define PinnacleBridge_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#ifdef __cplusplus
// Forward declaration of the C++ interface
class IPinnacleMetalRenderer;
#endif

// Declare PinnacleMetalView as an NSObject, it will internally manage an MTKView
@interface PinnacleMetalView : NSObject

- (nonnull instancetype)initWithFrame:(CGRect)frameRect;
- (void)loadModel:(nonnull NSString *)filename;

// Add a method to get the underlying NSView/MTKView for SwiftUI
- (nonnull NSView *)getMetalContentView;

@end

#endif /* PinnacleBridge_h */