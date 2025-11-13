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

    // Camera controls
    void resetCamera();
    void fitCameraToModel();
    void setCameraDistance(float distance);
    void orbitCamera(float deltaX, float deltaY);

    // Camera info getters
    simd_float3 getCameraPosition() const { return _cameraPosition; }
    simd_float3 getCameraLookAt() const { return _cameraLookAt; }
    float getCameraDistance() const;
    float getCameraFieldOfView() const { return _cameraFOV; }

    // Lighting controls
    void setLightDirection(simd_float3 direction);
    void setLightIntensity(float intensity);
    void setLightColor(simd_float3 color);
    simd_float3 getLightDirection() const { return _lightDirection; }
    float getLightIntensity() const { return _lightIntensity; }
    simd_float3 getLightColor() const { return _lightColor; }

    // Environment controls
    void setBackgroundColor(simd_float4 color);
    simd_float4 getBackgroundColor() const { return _backgroundColor; }

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

    // Camera state
    simd_float3 _cameraPosition;
    simd_float3 _cameraLookAt;
    simd_float3 _cameraUp;
    float _cameraFOV;          // Field of view in radians
    float _cameraNear;
    float _cameraFar;
    float _cameraOrbitTheta;   // Horizontal angle
    float _cameraOrbitPhi;     // Vertical angle

    // Lighting state
    simd_float3 _lightDirection;
    simd_float3 _lightColor;
    float _lightIntensity;

    // Environment state
    simd_float4 _backgroundColor;

    void buildShaders();
    void drawModel(id<MTLRenderCommandEncoder> renderEncoder);
    void updateCameraFromOrbit();
};

#endif /* PinnacleMetalRenderer_h */