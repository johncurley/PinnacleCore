#ifndef PinnacleMetalRenderer_h
#define PinnacleMetalRenderer_h

#include "PinnacleMetalRendererInterface.h" // Include the interface
#include "Scene/Model.hpp" // For Pinnacle::Model
#include "ShaderEditor/ShaderEditor.hpp" // For shader hot-reload interface

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
@protocol MTLVertexDescriptor;

class PinnacleMetalRenderer : public IPinnacleMetalRenderer, public Pinnacle::RendererShaderInterface {
public:
    PinnacleMetalRenderer();
    ~PinnacleMetalRenderer();

    void loadModel(const char* filename) override;
    void draw(void* metalLayer) override; // void* representing CAMetalLayer*

    // Shader hot-reload interface
    bool setCustomPipelineState(id pipelineState) override;
    void resetToDefaultShaders() override;
    id getVertexDescriptor() override;
    id<MTLDevice> getDevice() const { return _pDevice; }

    // Scene inspection
    std::shared_ptr<Pinnacle::Model> getModel() const { return _pModel; }

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

    // Shader hot-reload support
    id<MTLRenderPipelineState> _pDefaultPipelineState;  // Original default pipeline
    id<MTLVertexDescriptor> _pVertexDescriptor;         // Cached vertex descriptor
    bool _usingCustomShader;                            // Flag for custom shader state

    void buildShaders();
    void drawModel(id<MTLRenderCommandEncoder> renderEncoder);
};

#endif /* PinnacleMetalRenderer_h */