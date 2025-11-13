#import <Foundation/Foundation.h>
#include "ShaderEditorExample.hpp"
#include <iostream>

namespace Pinnacle
{
    // ExampleShaderDelegate implementation

    void ExampleShaderDelegate::onCompilationSuccess(const ShaderProgram& program, double compilationTime)
    {
        std::cout << "✓ Shader '" << program.getName() << "' compiled successfully in "
                  << compilationTime << "s" << std::endl;
    }

    void ExampleShaderDelegate::onCompilationError(const ShaderProgram& program,
                                                   const std::vector<CompileError>& errors)
    {
        std::cerr << "✗ Shader '" << program.getName() << "' compilation failed:" << std::endl;
        for (const auto& error : errors) {
            std::cerr << "  Line " << (error.line + 1) << ": "
                     << (error.severity == CompileError::Severity::Error ? "ERROR" : "WARNING")
                     << " - " << error.message << std::endl;
        }
    }

    void ExampleShaderDelegate::onShaderModified(const ShaderSource& source)
    {
        std::cout << "Shader '" << source.getName() << "' modified" << std::endl;
    }

    // Example 1: Basic shader editor usage

    void runShaderEditorExample(PinnacleMetalRenderer* renderer)
    {
        std::cout << "\n=== Shader Editor Example ===" << std::endl;

        // Create shader editor
        auto editor = std::make_unique<ShaderEditor>(renderer->getDevice());

        // Create delegate for callbacks
        ExampleShaderDelegate delegate;
        editor->setDelegate(&delegate);

        // Create a simple test program
        auto program = editor->createProgram("Simple Test Shader");

        // Create vertex shader
        auto vertexShader = std::make_shared<ShaderSource>(ShaderType::Vertex, "Test Vertex");
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

    float3x3 normalMatrix = float3x3(uniforms.modelMatrix[0].xyz,
                                      uniforms.modelMatrix[1].xyz,
                                      uniforms.modelMatrix[2].xyz);
    out.normal = normalize(normalMatrix * v.normal);

    return out;
}
)";
        vertexShader->setSource(vertSource);

        // Create fragment shader
        auto fragmentShader = std::make_shared<ShaderSource>(ShaderType::Fragment, "Test Fragment");
        std::string fragSource = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 normal;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    float3 normal = normalize(in.normal);
    float3 color = normal * 0.5 + 0.5;
    return float4(color, 1.0);
}
)";
        fragmentShader->setSource(fragSource);

        // Add shaders to program
        program->setVertexShader(vertexShader);
        program->setFragmentShader(fragmentShader);

        // Test compilation
        std::cout << "\nTesting compilation..." << std::endl;
        auto result = editor->testCompile(*program);

        if (result.success) {
            std::cout << "\nApplying shader to renderer..." << std::endl;
            if (editor->applyShaderProgram(*program, renderer)) {
                std::cout << "✓ Shader hot-reload successful!" << std::endl;
                std::cout << "  The model should now display with normal-mapped colors" << std::endl;
            }
        }

        std::cout << "\n✓ Example complete. Call renderer->resetToDefaultShaders() to restore defaults." << std::endl;
    }

    // Example 2: Shader library usage

    void runShaderLibraryExample(PinnacleMetalRenderer* renderer)
    {
        std::cout << "\n=== Shader Library Example ===" << std::endl;

        // Create editor and library
        auto editor = std::make_unique<ShaderEditor>(renderer->getDevice());
        auto library = std::make_unique<ShaderLibrary>();

        // Add built-in shaders
        library->addProgram(ShaderLibrary::createUnlitProgram());
        library->addProgram(ShaderLibrary::createWireframeProgram());
        library->addProgram(ShaderLibrary::createNormalVisualizerProgram());

        std::cout << "\nAvailable shader presets:" << std::endl;
        for (const auto& name : library->getProgramNames()) {
            std::cout << "  - " << name << std::endl;
        }

        // Apply unlit shader
        std::cout << "\nApplying 'Unlit' shader..." << std::endl;
        auto unlitProgram = library->getProgram("Unlit");
        if (unlitProgram && editor->applyShaderProgram(*unlitProgram, renderer)) {
            std::cout << "✓ Unlit shader applied" << std::endl;
        }

        // Save library to disk (for user customization)
        std::string libraryPath = "/tmp/PinnacleShaders";
        std::cout << "\nSaving shader library to: " << libraryPath << std::endl;
        if (library->saveToDirectory(libraryPath)) {
            std::cout << "✓ Library saved successfully" << std::endl;
            std::cout << "  Users can now edit these files and reload them" << std::endl;
        }

        std::cout << "\n✓ Example complete." << std::endl;
    }

    // Example 3: Live shader editing (simulating user edits)

    void runLiveShaderEditingExample(PinnacleMetalRenderer* renderer)
    {
        std::cout << "\n=== Live Shader Editing Example ===" << std::endl;

        auto editor = std::make_unique<ShaderEditor>(renderer->getDevice());
        ExampleShaderDelegate delegate;
        editor->setDelegate(&delegate);

        // Create initial program
        auto program = editor->createProgram("Animated Shader");
        auto vertexShader = std::make_shared<ShaderSource>(ShaderType::Vertex, "Animated Vertex");
        auto fragmentShader = std::make_shared<ShaderSource>(ShaderType::Fragment, "Animated Fragment");

        // Initial shader (red tint)
        std::string initialFragSource = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return float4(1.0, 0.0, 0.0, 1.0); // Red
}
)";

        fragmentShader->setSource(initialFragSource);
        program->setVertexShader(vertexShader); // Can reuse vertex shader
        program->setFragmentShader(fragmentShader);

        // Apply initial version
        std::cout << "\nApplying initial shader (red)..." << std::endl;
        editor->applyShaderProgram(*program, renderer);

        // Simulate user editing the shader
        std::cout << "\nSimulating user edit: Changing color to blue..." << std::endl;
        fragmentShader->pushVersion(); // Save for undo

        std::string editedFragSource = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return float4(0.0, 0.0, 1.0, 1.0); // Blue
}
)";

        fragmentShader->setSource(editedFragSource);

        // Hot-reload with new version
        std::cout << "Recompiling and applying..." << std::endl;
        editor->applyShaderProgram(*program, renderer);

        // Demonstrate undo
        std::cout << "\nDemonstrating undo..." << std::endl;
        if (fragmentShader->undo()) {
            std::cout << "✓ Undone to previous version" << std::endl;
            editor->applyShaderProgram(*program, renderer);
            std::cout << "  Shader should be red again" << std::endl;
        }

        std::cout << "\n✓ Example complete." << std::endl;
    }

} // namespace Pinnacle
