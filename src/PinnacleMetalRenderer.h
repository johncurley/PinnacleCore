#ifndef PinnacleMetalRenderer_h
#define PinnacleMetalRenderer_h

#include "PinnacleMetalRendererInterface.h" // Include the interface
#include "Scene/Model.hpp" // For Pinnacle::Model

#include <string>
#include <iostream>
#include <vector>
#include <memory>

// Forward declarations for Objective-C Metal types
@protocol MTLDevice;
@protocol MTLCommandQueue;
@protocol MTLLibrary;
@protocol MTLRenderPipelineState;
@protocol MTLBuffer;
@protocol MTLDepthStencilState;
@protocol MTLSamplerState;

class PinnacleMetalRenderer : public IPinnacleMetalRenderer {
public:
    PinnacleMetalRenderer();
    ~PinnacleMetalRenderer();

    void loadModel(const char* filename) override;
    void draw(void* metalLayer) override; // void* representing CAMetalLayer*

private:
    id<MTLDevice> _pDevice;
    id<MTLCommandQueue> _pCommandQueue;
    id<MTLLibrary> _pShaderLibrary;
    id<MTLRenderPipelineState> _pPipelineState;
    id<MTLDepthStencilState> _pDepthStencilState;
    id<MTLSamplerState> _pSamplerState;
    id<MTLBuffer> _pUniformBuffer;
    id<MTLBuffer> _pMaterialBuffer;
    id<MTLBuffer> _pLightBuffer;

    // Model data
    std::shared_ptr<Pinnacle::Model> _pModel;

    void buildShaders();
    void drawModel(id<MTLRenderCommandEncoder> renderEncoder);
};

#endif /* PinnacleMetalRenderer_h */