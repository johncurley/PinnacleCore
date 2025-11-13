#import <Foundation/Foundation.h>
#include "ShaderLibrary.hpp"
#include <iostream>

namespace Pinnacle
{
    ShaderLibrary::ShaderLibrary()
    {
    }

    ShaderLibrary::~ShaderLibrary()
    {
    }

    void ShaderLibrary::addProgram(std::shared_ptr<ShaderProgram> program)
    {
        if (!program) return;
        m_programs[program->getName()] = program;
    }

    bool ShaderLibrary::removeProgram(const std::string& name)
    {
        auto it = m_programs.find(name);
        if (it != m_programs.end()) {
            m_programs.erase(it);
            return true;
        }
        return false;
    }

    std::shared_ptr<ShaderProgram> ShaderLibrary::getProgram(const std::string& name) const
    {
        auto it = m_programs.find(name);
        if (it != m_programs.end()) {
            return it->second;
        }
        return nullptr;
    }

    std::vector<std::string> ShaderLibrary::getProgramNames() const
    {
        std::vector<std::string> names;
        names.reserve(m_programs.size());
        for (const auto& pair : m_programs) {
            names.push_back(pair.first);
        }
        return names;
    }

    bool ShaderLibrary::hasProgram(const std::string& name) const
    {
        return m_programs.find(name) != m_programs.end();
    }

    void ShaderLibrary::clear()
    {
        m_programs.clear();
    }

    bool ShaderLibrary::loadFromDirectory(const std::string& path)
    {
        NSString* nsPath = [NSString stringWithUTF8String:path.c_str()];
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSError* error = nil;

        NSArray* files = [fileManager contentsOfDirectoryAtPath:nsPath error:&error];

        if (error) {
            NSLog(@"Failed to read directory: %@", error);
            return false;
        }

        for (NSString* file in files) {
            if ([file hasSuffix:@".metal"]) {
                NSString* fullPath = [nsPath stringByAppendingPathComponent:file];
                std::string filePath = [fullPath UTF8String];

                // For now, assume vertex shaders end with _vert.metal and fragment with _frag.metal
                // This is a simple convention - a real implementation would need more sophisticated parsing

                std::cout << "Found shader file: " << filePath << std::endl;
            }
        }

        return true;
    }

    bool ShaderLibrary::saveToDirectory(const std::string& path) const
    {
        NSString* nsPath = [NSString stringWithUTF8String:path.c_str()];
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSError* error = nil;

        // Create directory if it doesn't exist
        [fileManager createDirectoryAtPath:nsPath
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:&error];

        if (error) {
            NSLog(@"Failed to create directory: %@", error);
            return false;
        }

        // Save each program
        for (const auto& pair : m_programs) {
            const auto& program = pair.second;

            // Save vertex shader
            if (program->getVertexShader()) {
                std::string vertPath = path + "/" + program->getName() + "_vert.metal";
                program->getVertexShader()->saveToFile(vertPath);
            }

            // Save fragment shader
            if (program->getFragmentShader()) {
                std::string fragPath = path + "/" + program->getName() + "_frag.metal";
                program->getFragmentShader()->saveToFile(fragPath);
            }

            // Save compute shader
            if (program->getComputeShader()) {
                std::string compPath = path + "/" + program->getName() + "_comp.metal";
                program->getComputeShader()->saveToFile(compPath);
            }
        }

        return true;
    }

    // Built-in shader presets

    std::shared_ptr<ShaderProgram> ShaderLibrary::createDefaultPBRProgram()
    {
        auto program = std::make_shared<ShaderProgram>("Default PBR");

        // This would contain the current PBR shader from triangle.metal
        // In a real implementation, we'd load this from a file or embed it as a string

        auto vertexShader = std::make_shared<ShaderSource>(ShaderType::Vertex, "PBR Vertex");
        auto fragmentShader = std::make_shared<ShaderSource>(ShaderType::Fragment, "PBR Fragment");

        // For now, just mark them as needing to be loaded from the default file
        // In a production system, you'd have these as const char* strings

        program->setVertexShader(vertexShader);
        program->setFragmentShader(fragmentShader);

        return program;
    }

    std::shared_ptr<ShaderProgram> ShaderLibrary::createUnlitProgram()
    {
        auto program = std::make_shared<ShaderProgram>("Unlit");

        auto vertexShader = std::make_shared<ShaderSource>(ShaderType::Vertex, "Unlit Vertex");
        auto fragmentShader = std::make_shared<ShaderSource>(ShaderType::Fragment, "Unlit Fragment");

        // Simple unlit shader
        std::string vertSource = R"(
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
    float2 texCoords;
};

vertex VertexOut vertexShader(device const Vertex* vertices [[buffer(0)]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              unsigned int vertexId [[vertex_id]]) {
    VertexOut out;
    Vertex v = vertices[vertexId];
    float4 worldPos = uniforms.modelMatrix * float4(v.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.texCoords = v.texCoords;
    return out;
}
)";

        std::string fragSource = R"(
#include <metal_stdlib>
using namespace metal;

struct MaterialUniforms {
    float4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    int hasBaseColorTexture;
    int hasMetallicRoughnessTexture;
    int hasNormalTexture;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant MaterialUniforms& material [[buffer(0)]],
                              texture2d<float> baseColorTexture [[texture(0)]]) {
    float4 color = material.baseColorFactor;

    if (material.hasBaseColorTexture && !is_null_texture(baseColorTexture)) {
        constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
        color *= baseColorTexture.sample(textureSampler, in.texCoords);
    }

    return color;
}
)";

        vertexShader->setSource(vertSource);
        fragmentShader->setSource(fragSource);

        program->setVertexShader(vertexShader);
        program->setFragmentShader(fragmentShader);

        return program;
    }

    std::shared_ptr<ShaderProgram> ShaderLibrary::createWireframeProgram()
    {
        auto program = std::make_shared<ShaderProgram>("Wireframe");

        auto vertexShader = std::make_shared<ShaderSource>(ShaderType::Vertex, "Wireframe Vertex");
        auto fragmentShader = std::make_shared<ShaderSource>(ShaderType::Fragment, "Wireframe Fragment");

        // Wireframe shader (simplified - real wireframe needs geometry shader or barycentric coords)
        std::string fragSource = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return float4(0.0, 1.0, 0.0, 1.0); // Green wireframe
}
)";

        fragmentShader->setSource(fragSource);
        program->setVertexShader(vertexShader); // Uses same vertex shader as unlit
        program->setFragmentShader(fragmentShader);

        return program;
    }

    std::shared_ptr<ShaderProgram> ShaderLibrary::createNormalVisualizerProgram()
    {
        auto program = std::make_shared<ShaderProgram>("Normal Visualizer");

        auto vertexShader = std::make_shared<ShaderSource>(ShaderType::Vertex, "Normal Viz Vertex");
        auto fragmentShader = std::make_shared<ShaderSource>(ShaderType::Fragment, "Normal Viz Fragment");

        std::string vertSource = R"(
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
    float3 normal;
};

vertex VertexOut vertexShader(device const Vertex* vertices [[buffer(0)]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              unsigned int vertexId [[vertex_id]]) {
    VertexOut out;
    Vertex v = vertices[vertexId];
    float4 worldPos = uniforms.modelMatrix * float4(v.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;

    // Transform normal
    float3x3 normalMatrix = float3x3(uniforms.modelMatrix[0].xyz,
                                      uniforms.modelMatrix[1].xyz,
                                      uniforms.modelMatrix[2].xyz);
    out.normal = normalize(normalMatrix * v.normal);

    return out;
}
)";

        std::string fragSource = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 normal;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    // Visualize normals as RGB colors
    float3 normal = normalize(in.normal);
    float3 color = normal * 0.5 + 0.5; // Map from [-1,1] to [0,1]
    return float4(color, 1.0);
}
)";

        vertexShader->setSource(vertSource);
        fragmentShader->setSource(fragSource);

        program->setVertexShader(vertexShader);
        program->setFragmentShader(fragmentShader);

        return program;
    }

} // namespace Pinnacle
