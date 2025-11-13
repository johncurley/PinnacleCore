#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "ShaderCompiler.hpp"
#include <regex>
#include <chrono>

namespace Pinnacle
{
    ShaderCompiler::ShaderCompiler(id device)
        : m_device(device)
    {
        [(id<MTLDevice>)m_device retain];
    }

    ShaderCompiler::~ShaderCompiler()
    {
        [(id<MTLDevice>)m_device release];
    }

    CompileResult ShaderCompiler::compile(const ShaderSource& source)
    {
        CompileResult result;
        id<MTLDevice> device = (id<MTLDevice>)m_device;

        auto startTime = std::chrono::high_resolution_clock::now();

        // Convert source to NSString
        NSString* sourceCode = [NSString stringWithUTF8String:source.getSource().c_str()];

        if (!sourceCode || [sourceCode length] == 0) {
            result.errors.push_back(CompileError(
                CompileError::Severity::Error,
                0, 0,
                "Shader source is empty"
            ));
            return result;
        }

        // Create library options
        MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
        options.languageVersion = MTLLanguageVersion2_4; // Metal 2.4

        NSError* error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:sourceCode
                                                      options:options
                                                        error:&error];

        [options release];

        auto endTime = std::chrono::high_resolution_clock::now();
        result.compilationTime = std::chrono::duration<double>(endTime - startTime).count();

        if (error) {
            // Compilation failed
            result.success = false;
            parseCompilerErrors(error, result.errors);
            return result;
        }

        if (!library) {
            result.success = false;
            result.errors.push_back(CompileError(
                CompileError::Severity::Error,
                0, 0,
                "Failed to create library (unknown error)"
            ));
            return result;
        }

        // Get the function
        NSString* entryPoint = [NSString stringWithUTF8String:source.getEntryPoint().c_str()];
        id<MTLFunction> function = [library newFunctionWithName:entryPoint];

        if (!function) {
            result.success = false;
            result.errors.push_back(CompileError(
                CompileError::Severity::Error,
                0, 0,
                "Entry point '" + source.getEntryPoint() + "' not found in compiled shader"
            ));
            [library release];
            return result;
        }

        // Success!
        result.success = true;
        result.compiledFunction = function; // Transfer ownership to result
        [library release];

        return result;
    }

    ShaderCompiler::PipelineResult ShaderCompiler::compileGraphicsPipeline(
        const ShaderProgram& program,
        id vertexDescriptor,
        MTLPixelFormat colorFormat,
        MTLPixelFormat depthFormat
    )
    {
        PipelineResult result;
        id<MTLDevice> device = (id<MTLDevice>)m_device;

        if (!program.isComplete()) {
            result.errors.push_back(CompileError(
                CompileError::Severity::Error,
                0, 0,
                "Shader program is incomplete (missing vertex or fragment shader)"
            ));
            return result;
        }

        auto startTime = std::chrono::high_resolution_clock::now();

        // Compile vertex shader
        auto vertexResult = compile(*program.getVertexShader());
        if (!vertexResult.success) {
            result.errors.insert(result.errors.end(),
                               vertexResult.errors.begin(),
                               vertexResult.errors.end());
            return result;
        }

        // Compile fragment shader
        auto fragmentResult = compile(*program.getFragmentShader());
        if (!fragmentResult.success) {
            result.errors.insert(result.errors.end(),
                               fragmentResult.errors.begin(),
                               fragmentResult.errors.end());
            [(id<MTLFunction>)vertexResult.compiledFunction release];
            return result;
        }

        // Create pipeline state
        MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDescriptor.vertexFunction = (id<MTLFunction>)vertexResult.compiledFunction;
        pipelineDescriptor.fragmentFunction = (id<MTLFunction>)fragmentResult.compiledFunction;
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorFormat;

        if (depthFormat != MTLPixelFormatInvalid) {
            pipelineDescriptor.depthAttachmentPixelFormat = depthFormat;
        }

        // Set vertex descriptor if provided
        if (vertexDescriptor) {
            pipelineDescriptor.vertexDescriptor = (MTLVertexDescriptor*)vertexDescriptor;
        }

        NSError* error = nil;
        id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                                           error:&error];

        [pipelineDescriptor release];
        [(id<MTLFunction>)vertexResult.compiledFunction release];
        [(id<MTLFunction>)fragmentResult.compiledFunction release];

        auto endTime = std::chrono::high_resolution_clock::now();
        result.compilationTime = std::chrono::duration<double>(endTime - startTime).count();

        if (error) {
            result.success = false;
            parseCompilerErrors(error, result.errors);
            return result;
        }

        if (!pipelineState) {
            result.success = false;
            result.errors.push_back(CompileError(
                CompileError::Severity::Error,
                0, 0,
                "Failed to create pipeline state (unknown error)"
            ));
            return result;
        }

        result.success = true;
        result.pipelineState = pipelineState;

        return result;
    }

    void ShaderCompiler::parseCompilerErrors(NSError* error, std::vector<CompileError>& outErrors)
    {
        if (!error) return;

        NSString* errorDescription = [error localizedDescription];
        std::string errorMsg = [errorDescription UTF8String];

        // Metal compiler error format is typically:
        // "program_source:LINE:COLUMN: error: MESSAGE"
        // or
        // "program_source:LINE:COLUMN: warning: MESSAGE"

        std::istringstream stream(errorMsg);
        std::string line;

        while (std::getline(stream, line)) {
            // Skip empty lines
            if (line.empty()) continue;

            // Try to parse line number
            int lineNum = extractLineNumber(line);

            // Determine severity
            CompileError::Severity severity = CompileError::Severity::Error;
            if (line.find("warning:") != std::string::npos) {
                severity = CompileError::Severity::Warning;
            }

            // Extract message (everything after "error:" or "warning:")
            std::string message = line;
            size_t errorPos = line.find("error:");
            size_t warningPos = line.find("warning:");

            if (errorPos != std::string::npos) {
                message = line.substr(errorPos + 7); // Skip "error: "
            } else if (warningPos != std::string::npos) {
                message = line.substr(warningPos + 9); // Skip "warning: "
            }

            // Trim leading/trailing whitespace
            message.erase(0, message.find_first_not_of(" \t\n\r"));
            message.erase(message.find_last_not_of(" \t\n\r") + 1);

            outErrors.push_back(CompileError(
                severity,
                lineNum,
                0, // Column parsing is complex, skip for now
                message
            ));
        }

        // If we didn't find any specific errors, add a generic one
        if (outErrors.empty()) {
            outErrors.push_back(CompileError(
                CompileError::Severity::Error,
                0, 0,
                errorMsg
            ));
        }
    }

    int ShaderCompiler::extractLineNumber(const std::string& message)
    {
        // Look for pattern: :NUMBER:
        std::regex lineRegex(":([0-9]+):");
        std::smatch match;

        if (std::regex_search(message, match, lineRegex)) {
            try {
                return std::stoi(match[1].str()) - 1; // Convert to 0-based
            } catch (...) {
                return 0;
            }
        }

        return 0;
    }

} // namespace Pinnacle
