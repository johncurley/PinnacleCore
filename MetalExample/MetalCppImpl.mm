#define NS_PRIVATE_IMPLEMENTATION
#define CA_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION
#include <memory> // For std::unique_ptr
#include <cstdint> // Include cstdint explicitly, as it might be needed by metal-cpp

// Undefine system Metal header guards to prevent conflicts.
#ifdef __Metal_h
    #undef __Metal_h
#endif
#ifdef __MetalKit_h
    #undef __MetalKit_h
#endif

// Remove the problematic redefinition of _MTL_PRIVATE_DEF_STR.
// The original definition in metal-cpp should be used if it's compatible.
#ifdef _MTL_PRIVATE_DEF_STR
    #undef _MTL_PRIVATE_DEF_STR
#endif

// Include metal-cpp headers. These should now use their internal definitions
// without pulling in conflicting system headers.
// We include Foundation, Metal, and QuartzCore headers from metal-cpp.
#include <metal-cpp/Metal/Metal.hpp>
#include <metal-cpp/QuartzCore/QuartzCore.hpp>

#include "MetalView.h" // Include our own header file for MetalView

#include "../src/Renderer/Renderer.hpp" // Include the C++ renderer header
#include "../src/Core/Scene.hpp"
#include "../src/Core/InputManager.hpp"

/**
 * @brief C-style callback function for CVDisplayLink.
 * This function is called on a separate thread for each frame.
 * @param displayLinkContext A void* pointer to our MetalView instance.
 */
static CVReturn DisplayLinkCallback(CVDisplayLinkRef displayLink,
                                    const CVTimeStamp *now,
                                    const CVTimeStamp *outputTime,
                                    CVOptionFlags flagsIn,
                                    CVOptionFlags *flagsOut,
                                    void *displayLinkContext) {
    // Bridge the context back to our Objective-C/C++ object
    // and call the drawFrame method inside an autorelease pool.
    @autoreleasepool {
        // Cast the void pointer back to the Objective-C object pointer.
        // (__bridge MetalView *) is used for bridging Objective-C objects between ARC and non-ARC contexts.
        [(__bridge MetalView *)displayLinkContext drawFrame];
    }
    return kCVReturnSuccess;
}

// The implementation of MetalView methods follows.
// The @interface declaration is now in MetalView.h
@implementation MetalView
{
    // C++ objects are declared here
    std::unique_ptr<Renderer::Renderer> renderer;
    std::unique_ptr<Core::Scene> m_scene;
    std::unique_ptr<Core::InputManager> m_inputManager;
}

// 1. Initialize the view
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        // Tell NSView we want to use a Core Animation Layer
        // This is necessary for using CAMetalLayer.
        [self setWantsLayer:YES];

        // Initialize new C++ objects
        m_scene = std::make_unique<Core::Scene>();
        m_inputManager = std::make_unique<Core::InputManager>();

        // Initialize last frame time for delta time calculation.
        m_lastFrameTime = CACurrentMediaTime();
    }
    return self;
}

// 2. This is the key method:
// We override it to tell NSView to use a CAMetalLayer
// instead of a standard CALayer.
- (CALayer *)makeBackingLayer {
    // Create a CAMetalLayer.
    CA::MetalLayer* pMetalLayer = CA::MetalLayer::layer();
    
    // Set the initial size of the layer and its drawable.
    // convertSizeToBacking correctly handles scaling for Retina displays.
    CGSize backingSize = [self convertSizeToBacking:[self bounds].size];
    pMetalLayer->setDrawableSize(backingSize);
    
    // The layer is now created. We can initialize our C++ Renderer
    // and pass it a pointer to the layer.
    //
    // We use (__bridge void*) to cast the Objective-C object
    // to the opaque void* pointer that the C++ header expects.
    // The Renderer will not *own* the layer, so this is a
    // non-owning (unsafe) reference.
    
    // Create the Metal device.
    m_pMetalDevice = MTL::CreateSystemDefaultDevice(); // Initialize here
    if (!m_pMetalDevice) {
        NSLog(@"Failed to create Metal device in makeBackingLayer.");
        return nil; // Return nil if device creation fails.
    }

    // Initialize the C++ renderer, passing the Metal device.
    renderer = std::make_unique<Renderer::Renderer>((MTL::Device*)m_pMetalDevice);

    // Return the CAMetalLayer as a CALayer (Objective-C type).
    return (__bridge CALayer*)pMetalLayer;
}

// 3. Called when the view is added to or removed from a window
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow]; // Corrected method name

    if (self.window) {
        // When the view gets a window, ensure the drawable size is updated.
        CGSize backingSize = [self convertSizeToBacking:[self bounds].size];
        ((__bridge CA::MetalLayer*)self.layer)->setDrawableSize(backingSize);
        
        // --- Start the CVDisplayLink ---
        // If displayLink is not yet created, create and start it.
        if (!displayLink) {
            // Create the display link, which is needed for frame rate synchronization.
            CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

            // Set the callback function. This function will be called for each display refresh.
            // Pass `self` (the MetalView instance) as the context to the callback.
            CVDisplayLinkSetOutputCallback(displayLink, &DisplayLinkCallback, (__bridge void *)self);

            // Start the display link to begin receiving frame updates.
            CVDisplayLinkStart(displayLink);
        }
    }
    else {
        // --- Stop the CVDisplayLink ---
        // If the view is removed from the window, stop the display link.
        if (displayLink) {
            CVDisplayLinkStop(displayLink);
        }
    }
}

// 4. Our main draw method, called by the CVDisplayLink callback.
- (void)drawFrame {
    // Ensure the renderer is initialized.
    if (renderer) {
        // Calculate delta time for frame rate independence.
        CFTimeInterval currentTime = CACurrentMediaTime();
        float deltaTime = (float)(currentTime - m_lastFrameTime);
        m_lastFrameTime = currentTime;

        // Get the current drawable from the Metal layer.
        CA::MetalLayer* pMetalLayer = (__bridge CA::MetalLayer*)self.layer;
        MTL::Drawable* pDrawable = pMetalLayer->nextDrawable();
        if (!pDrawable)
        {
            // If no drawable is available (e.g., screen is being updated), return early.
            return;
        }

        // Create a command buffer to record Metal commands.
        MTL::CommandBuffer* pCommandBuffer = renderer->getCommandQueue()->commandBuffer();

        // Create a render pass descriptor. This describes the attachments (color, depth, stencil) 
        // that the render encoder will operate on.
        MTL::RenderPassDescriptor* pRenderPassDescriptor = MTL::RenderPassDescriptor::alloc()->init();
        
        // Configure the color attachment to use the drawable's texture.
        // Use LoadActionClear to clear the previous frame's content, and StoreActionStore to keep the rendered content.
        pRenderPassDescriptor->colorAttachments()->object(0)->setLoadAction(MTL::LoadActionClear);
        pRenderPassDescriptor->colorAttachments()->object(0)->setStoreAction(MTL::StoreActionStore);
        // Set the clear color to a dark gray.
        pRenderPassDescriptor->colorAttachments()->object(0)->setClearColor(MTL::ClearColor::Make(0.2f, 0.2f, 0.2f, 1.0f));

        // Create a depth attachment for depth testing...
        // Define texture descriptor for depth buffer.
        MTL::TextureDescriptor* pDepthTexDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatDepth32Float, pMetalLayer->drawableSize().width, pMetalLayer->drawableSize().height, false);
        pDepthTexDesc->setUsage(MTL::TextureUsageRenderTarget);
        // Create the depth texture.
        MTL::Texture* pDepthTexture = ((MTL::Device*)m_pMetalDevice)->newTexture(pDepthTexDesc);
        pDepthTexDesc->release(); // Release the descriptor as it's no longer needed.

        // Configure the depth attachment.
        pRenderPassDescriptor->depthAttachment()->setTexture(pDepthTexture);
        pRenderPassDescriptor->depthAttachment()->setLoadAction(MTL::LoadActionClear);
        pRenderPassDescriptor->depthAttachment()->setStoreAction(MTL::StoreActionDontCare); // Depth buffer content not needed after rendering.
        pRenderPassDescriptor->depthAttachment()->setClearDepth(1.0f); // Initialize depth to 1.0 (farthest).

        // Create a render command encoder.
        // This allows us to record commands for a render pass.
        MTL::RenderCommandEncoder* pRenderEncoder = pCommandBuffer->renderCommandEncoder(pRenderPassDescriptor);

        // Call the C++ draw() method to render the scene.
        // Pass the render encoder and the scene object.
        renderer->draw(pRenderEncoder, *m_scene);

        // End encoding, release resources, and commit the command buffer.
        pRenderEncoder->endEncoding();
        pRenderEncoder->release();
        pRenderPassDescriptor->release();
        pDepthTexture->release();

        // Present the drawable to the screen after all commands are recorded and committed.
        pCommandBuffer->presentDrawable(pDrawable);
        pCommandBuffer->commit();
    }
}

// 5. Called when the view's size changes (e.g., window resize).
- (void)layout {
    [super layout];
    if (renderer) {
        // Get the view's size in backing store coordinates (pixels).
        // This ensures the drawable size is updated correctly across different display scales.
        CGSize backingSize = [self convertSizeToBacking:[self bounds].size];
        ((__bridge CA::MetalLayer*)self.layer)->setDrawableSize(backingSize);
    }
}

// 6. Clean up the display link and Metal device when the view is deallocated.
- (void)dealloc {
    // Stop and release the display link.
    if (displayLink) {
        CVDisplayLinkStop(displayLink);
        CVDisplayLinkRelease(displayLink);
        displayLink = NULL;
    }
    // Release the Metal device.
    if (m_pMetalDevice) {
        ((MTL::Device*)m_pMetalDevice)->release();
        m_pMetalDevice = nullptr;
    }
    // The std::unique_ptr<Renderer> will automatically manage its own memory,
    // calling the C++ destructor when it goes out of scope.
}

// Mouse event handling
// These methods forward mouse events to the InputManager in the C++ scene.
- (void)mouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:[(NSEvent*)event locationInWindow] fromView:nil];
    simd_float2 point = {(float)locationInView.x, (float)locationInView.y};
    m_inputManager->mouseDown(point, m_scene->getCamera());
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:[(NSEvent*)event locationInWindow] fromView:nil];
    simd_float2 point = {(float)locationInView.x, (float)locationInWindow.y};
    m_inputManager->mouseDragged(point, m_scene->getCamera());
}

- (void)mouseUp:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:[(NSEvent*)event locationInWindow] fromView:nil];
    simd_float2 point = {(float)locationInView.x, (float)locationInWindow.y};
    m_inputManager->mouseUp(point, m_scene->getCamera());
}

// Method to load a model into the scene, called by the SwiftUI container.
- (void)loadModelAtPath:(NSString*)path {
    if (m_scene && m_pMetalDevice) {
        // Create a new Model object using the Metal device and the provided path.
        std::shared_ptr<Scene::Model> newModel = std::make_shared<Scene::Model>((MTL::Device*)m_pMetalDevice, std::string([path UTF8String]));
        // Add the new model to the scene.
        m_scene->addModel(newModel);
    }
}

@end