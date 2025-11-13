#pragma once

/**
 * ShaderEditorExample.hpp
 *
 * This file demonstrates how to use the Pinnacle Shader Editor system for hot-reloading shaders.
 *
 * USAGE OVERVIEW:
 *
 * 1. Create a ShaderEditor instance with your Metal device
 * 2. Create or load shader programs
 * 3. Compile and test shaders
 * 4. Apply shaders to the renderer for hot-reload
 * 5. Reset to default shaders when needed
 *
 * EXAMPLE WORKFLOW:
 *
 * ```cpp
 * // 1. Setup
 * auto renderer = createPinnacleMetalRenderer();
 * auto editor = std::make_unique<Pinnacle::ShaderEditor>(renderer->getDevice());
 *
 * // 2. Create a shader program
 * auto program = editor->createProgram("My Custom Shader");
 *
 * // 3. Load shader sources
 * auto vertexShader = std::make_shared<Pinnacle::ShaderSource>(
 *     Pinnacle::ShaderType::Vertex, "Custom Vertex");
 * vertexShader->setSource(myVertexShaderCode);
 *
 * auto fragmentShader = std::make_shared<Pinnacle::ShaderSource>(
 *     Pinnacle::ShaderType::Fragment, "Custom Fragment");
 * fragmentShader->setSource(myFragmentShaderCode);
 *
 * program->setVertexShader(vertexShader);
 * program->setFragmentShader(fragmentShader);
 *
 * // 4. Test compilation (without applying)
 * auto result = editor->testCompile(*program);
 * if (result.success) {
 *     std::cout << "Compilation successful!" << std::endl;
 * } else {
 *     for (const auto& error : result.errors) {
 *         std::cerr << "Line " << error.line << ": " << error.message << std::endl;
 *     }
 * }
 *
 * // 5. Apply to renderer (hot-reload)
 * if (editor->applyShaderProgram(*program, renderer)) {
 *     std::cout << "Shader hot-reloaded!" << std::endl;
 * }
 *
 * // 6. Reset to default
 * renderer->resetToDefaultShaders();
 * ```
 *
 * BUILT-IN SHADER LIBRARY:
 *
 * ```cpp
 * auto library = std::make_unique<Pinnacle::ShaderLibrary>();
 *
 * // Add built-in presets
 * library->addProgram(Pinnacle::ShaderLibrary::createUnlitProgram());
 * library->addProgram(Pinnacle::ShaderLibrary::createWireframeProgram());
 * library->addProgram(Pinnacle::ShaderLibrary::createNormalVisualizerProgram());
 *
 * // Apply a preset
 * auto unlitProgram = library->getProgram("Unlit");
 * if (unlitProgram) {
 *     editor->applyShaderProgram(*unlitProgram, renderer);
 * }
 * ```
 *
 * ERROR HANDLING:
 *
 * The compiler provides detailed error information:
 * - Line numbers (0-based)
 * - Error severity (Error or Warning)
 * - Descriptive error messages
 * - Compilation time
 *
 * SHADER CALLBACKS:
 *
 * ```cpp
 * class MyDelegate : public Pinnacle::ShaderEditorDelegate {
 *     void onCompilationSuccess(const Pinnacle::ShaderProgram& program, double time) override {
 *         std::cout << "✓ " << program.getName() << " compiled in " << time << "s" << std::endl;
 *     }
 *
 *     void onCompilationError(const Pinnacle::ShaderProgram& program,
 *                            const std::vector<Pinnacle::CompileError>& errors) override {
 *         std::cerr << "✗ " << program.getName() << " failed to compile" << std::endl;
 *     }
 * };
 *
 * MyDelegate delegate;
 * editor->setDelegate(&delegate);
 * ```
 */

#include "ShaderEditor.hpp"
#include "ShaderLibrary.hpp"
#include "../PinnacleMetalRenderer.h"

namespace Pinnacle
{
    /**
     * Example delegate for logging shader compilation events
     */
    class ExampleShaderDelegate : public ShaderEditorDelegate
    {
    public:
        void onCompilationSuccess(const ShaderProgram& program, double compilationTime) override;
        void onCompilationError(const ShaderProgram& program, const std::vector<CompileError>& errors) override;
        void onShaderModified(const ShaderSource& source) override;
    };

    /**
     * Example function demonstrating basic shader editor usage
     */
    void runShaderEditorExample(PinnacleMetalRenderer* renderer);

    /**
     * Example function demonstrating shader library usage
     */
    void runShaderLibraryExample(PinnacleMetalRenderer* renderer);

    /**
     * Example function demonstrating live shader editing
     */
    void runLiveShaderEditingExample(PinnacleMetalRenderer* renderer);

} // namespace Pinnacle
