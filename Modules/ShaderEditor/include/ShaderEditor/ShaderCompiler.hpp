#pragma once

#include "ShaderSource.hpp"
#include <string>
#include <vector>
#include <memory>

#ifdef __OBJC__
#import <Metal/Metal.h>
#else
typedef void* id;
#endif

namespace Pinnacle
{
    /**
     * CompileError: Represents a compilation error or warning
     */
    struct CompileError
    {
        enum class Severity
        {
            Warning,
            Error
        };

        Severity severity;
        int line;           // Line number (0-based)
        int column;         // Column number (0-based)
        std::string message;
        std::string code;   // The offending line of code (for display)

        CompileError(Severity sev, int ln, int col, const std::string& msg, const std::string& c = "")
            : severity(sev), line(ln), column(col), message(msg), code(c)
        {}
    };

    /**
     * CompileResult: The result of a shader compilation attempt
     */
    struct CompileResult
    {
        bool success;
        std::vector<CompileError> errors;
        id compiledFunction;  // id<MTLFunction> on success, nil on failure
        double compilationTime; // Time in seconds

        CompileResult()
            : success(false)
            , compiledFunction(nil)
            , compilationTime(0.0)
        {}
    };

    /**
     * ShaderCompiler: Handles live compilation of Metal shaders
     * This is the core engine for hot-reload functionality
     */
    class ShaderCompiler
    {
    public:
        ShaderCompiler(id device);
        ~ShaderCompiler();

        /**
         * Compile a shader source to a Metal function
         * This is synchronous and happens on the calling thread
         */
        CompileResult compile(const ShaderSource& source);

        /**
         * Compile a complete shader program (vertex + fragment)
         * Returns pipeline state on success
         */
        struct PipelineResult
        {
            bool success;
            std::vector<CompileError> errors;
            id pipelineState;  // id<MTLRenderPipelineState>
            double compilationTime;

            PipelineResult()
                : success(false)
                , pipelineState(nil)
                , compilationTime(0.0)
            {}
        };

        PipelineResult compileGraphicsPipeline(
            const ShaderProgram& program,
            id vertexDescriptor = nil,    // id<MTLVertexDescriptor>
            MTLPixelFormat colorFormat = MTLPixelFormatBGRA8Unorm,
            MTLPixelFormat depthFormat = MTLPixelFormatDepth32Float
        );

        /**
         * Get the device being used for compilation
         */
        id getDevice() const { return m_device; }

    private:
        id m_device; // id<MTLDevice>

        // Parse error messages from Metal compiler
        void parseCompilerErrors(NSError* error, std::vector<CompileError>& outErrors);

        // Extract line number from error message
        int extractLineNumber(const std::string& message);
    };

} // namespace Pinnacle
