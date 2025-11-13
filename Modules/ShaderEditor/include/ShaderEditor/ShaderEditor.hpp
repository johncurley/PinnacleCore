#pragma once

#include "ShaderSource.hpp"
#include "ShaderCompiler.hpp"
#include <string>
#include <memory>
#include <functional>

#ifdef __OBJC__
#import <Metal/Metal.h>
#else
typedef void* id;
#endif

namespace Pinnacle
{
    /**
     * ShaderEditorDelegate: Callback interface for shader editor events
     * Implement this to receive notifications from the shader editor
     */
    class ShaderEditorDelegate
    {
    public:
        virtual ~ShaderEditorDelegate() = default;

        // Called when compilation succeeds
        virtual void onCompilationSuccess(const ShaderProgram& program, double compilationTime) {}

        // Called when compilation fails
        virtual void onCompilationError(const ShaderProgram& program, const std::vector<CompileError>& errors) {}

        // Called when shader source is modified
        virtual void onShaderModified(const ShaderSource& source) {}
    };

    /**
     * ShaderEditor: Main interface for the shader editing system
     * This coordinates between the compiler, source management, and renderer
     */
    class ShaderEditor
    {
    public:
        ShaderEditor(id device);
        ~ShaderEditor();

        /**
         * Create a new shader program
         */
        std::shared_ptr<ShaderProgram> createProgram(const std::string& name);

        /**
         * Load a shader from file
         */
        std::shared_ptr<ShaderSource> loadShader(const std::string& path, ShaderType type);

        /**
         * Compile and test a shader program
         * This compiles the shaders but doesn't activate them in the renderer
         */
        ShaderCompiler::PipelineResult testCompile(const ShaderProgram& program);

        /**
         * Compile and apply a shader program to the renderer
         * This is the "hot-reload" function that updates the active shader
         */
        bool applyShaderProgram(const ShaderProgram& program, id renderer);

        /**
         * Get the compiler
         */
        ShaderCompiler& getCompiler() { return *m_compiler; }

        /**
         * Set delegate for callbacks
         */
        void setDelegate(ShaderEditorDelegate* delegate) { m_delegate = delegate; }

        /**
         * Auto-compile: Automatically recompile when source changes
         */
        void setAutoCompile(bool enabled) { m_autoCompile = enabled; }
        bool getAutoCompile() const { return m_autoCompile; }

        /**
         * Get current active program
         */
        std::shared_ptr<ShaderProgram> getActiveProgram() const { return m_activeProgram; }

    private:
        id m_device;
        std::unique_ptr<ShaderCompiler> m_compiler;
        ShaderEditorDelegate* m_delegate;
        bool m_autoCompile;

        std::shared_ptr<ShaderProgram> m_activeProgram;
        id m_activePipelineState; // id<MTLRenderPipelineState>

        // Vertex descriptor cache (for pipeline creation)
        id m_cachedVertexDescriptor;
    };

    /**
     * RendererShaderInterface: Extension methods for PinnacleMetalRenderer
     * These methods would be added to your renderer to support hot-reload
     */
    class RendererShaderInterface
    {
    public:
        /**
         * Replace the current pipeline state with a new one
         * Call this when a shader is hot-reloaded
         */
        virtual bool setCustomPipelineState(id pipelineState) = 0;

        /**
         * Reset to default shaders
         */
        virtual void resetToDefaultShaders() = 0;

        /**
         * Get the vertex descriptor used by the renderer
         */
        virtual id getVertexDescriptor() = 0;

        virtual ~RendererShaderInterface() = default;
    };

} // namespace Pinnacle
