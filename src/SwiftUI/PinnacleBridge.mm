#import "PinnacleBridge.h"
#import <MetalKit/MetalKit.h> // Include MetalKit here
// Removed: #include <Metal/Metal.hpp> // metal-cpp is now handled in PinnacleMetalImplementation.mm
#include "../PinnacleMetalRendererInterface.h" // Include the C++ renderer interface declaration

@interface PinnacleMetalView () <MTKViewDelegate>
{
    IPinnacleMetalRenderer* _renderer; // Use the interface pointer
    MTKView* _mtkView; // Hold a reference to the MTKView
}
@end

@implementation PinnacleMetalView

- (nonnull instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super init]; // Inherit from NSObject
    if (self)
    {
        _mtkView = [[MTKView alloc] initWithFrame:frameRect device:MTLCreateSystemDefaultDevice()];
        _mtkView.delegate = self;
        // Do not add as subview here, it will be added by SwiftUI
        
        _renderer = createPinnacleMetalRenderer(); // Use the factory function
    }
    return self;
}

- (void)dealloc
{
    delete _renderer;
}

- (void)loadModel:(nonnull NSString *)filename
{
    _renderer->loadModel(filename.UTF8String);
}

- (nonnull NSView *)getMetalContentView
{
    return _mtkView;
}

- (nullable void *)getRenderer
{
    return _renderer;
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(nonnull MTKView *)view
{
    _renderer->draw((__bridge void*)view.layer); // Pass CAMetalLayer* as void*
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Handle drawable size changes here later
}

@end
