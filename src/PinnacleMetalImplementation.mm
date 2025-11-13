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

    // Initialize light
    Light* light = (Light*)[_pLightBuffer contents];
    light->direction = simd_make_float3(0.5f, -1.0f, 0.5f);
    light->color = simd_make_float3(1.0f, 1.0f, 1.0f);
    light->intensity = 1.0f;
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

        // View matrix (camera looking at origin from distance)
        simd_float3 eye = simd_make_float3(0.0f, 0.0f, 5.0f);
        simd_float3 center = simd_make_float3(0.0f, 0.0f, 0.0f);
        simd_float3 up = simd_make_float3(0.0f, 1.0f, 0.0f);

        simd_float3 f = simd_normalize(simd_sub(center, eye));
        simd_float3 s = simd_normalize(simd_cross(f, up));
        simd_float3 u = simd_cross(s, f);

        uniforms->viewMatrix = simd_matrix4x4(
            (simd_float4){s.x, u.x, -f.x, 0},
            (simd_float4){s.y, u.y, -f.y, 0},
            (simd_float4){s.z, u.z, -f.z, 0},
            (simd_float4){-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1}
        );

        // Projection matrix (perspective)
        float aspect = (float)pMetalLayer.drawableSize.width / (float)pMetalLayer.drawableSize.height;
        float fovy = 45.0f * (3.14159265359f / 180.0f); // 45 degrees in radians
        float near = 0.1f;
        float far = 100.0f;

        float ys = 1.0f / tanf(fovy * 0.5f);
        float xs = ys / aspect;
        float zs = far / (near - far);

        uniforms->projectionMatrix = simd_matrix4x4(
            (simd_float4){xs, 0, 0, 0},
            (simd_float4){0, ys, 0, 0},
            (simd_float4){0, 0, zs, -1},
            (simd_float4){0, 0, near * zs, 0}
        );

        uniforms->cameraPosition = eye;

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
        pRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1.0);
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

// Factory function implementation
IPinnacleMetalRenderer* createPinnacleMetalRenderer() {
    return new PinnacleMetalRenderer();
}