#pragma once

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CVDisplayLink.h>

@protocol MTLDevice;

// Forward declarations for C++ objects used in the implementation.
// These are needed because the instance variables are declared in the header.
#ifdef __cplusplus
namespace Renderer { class Renderer; }
namespace Core { class Scene; class InputManager; }
#endif

@interface MetalView : NSView
{
    // Instance variables that are Objective-C/C compatible can be declared here.
    CVDisplayLinkRef displayLink;
    CFTimeInterval m_lastFrameTime;
    id<MTLDevice> m_pMetalDevice; // Pointer to Metal device
}

// Methods declared here
- (instancetype)initWithFrame:(NSRect)frameRect;
- (CALayer *)makeBackingLayer;
- (void)viewDidMoveToWindow;
- (void)drawFrame;
- (void)layout;
- (void)dealloc;
- (void)mouseDown:(NSEvent *)event;
- (void)mouseDragged:(NSEvent *)event;
- (void)mouseUp:(NSEvent *)event;
- (void)loadModelAtPath:(NSString*)path;

@end