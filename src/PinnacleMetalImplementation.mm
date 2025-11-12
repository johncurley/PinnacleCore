// Removed metal-cpp includes and defines
#import <MetalKit/MetalKit.h> // Include MetalKit for Objective-C Metal types
#import <Foundation/Foundation.h> // For NSBundle

#include "PinnacleMetalRenderer.h" // Include the concrete renderer declaration

// Uniforms structure for our shader
struct Uniforms {
    vector_float4 modelColor;
};

// Implementation of PinnacleMetalRenderer methods
PinnacleMetalRenderer::PinnacleMetalRenderer() {
    _pDevice = MTLCreateSystemDefaultDevice();
    _pCommandQueue = [_pDevice newCommandQueue];
    _pShaderLibrary = nil; // Initialize to nil
    _pPipelineState = nil; // Initialize to nil
    _pUniformBuffer = nil; // Initialize to nil

    buildShaders();
}

PinnacleMetalRenderer::~PinnacleMetalRenderer() {
    // Manual release calls for non-ARC environment
    for (id<MTLBuffer> buffer : _vertexBuffers) {
        [buffer release];
    }
    _vertexBuffers.clear();
    for (id<MTLBuffer> buffer : _indexBuffers) {
        [buffer release];
    }
    _indexBuffers.clear();
    [_pUniformBuffer release];
    [_pPipelineState release];
    [_pShaderLibrary release];
    [_pCommandQueue release];
    [_pDevice release];
}

void PinnacleMetalRenderer::loadModel(const char* filename) {
    tinygltf::TinyGLTF loader;
    std::string err;
    std::string warn;

    bool res = loader.LoadASCIIFromFile(&_gltfModel, &err, &warn, filename);
    if (!warn.empty()) {
        std::cout << "WARN: " << warn << std::endl;
    }

    if (!err.empty()) {
        std::cout << "ERR: " << err << std::endl;
    }

    if (!res) {
        std::cout << "Failed to load glTF: " << filename << std::endl;
    } else {
        std::cout << "Successfully loaded glTF: " << filename << std::endl;
        setupModelBuffers(); // Setup Metal buffers after loading the model

        // Setup uniform buffer with model color
        Uniforms uniforms;
        if (!_gltfModel.materials.empty()) {
            const tinygltf::Material& material = _gltfModel.materials[0];
            if (material.pbrMetallicRoughness.baseColorFactor.size() == 4) {
                uniforms.modelColor = {
                    (float)material.pbrMetallicRoughness.baseColorFactor[0],
                    (float)material.pbrMetallicRoughness.baseColorFactor[1],
                    (float)material.pbrMetallicRoughness.baseColorFactor[2],
                    (float)material.pbrMetallicRoughness.baseColorFactor[3]
                };
            } else {
                uniforms.modelColor = {1.0f, 1.0f, 1.0f, 1.0f}; // Default to white
            }
        } else {
            uniforms.modelColor = {1.0f, 1.0f, 1.0f, 1.0f}; // Default to white
        }
        _pUniformBuffer = [_pDevice newBufferWithBytes:&uniforms length:sizeof(uniforms) options:MTLResourceStorageModeShared];
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

    // Create a vertex descriptor
    MTLVertexDescriptor* vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    // Position attribute
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    // Layout for buffer 0
    vertexDescriptor.layouts[0].stride = sizeof(float) * 3; // 3 floats for position
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

    pipelineDescriptor.vertexDescriptor = vertexDescriptor;

    _pPipelineState = [_pDevice newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];

    if (!_pPipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
    }

    [vertexFunction release];
    [fragmentFunction release];
    [pipelineDescriptor release];
    [vertexDescriptor release]; // Release the vertex descriptor
}

void PinnacleMetalRenderer::setupModelBuffers() {
    if (_gltfModel.meshes.empty()) return;

    for (const auto& mesh : _gltfModel.meshes) {
        for (const auto& primitive : mesh.primitives) {
            // Vertices (POSITION attribute)
            auto positionAttribute = primitive.attributes.find("POSITION");
            if (positionAttribute != primitive.attributes.end()) {
                const tinygltf::Accessor& accessor = _gltfModel.accessors[positionAttribute->second];
                const tinygltf::BufferView& bufferView = _gltfModel.bufferViews[accessor.bufferView];
                const tinygltf::Buffer& buffer = _gltfModel.buffers[bufferView.buffer];

                id<MTLBuffer> vertexBuffer = [_pDevice newBufferWithBytes:buffer.data.data() + bufferView.byteOffset + accessor.byteOffset
                                                                    length:bufferView.byteLength
                                                                   options:MTLResourceStorageModeShared];
                _vertexBuffers.push_back([vertexBuffer retain]); // Retain and add to vector
                [vertexBuffer release]; // Release the temporary ownership
            }

            // Indices
            if (primitive.indices > -1) {
                const tinygltf::Accessor& indexAccessor = _gltfModel.accessors[primitive.indices];
                const tinygltf::BufferView& indexBufferView = _gltfModel.bufferViews[indexAccessor.bufferView];
                const tinygltf::Buffer& indexBuffer = _gltfModel.buffers[indexBufferView.buffer];

                id<MTLBuffer> metalIndexBuffer = [_pDevice newBufferWithBytes:indexBuffer.data.data() + indexBufferView.byteOffset + indexAccessor.byteOffset
                                                                        length:indexBufferView.byteLength
                                                                       options:MTLResourceStorageModeShared];
                _indexBuffers.push_back([metalIndexBuffer retain]); // Retain and add to vector
                [metalIndexBuffer release]; // Release the temporary ownership

                MTLIndexType indexType;
                if (indexAccessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_SHORT) {
                    indexType = MTLIndexTypeUInt16;
                } else if (indexAccessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_INT) {
                    indexType = MTLIndexTypeUInt32;
                } else {
                    // Default to UInt16 or handle error
                    indexType = MTLIndexTypeUInt16;
                }
                _indexBufferTypes.push_back(indexType);
            }
        }
    }
}

void PinnacleMetalRenderer::drawModel(id<MTLRenderCommandEncoder> renderEncoder) {
    if (_vertexBuffers.empty() || _indexBuffers.empty() || !_pUniformBuffer) return;

    [renderEncoder setVertexBuffer:_pUniformBuffer offset:0 atIndex:1]; // Set uniform buffer at index 1

    for (size_t i = 0; i < _vertexBuffers.size(); ++i) {
        id<MTLBuffer> vertexBuffer = _vertexBuffers[i];
        id<MTLBuffer> indexBuffer = _indexBuffers[i];
        MTLIndexType indexType = _indexBufferTypes[i];

        [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                 indexCount:[indexBuffer length] / (indexType == MTLIndexTypeUInt16 ? 2 : 4)
                                  indexType:indexType
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
        MTLRenderPassDescriptor* pRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        pRenderPassDescriptor.colorAttachments[0].texture = [pDrawable texture];
        pRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        pRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.2, 0.2, 1.0);
        pRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

        id<MTLRenderCommandEncoder> pRenderEncoder = [pCommandBuffer renderCommandEncoderWithDescriptor:pRenderPassDescriptor];
        [pRenderEncoder setRenderPipelineState:_pPipelineState];
        
        drawModel(pRenderEncoder); // Draw the loaded glTF model

        [pRenderEncoder endEncoding];

        [pCommandBuffer presentDrawable:pDrawable];
    }

    [pCommandBuffer commit];
    [pPool release];
}

// Factory function implementation
IPinnacleMetalRenderer* createPinnacleMetalRenderer() {
    return new PinnacleMetalRenderer();
}