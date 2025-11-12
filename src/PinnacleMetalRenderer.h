#ifndef PinnacleMetalRenderer_h
#define PinnacleMetalRenderer_h

#include "PinnacleMetalRendererInterface.h" // Include the interface
#include "tiny_gltf.h" // For tinygltf::Model

#include <string>
#include <iostream>
#include <vector>

// Forward declarations for Objective-C Metal types
@protocol MTLDevice;
@protocol MTLCommandQueue;
@protocol MTLLibrary;
@protocol MTLRenderPipelineState;
@protocol MTLBuffer;

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
    id<MTLBuffer> _pUniformBuffer; // Add uniform buffer

    // For glTF model data
    tinygltf::Model _gltfModel;
    std::vector<id<MTLBuffer>> _vertexBuffers;
    std::vector<id<MTLBuffer>> _indexBuffers;
    std::vector<MTLIndexType> _indexBufferTypes;

    void buildShaders();
    void setupModelBuffers(); // New method to process glTF data into Metal buffers
    void drawModel(id<MTLRenderCommandEncoder> renderEncoder);
};

#endif /* PinnacleMetalRenderer_h */