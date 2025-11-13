#import "ShaderEditorBridge.h"
#import <Metal/Metal.h>

#include "../ShaderEditor/ShaderEditor.hpp"
#include "../ShaderEditor/ShaderLibrary.hpp"
#include "../PinnacleMetalRenderer.h"

#include <memory>

@implementation CompileResult
@end

@interface ShaderEditorBridge()
{
    std::unique_ptr<Pinnacle::ShaderEditor> _editor;
    std::unique_ptr<Pinnacle::ShaderLibrary> _library;
    std::shared_ptr<Pinnacle::ShaderProgram> _currentProgram;
    std::shared_ptr<Pinnacle::ShaderSource> _vertexShader;
    std::shared_ptr<Pinnacle::ShaderSource> _fragmentShader;
    PinnacleMetalRenderer* _renderer;
}
@end

@implementation ShaderEditorBridge

- (instancetype)initWithRenderer:(void*)renderer {
    self = [super init];
    if (self) {
        _renderer = (PinnacleMetalRenderer*)renderer;

        // Create shader editor with renderer's device
        _editor = std::make_unique<Pinnacle::ShaderEditor>(_renderer->getDevice());

        // Create shader library with presets
        _library = std::make_unique<Pinnacle::ShaderLibrary>();
        _library->addProgram(Pinnacle::ShaderLibrary::createUnlitProgram());
        _library->addProgram(Pinnacle::ShaderLibrary::createWireframeProgram());
        _library->addProgram(Pinnacle::ShaderLibrary::createNormalVisualizerProgram());

        // Start with a default program
        [self createProgramWithName:@"Custom Shader"];
    }
    return self;
}

- (void)createProgramWithName:(NSString*)name {
    std::string programName = [name UTF8String];
    _currentProgram = _editor->createProgram(programName);

    // Create default vertex and fragment shaders
    _vertexShader = std::make_shared<Pinnacle::ShaderSource>(
        Pinnacle::ShaderType::Vertex,
        programName + " Vertex"
    );

    _fragmentShader = std::make_shared<Pinnacle::ShaderSource>(
        Pinnacle::ShaderType::Fragment,
        programName + " Fragment"
    );

    // Set default sources (copy from current PBR shader)
    std::string defaultVertexSource = R"(
#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position;
    float3 normal;
    float2 texCoords;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 cameraPosition;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoords;
};

vertex VertexOut vertexShader(device const Vertex* vertices [[buffer(0)]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              unsigned int vertexId [[vertex_id]]) {
    VertexOut out;
    Vertex v = vertices[vertexId];

    float4 worldPos = uniforms.modelMatrix * float4(v.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;

    float3x3 normalMatrix = float3x3(uniforms.modelMatrix[0].xyz,
                                      uniforms.modelMatrix[1].xyz,
                                      uniforms.modelMatrix[2].xyz);
    out.normal = normalize(normalMatrix * v.normal);
    out.texCoords = v.texCoords;

    return out;
}
)";

    std::string defaultFragmentSource = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoords;
};

struct MaterialUniforms {
    float4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    int hasBaseColorTexture;
    int hasMetallicRoughnessTexture;
    int hasNormalTexture;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant MaterialUniforms& material [[buffer(0)]]) {
    // Simple visualizer: Show normals as colors
    float3 N = normalize(in.normal);
    float3 color = N * 0.5 + 0.5;
    return float4(color, 1.0);
}
)";

    _vertexShader->setSource(defaultVertexSource);
    _fragmentShader->setSource(defaultFragmentSource);

    _currentProgram->setVertexShader(_vertexShader);
    _currentProgram->setFragmentShader(_fragmentShader);
}

- (void)setVertexShaderSource:(NSString*)source {
    if (!_vertexShader) return;
    std::string cppSource = [source UTF8String];
    _vertexShader->setSource(cppSource);
}

- (void)setFragmentShaderSource:(NSString*)source {
    if (!_fragmentShader) return;
    std::string cppSource = [source UTF8String];
    _fragmentShader->setSource(cppSource);
}

- (CompileResult*)testCompile {
    CompileResult* result = [[CompileResult alloc] init];

    if (!_currentProgram) {
        result.success = NO;
        result.errors = @[@"No program created"];
        result.errorLines = @[@0];
        return result;
    }

    auto compileResult = _editor->testCompile(*_currentProgram);

    result.success = compileResult.success;
    result.compilationTime = compileResult.compilationTime;

    NSMutableArray* errors = [NSMutableArray array];
    NSMutableArray* lines = [NSMutableArray array];

    for (const auto& error : compileResult.errors) {
        NSString* errorMsg = [NSString stringWithFormat:@"Line %d: %s",
                             error.line + 1,
                             error.message.c_str()];
        [errors addObject:errorMsg];
        [lines addObject:@(error.line)];
    }

    result.errors = errors;
    result.errorLines = lines;

    return result;
}

- (BOOL)applyShader {
    if (!_currentProgram || !_renderer) return NO;

    return _editor->applyShaderProgram(*_currentProgram, _renderer);
}

- (void)resetToDefaults {
    if (_renderer) {
        _renderer->resetToDefaultShaders();
    }
}

- (BOOL)loadPreset:(NSString*)presetName {
    std::string name = [presetName UTF8String];
    auto program = _library->getProgram(name);

    if (!program) return NO;

    // Update current program with preset
    _currentProgram = program;
    _vertexShader = program->getVertexShader();
    _fragmentShader = program->getFragmentShader();

    return YES;
}

- (NSArray<NSString*>*)availablePresets {
    auto names = _library->getProgramNames();
    NSMutableArray* presets = [NSMutableArray array];

    for (const auto& name : names) {
        [presets addObject:[NSString stringWithUTF8String:name.c_str()]];
    }

    return presets;
}

- (BOOL)loadShaderFromFile:(NSString*)path isVertex:(BOOL)isVertex {
    std::string filePath = [path UTF8String];

    if (isVertex) {
        return _vertexShader->loadFromFile(filePath);
    } else {
        return _fragmentShader->loadFromFile(filePath);
    }
}

- (BOOL)saveShaderToFile:(NSString*)path isVertex:(BOOL)isVertex {
    std::string filePath = [path UTF8String];

    if (isVertex) {
        return _vertexShader->saveToFile(filePath);
    } else {
        return _fragmentShader->saveToFile(filePath);
    }
}

- (NSString*)getVertexShaderSource {
    if (!_vertexShader) return @"";
    return [NSString stringWithUTF8String:_vertexShader->getSource().c_str()];
}

- (NSString*)getFragmentShaderSource {
    if (!_fragmentShader) return @"";
    return [NSString stringWithUTF8String:_fragmentShader->getSource().c_str()];
}

@end
