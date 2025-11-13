// Removed metal-cpp includes and defines
#import <MetalKit/MetalKit.h> // Include MetalKit for Objective-C Metal types
#import <Foundation/Foundation.h> // For NSBundle
#import <simd/simd.h>

#include "PinnacleMetalRenderer.h" // Include the concrete renderer declaration
#include "Scene/Model.hpp"
#include "Scene/Mesh.hpp"
#include "Scene/Material.hpp"

// Uniforms structure matching the shader
struct Uniforms {
    simd_float4x4 modelMatrix;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
    simd_float3 cameraPosition;
};

// Material uniforms matching the shader
struct MaterialUniforms {
    simd_float4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    int hasBaseColorTexture;
    int hasMetallicRoughnessTexture;
    int hasNormalTexture;
};

// Light structure matching the shader
struct Light {
    simd_float3 direction;
    simd_float3 color;
    float intensity;
};

// Implementation of PinnacleMetalRenderer methods
PinnacleMetalRenderer::PinnacleMetalRenderer() {
    _pDevice = MTLCreateSystemDefaultDevice();
    _pCommandQueue = [_pDevice newCommandQueue];
    _pShaderLibrary = nil;
    _pPipelineState = nil;
    _pDepthStencilState = nil;
    _pSamplerState = nil;
    _pUniformBuffer = nil;
    _pMaterialBuffer = nil;
    _pLightBuffer = nil;
    _pModel = nullptr;
    _pDefaultPipelineState = nil;
    _pVertexDescriptor = nil;
    _usingCustomShader = false;

    buildShaders();

    // Create depth stencil state
    MTLDepthStencilDescriptor* depthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    _pDepthStencilState = [_pDevice newDepthStencilStateWithDescriptor:depthDescriptor];
    [depthDescriptor release];

    // Create sampler state
    MTLSamplerDescriptor* samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    _pSamplerState = [_pDevice newSamplerStateWithDescriptor:samplerDescriptor];
    [samplerDescriptor release];

    // Create uniform buffers
    _pUniformBuffer = [_pDevice newBufferWithLength:sizeof(Uniforms) options:MTLResourceStorageModeShared];
    _pMaterialBuffer = [_pDevice newBufferWithLength:sizeof(MaterialUniforms) options:MTLResourceStorageModeShared];
    _pLightBuffer = [_pDevice newBufferWithLength:sizeof(Light) options:MTLResourceStorageModeShared];

    // Initialize lighting state
    _lightDirection = simd_make_float3(0.5f, -1.0f, 0.5f);
    _lightColor = simd_make_float3(1.0f, 1.0f, 1.0f);
    _lightIntensity = 1.0f;

    // Initialize light buffer
    Light* light = (Light*)[_pLightBuffer contents];
    light->direction = _lightDirection;
    light->color = _lightColor;
    light->intensity = _lightIntensity;

    // Initialize environment state
    _backgroundColor = simd_make_float4(0.1f, 0.1f, 0.1f, 1.0f);

    // Initialize camera with default values
    resetCamera();
}

PinnacleMetalRenderer::~PinnacleMetalRenderer() {
    // Manual release calls for non-ARC environment
    _pModel.reset();
    [_pLightBuffer release];
    [_pMaterialBuffer release];
    [_pUniformBuffer release];
    [_pSamplerState release];
    [_pDepthStencilState release];
    [_pPipelineState release];
    [_pDefaultPipelineState release];
    [_pVertexDescriptor release];
    [_pShaderLibrary release];
    [_pCommandQueue release];
    [_pDevice release];
}

void PinnacleMetalRenderer::loadModel(const char* filename) {
    try {
        _pModel = std::make_shared<Pinnacle::Model>(_pDevice, std::string(filename));
        std::cout << "Model loaded successfully with " << _pModel->getMeshes().size() << " meshes" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Failed to load model: " << e.what() << std::endl;
    }
}

void PinnacleMetalRenderer::buildShaders() {
    NSError* error = nil;
    // Get the path to the default.metallib in the app bundle
    NSString* bundlePath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
    if (bundlePath) {
        _pShaderLibrary = [_pDevice newLibraryWithFile:bundlePath error:&error];
    } else {
        // Fallback: try to load from source if metallib not found (for development)
        NSString* shaderPath = [[NSBundle mainBundle] pathForResource:@"triangle" ofType:@"metal"];
        if (shaderPath) {
            NSString* shaderSource = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
            if (shaderSource) {
                _pShaderLibrary = [_pDevice newLibraryWithSource:shaderSource options:nil error:&error];
            }
        }
    }

    if (!_pShaderLibrary) {
        NSLog(@"Failed to create shader library: %@", error);
        return;
    }

    id<MTLFunction> vertexFunction = [_pShaderLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [_pShaderLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

    // Create a vertex descriptor matching our Vertex struct
    MTLVertexDescriptor* vertexDescriptor = [[MTLVertexDescriptor alloc] init];

    // Position attribute (float3)
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;

    // Normal attribute (float3)
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[1].offset = sizeof(simd_float3);
    vertexDescriptor.attributes[1].bufferIndex = 0;

    // TexCoords attribute (float2)
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[2].offset = sizeof(simd_float3) * 2;
    vertexDescriptor.attributes[2].bufferIndex = 0;

    // Layout for buffer 0 (vertices)
    vertexDescriptor.layouts[0].stride = sizeof(simd_float3) * 2 + sizeof(simd_float2); // position + normal + texCoords
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

    pipelineDescriptor.vertexDescriptor = vertexDescriptor;

    _pPipelineState = [_pDevice newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];

    if (!_pPipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
    } else {
        // Cache the default pipeline state for hot-reload reset functionality
        _pDefaultPipelineState = [_pPipelineState retain];
    }

    // Cache vertex descriptor for shader editor
    _pVertexDescriptor = [vertexDescriptor retain];

    [vertexFunction release];
    [fragmentFunction release];
    [pipelineDescriptor release];
    [vertexDescriptor release];
}

void PinnacleMetalRenderer::drawModel(id<MTLRenderCommandEncoder> renderEncoder) {
    if (!_pModel) return;

    // Set uniforms
    [renderEncoder setVertexBuffer:_pUniformBuffer offset:0 atIndex:1];
    [renderEncoder setFragmentBuffer:_pUniformBuffer offset:0 atIndex:1];
    [renderEncoder setFragmentBuffer:_pLightBuffer offset:0 atIndex:2];
    [renderEncoder setFragmentSamplerState:_pSamplerState atIndex:0];

    // Draw each mesh
    for (const auto& mesh : _pModel->getMeshes()) {
        id<MTLBuffer> vertexBuffer = (id<MTLBuffer>)mesh->getVertexBuffer();
        id<MTLBuffer> indexBuffer = (id<MTLBuffer>)mesh->getIndexBuffer();
        size_t indexCount = mesh->getIndexCount();

        if (!vertexBuffer || !indexBuffer) continue;

        // Get material
        auto material = mesh->getMaterial();
        if (material) {
            const Pinnacle::PBRMaterial& pbr = material->getPBRMaterial();

            // Update material buffer
            MaterialUniforms* materialUniforms = (MaterialUniforms*)[_pMaterialBuffer contents];
            materialUniforms->baseColorFactor = pbr.baseColorFactor;
            materialUniforms->metallicFactor = pbr.metallicFactor;
            materialUniforms->roughnessFactor = pbr.roughnessFactor;
            materialUniforms->hasBaseColorTexture = (pbr.baseColorTexture != nullptr) ? 1 : 0;
            materialUniforms->hasMetallicRoughnessTexture = (pbr.metallicRoughnessTexture != nullptr) ? 1 : 0;
            materialUniforms->hasNormalTexture = (pbr.normalTexture != nullptr) ? 1 : 0;

            [renderEncoder setFragmentBuffer:_pMaterialBuffer offset:0 atIndex:0];

            // Bind base color texture if available
            if (pbr.baseColorTexture) {
                id<MTLTexture> texture = (id<MTLTexture>)pbr.baseColorTexture->getMTLTexture();
                if (texture) {
                    [renderEncoder setFragmentTexture:texture atIndex:0];
                }
            }
        }

        // Set vertex buffer and draw
        [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                  indexCount:indexCount
                                   indexType:MTLIndexTypeUInt32
                                 indexBuffer:indexBuffer
                           indexBufferOffset:0];
    }
}

void PinnacleMetalRenderer::draw(void* metalLayer) {
    // Cast the void* to CAMetalLayer* (Objective-C type)
    CAMetalLayer* pMetalLayer = (__bridge CAMetalLayer*)metalLayer;

    if (!_pDevice || !_pCommandQueue || !pMetalLayer || !_pPipelineState) return;

    // Create an autorelease pool for the frame (manual management)
    NSAutoreleasePool* pPool = [[NSAutoreleasePool alloc] init];

    id<MTLCommandBuffer> pCommandBuffer = [_pCommandQueue commandBuffer];
    id<MTLDrawable> pDrawable = [pMetalLayer nextDrawable];

    if (pDrawable) {
        // Update uniforms
        Uniforms* uniforms = (Uniforms*)[_pUniformBuffer contents];

        // Model matrix (identity for now)
        uniforms->modelMatrix = simd_matrix4x4((simd_float4){1, 0, 0, 0},
                                              (simd_float4){0, 1, 0, 0},
                                              (simd_float4){0, 0, 1, 0},
                                              (simd_float4){0, 0, 0, 1});

        // View matrix (using camera state)
        simd_float3 f = simd_normalize(simd_sub(_cameraLookAt, _cameraPosition));
        simd_float3 s = simd_normalize(simd_cross(f, _cameraUp));
        simd_float3 u = simd_cross(s, f);

        uniforms->viewMatrix = simd_matrix4x4(
            (simd_float4){s.x, u.x, -f.x, 0},
            (simd_float4){s.y, u.y, -f.y, 0},
            (simd_float4){s.z, u.z, -f.z, 0},
            (simd_float4){-simd_dot(s, _cameraPosition), -simd_dot(u, _cameraPosition), simd_dot(f, _cameraPosition), 1}
        );

        // Projection matrix (perspective, using camera state)
        float aspect = (float)pMetalLayer.drawableSize.width / (float)pMetalLayer.drawableSize.height;

        float ys = 1.0f / tanf(_cameraFOV * 0.5f);
        float xs = ys / aspect;
        float zs = _cameraFar / (_cameraNear - _cameraFar);

        uniforms->projectionMatrix = simd_matrix4x4(
            (simd_float4){xs, 0, 0, 0},
            (simd_float4){0, ys, 0, 0},
            (simd_float4){0, 0, zs, -1},
            (simd_float4){0, 0, _cameraNear * zs, 0}
        );

        uniforms->cameraPosition = _cameraPosition;

        // Create depth texture
        id<MTLTexture> colorTexture = [pDrawable texture];
        MTLTextureDescriptor* depthDescriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
            width:colorTexture.width
            height:colorTexture.height
            mipmapped:NO];
        depthDescriptor.usage = MTLTextureUsageRenderTarget;
        depthDescriptor.storageMode = MTLStorageModePrivate;
        id<MTLTexture> depthTexture = [_pDevice newTextureWithDescriptor:depthDescriptor];

        // Setup render pass
        MTLRenderPassDescriptor* pRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        pRenderPassDescriptor.colorAttachments[0].texture = colorTexture;
        pRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        pRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(
            _backgroundColor.x, _backgroundColor.y, _backgroundColor.z, _backgroundColor.w);
        pRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

        pRenderPassDescriptor.depthAttachment.texture = depthTexture;
        pRenderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        pRenderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
        pRenderPassDescriptor.depthAttachment.clearDepth = 1.0;

        id<MTLRenderCommandEncoder> pRenderEncoder = [pCommandBuffer renderCommandEncoderWithDescriptor:pRenderPassDescriptor];
        [pRenderEncoder setRenderPipelineState:_pPipelineState];
        [pRenderEncoder setDepthStencilState:_pDepthStencilState];
        [pRenderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [pRenderEncoder setCullMode:MTLCullModeBack];

        drawModel(pRenderEncoder); // Draw the loaded glTF model

        [pRenderEncoder endEncoding];

        [pCommandBuffer presentDrawable:pDrawable];
        [depthTexture release];
    }

    [pCommandBuffer commit];
    [pPool release];
}

// Shader hot-reload interface implementation

bool PinnacleMetalRenderer::setCustomPipelineState(id pipelineState) {
    if (!pipelineState) {
        NSLog(@"Cannot set null pipeline state");
        return false;
    }

    id<MTLRenderPipelineState> newState = (id<MTLRenderPipelineState>)pipelineState;

    // Release old custom pipeline state if we were using one
    if (_usingCustomShader && _pPipelineState != _pDefaultPipelineState) {
        [_pPipelineState release];
    }

    // Set new pipeline state
    _pPipelineState = [newState retain];
    _usingCustomShader = true;

    NSLog(@"✓ Custom shader pipeline applied");
    return true;
}

void PinnacleMetalRenderer::resetToDefaultShaders() {
    if (!_usingCustomShader) {
        return; // Already using default shaders
    }

    // Release custom pipeline state
    if (_pPipelineState != _pDefaultPipelineState) {
        [_pPipelineState release];
    }

    // Restore default pipeline state
    _pPipelineState = _pDefaultPipelineState;
    _usingCustomShader = false;

    NSLog(@"✓ Reset to default shaders");
}

id PinnacleMetalRenderer::getVertexDescriptor() {
    return _pVertexDescriptor;
}

// Camera control methods

void PinnacleMetalRenderer::resetCamera() {
    _cameraPosition = simd_make_float3(0.0f, 0.0f, 5.0f);
    _cameraLookAt = simd_make_float3(0.0f, 0.0f, 0.0f);
    _cameraUp = simd_make_float3(0.0f, 1.0f, 0.0f);
    _cameraFOV = 45.0f * (3.14159265359f / 180.0f);  // 45 degrees in radians
    _cameraNear = 0.1f;
    _cameraFar = 100.0f;
    _cameraOrbitTheta = 0.0f;
    _cameraOrbitPhi = 0.0f;
}

void PinnacleMetalRenderer::fitCameraToModel() {
    if (!_pModel) {
        resetCamera();
        return;
    }

    const auto& meshes = _pModel->getMeshes();
    if (meshes.empty()) {
        resetCamera();
        return;
    }

    // Calculate bounding box
    float minX = INFINITY, minY = INFINITY, minZ = INFINITY;
    float maxX = -INFINITY, maxY = -INFINITY, maxZ = -INFINITY;

    for (const auto& mesh : meshes) {
        id<MTLBuffer> vertexBuffer = (id<MTLBuffer>)mesh->getVertexBuffer();
        if (vertexBuffer) {
            const Pinnacle::Vertex* vertices = (const Pinnacle::Vertex*)[vertexBuffer contents];
            size_t vertexCount = mesh->getVertexCount();

            for (size_t i = 0; i < vertexCount; ++i) {
                const auto& pos = vertices[i].position;
                minX = std::min(minX, pos.x);
                minY = std::min(minY, pos.y);
                minZ = std::min(minZ, pos.z);
                maxX = std::max(maxX, pos.x);
                maxY = std::max(maxY, pos.y);
                maxZ = std::max(maxZ, pos.z);
            }
        }
    }

    // Calculate center and size
    simd_float3 center = simd_make_float3(
        (minX + maxX) * 0.5f,
        (minY + maxY) * 0.5f,
        (minZ + maxZ) * 0.5f
    );

    float sizeX = maxX - minX;
    float sizeY = maxY - minY;
    float sizeZ = maxZ - minZ;
    float maxSize = std::max(std::max(sizeX, sizeY), sizeZ);

    // Position camera to fit model in view
    // Distance = size / (2 * tan(fov/2))
    float distance = maxSize / (2.0f * tanf(_cameraFOV * 0.5f)) * 1.5f;  // 1.5x for padding

    _cameraLookAt = center;
    _cameraPosition = simd_make_float3(center.x, center.y, center.z + distance);
    _cameraUp = simd_make_float3(0.0f, 1.0f, 0.0f);

    // Update orbit angles to match new position
    simd_float3 offset = simd_sub(_cameraPosition, _cameraLookAt);
    float dist = simd_length(offset);
    _cameraOrbitPhi = asinf(offset.y / dist);
    _cameraOrbitTheta = atan2f(offset.x, offset.z);
}

void PinnacleMetalRenderer::setCameraDistance(float distance) {
    simd_float3 direction = simd_normalize(simd_sub(_cameraPosition, _cameraLookAt));
    _cameraPosition = simd_add(_cameraLookAt, simd_mul(direction, distance));

    // Update orbit angles
    simd_float3 offset = simd_sub(_cameraPosition, _cameraLookAt);
    float dist = simd_length(offset);
    _cameraOrbitPhi = asinf(offset.y / dist);
    _cameraOrbitTheta = atan2f(offset.x, offset.z);
}

void PinnacleMetalRenderer::orbitCamera(float deltaX, float deltaY) {
    // Update orbit angles
    _cameraOrbitTheta += deltaX;
    _cameraOrbitPhi += deltaY;

    // Clamp phi to avoid gimbal lock
    const float maxPhi = 1.5f;  // ~86 degrees
    _cameraOrbitPhi = std::max(-maxPhi, std::min(maxPhi, _cameraOrbitPhi));

    updateCameraFromOrbit();
}

void PinnacleMetalRenderer::updateCameraFromOrbit() {
    // Calculate distance from look-at point
    simd_float3 offset = simd_sub(_cameraPosition, _cameraLookAt);
    float distance = simd_length(offset);

    // Calculate new position using spherical coordinates
    float cosPhi = cosf(_cameraOrbitPhi);
    _cameraPosition = simd_make_float3(
        _cameraLookAt.x + distance * cosPhi * sinf(_cameraOrbitTheta),
        _cameraLookAt.y + distance * sinf(_cameraOrbitPhi),
        _cameraLookAt.z + distance * cosPhi * cosf(_cameraOrbitTheta)
    );
}

float PinnacleMetalRenderer::getCameraDistance() const {
    return simd_length(simd_sub(_cameraPosition, _cameraLookAt));
}

// Lighting control methods

void PinnacleMetalRenderer::setLightDirection(simd_float3 direction) {
    _lightDirection = simd_normalize(direction);  // Normalize to ensure it's a unit vector

    // Update light buffer
    Light* light = (Light*)[_pLightBuffer contents];
    light->direction = _lightDirection;
}

void PinnacleMetalRenderer::setLightIntensity(float intensity) {
    _lightIntensity = std::max(0.0f, intensity);  // Clamp to non-negative

    // Update light buffer
    Light* light = (Light*)[_pLightBuffer contents];
    light->intensity = _lightIntensity;
}

void PinnacleMetalRenderer::setLightColor(simd_float3 color) {
    // Clamp color components to [0, 1]
    _lightColor = simd_make_float3(
        std::max(0.0f, std::min(1.0f, color.x)),
        std::max(0.0f, std::min(1.0f, color.y)),
        std::max(0.0f, std::min(1.0f, color.z))
    );

    // Update light buffer
    Light* light = (Light*)[_pLightBuffer contents];
    light->color = _lightColor;
}

// Environment control methods

void PinnacleMetalRenderer::setBackgroundColor(simd_float4 color) {
    // Clamp color components to [0, 1]
    _backgroundColor = simd_make_float4(
        std::max(0.0f, std::min(1.0f, color.x)),
        std::max(0.0f, std::min(1.0f, color.y)),
        std::max(0.0f, std::min(1.0f, color.z)),
        std::max(0.0f, std::min(1.0f, color.w))
    );
}

// Factory function implementation
IPinnacleMetalRenderer* createPinnacleMetalRenderer() {
    return new PinnacleMetalRenderer();
}