#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "ShaderEditor.hpp"
#include <iostream>

namespace Pinnacle
{
    ShaderEditor::ShaderEditor(id device)
        : m_device(device)
        , m_compiler(std::make_unique<ShaderCompiler>(device))
        , m_delegate(nullptr)
        , m_autoCompile(false)
        , m_activePipelineState(nil)
        , m_cachedVertexDescriptor(nil)
    {
        [(id<MTLDevice>)m_device retain];
    }

    ShaderEditor::~ShaderEditor()
    {
        if (m_activePipelineState) {
            [(id<MTLRenderPipelineState>)m_activePipelineState release];
        }
        if (m_cachedVertexDescriptor) {
            [(MTLVertexDescriptor*)m_cachedVertexDescriptor release];
        }
        [(id<MTLDevice>)m_device release];
    }

    std::shared_ptr<ShaderProgram> ShaderEditor::createProgram(const std::string& name)
    {
        return std::make_shared<ShaderProgram>(name);
    }

    std::shared_ptr<ShaderSource> ShaderEditor::loadShader(const std::string& path, ShaderType type)
    {
        // Extract name from path
        size_t lastSlash = path.find_last_of("/\\");
        size_t lastDot = path.find_last_of(".");
        std::string name = path.substr(lastSlash + 1, lastDot - lastSlash - 1);

        auto shader = std::make_shared<ShaderSource>(type, name);

        if (!shader->loadFromFile(path)) {
            std::cerr << "Failed to load shader from: " << path << std::endl;
            return nullptr;
        }

        std::cout << "Loaded shader: " << name << " from " << path << std::endl;
        return shader;
    }

    ShaderCompiler::PipelineResult ShaderEditor::testCompile(const ShaderProgram& program)
    {
        std::cout << "Test compiling shader program: " << program.getName() << std::endl;

        // Use cached vertex descriptor if available
        id vertexDescriptor = m_cachedVertexDescriptor;

        // If no cached descriptor, create default one matching the PBR viewer
        if (!vertexDescriptor) {
            MTLVertexDescriptor* desc = [[MTLVertexDescriptor alloc] init];

            // Position attribute (float3)
            desc.attributes[0].format = MTLVertexFormatFloat3;
            desc.attributes[0].offset = 0;
            desc.attributes[0].bufferIndex = 0;

            // Normal attribute (float3)
            desc.attributes[1].format = MTLVertexFormatFloat3;
            desc.attributes[1].offset = sizeof(simd_float3);
            desc.attributes[1].bufferIndex = 0;

            // TexCoords attribute (float2)
            desc.attributes[2].format = MTLVertexFormatFloat2;
            desc.attributes[2].offset = sizeof(simd_float3) * 2;
            desc.attributes[2].bufferIndex = 0;

            // Layout for buffer 0 (vertices)
            desc.layouts[0].stride = sizeof(simd_float3) * 2 + sizeof(simd_float2);
            desc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

            m_cachedVertexDescriptor = desc;
            vertexDescriptor = desc;
        }

        auto result = m_compiler->compileGraphicsPipeline(
            program,
            vertexDescriptor,
            MTLPixelFormatBGRA8Unorm,
            MTLPixelFormatDepth32Float
        );

        if (result.success) {
            std::cout << "✓ Compilation successful in " << result.compilationTime << "s" << std::endl;

            if (m_delegate) {
                m_delegate->onCompilationSuccess(program, result.compilationTime);
            }
        } else {
            std::cerr << "✗ Compilation failed:" << std::endl;
            for (const auto& error : result.errors) {
                std::cerr << "  Line " << (error.line + 1) << ": "
                         << (error.severity == CompileError::Severity::Error ? "ERROR" : "WARNING")
                         << " - " << error.message << std::endl;
            }

            if (m_delegate) {
                m_delegate->onCompilationError(program, result.errors);
            }
        }

        return result;
    }

    bool ShaderEditor::applyShaderProgram(const ShaderProgram& program, id renderer)
    {
        std::cout << "Applying shader program: " << program.getName() << std::endl;

        // Compile the program
        auto result = testCompile(program);

        if (!result.success) {
            std::cerr << "Cannot apply shader program - compilation failed" << std::endl;
            return false;
        }

        // Check if renderer supports custom pipeline state
        RendererShaderInterface* shaderInterface = dynamic_cast<RendererShaderInterface*>((IPinnacleMetalRenderer*)renderer);

        if (!shaderInterface) {
            std::cerr << "Renderer does not support shader hot-reload interface" << std::endl;
            [(id<MTLRenderPipelineState>)result.pipelineState release];
            return false;
        }

        // Apply the new pipeline state
        bool applied = shaderInterface->setCustomPipelineState(result.pipelineState);

        if (applied) {
            // Release old pipeline state
            if (m_activePipelineState) {
                [(id<MTLRenderPipelineState>)m_activePipelineState release];
            }

            // Store new state
            m_activePipelineState = result.pipelineState;
            m_activeProgram = std::make_shared<ShaderProgram>(program);

            std::cout << "✓ Shader hot-reload successful!" << std::endl;
        } else {
            std::cerr << "✗ Failed to apply shader to renderer" << std::endl;
            [(id<MTLRenderPipelineState>)result.pipelineState release];
        }

        return applied;
    }

} // namespace Pinnacle
