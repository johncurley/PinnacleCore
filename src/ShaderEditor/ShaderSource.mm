#import <Foundation/Foundation.h>
#include "ShaderSource.hpp"
#include <fstream>
#include <sstream>

namespace Pinnacle
{
    ShaderSource::ShaderSource(ShaderType type, const std::string& name)
        : m_type(type)
        , m_name(name)
        , m_source("")
        , m_entryPoint("")
        , m_isDirty(false)
        , m_historyIndex(0)
    {
        // Set default entry points based on type
        switch (type) {
            case ShaderType::Vertex:
                m_entryPoint = "vertexShader";
                break;
            case ShaderType::Fragment:
                m_entryPoint = "fragmentShader";
                break;
            case ShaderType::Compute:
                m_entryPoint = "computeShader";
                break;
            case ShaderType::Mesh:
                m_entryPoint = "meshShader";
                break;
            case ShaderType::Object:
                m_entryPoint = "objectShader";
                break;
        }
    }

    ShaderSource::~ShaderSource()
    {
    }

    void ShaderSource::setSource(const std::string& source)
    {
        if (m_source != source) {
            m_source = source;
            m_isDirty = true;
        }
    }

    bool ShaderSource::loadFromFile(const std::string& path)
    {
        NSString* nsPath = [NSString stringWithUTF8String:path.c_str()];
        NSError* error = nil;
        NSString* content = [NSString stringWithContentsOfFile:nsPath
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];

        if (error) {
            NSLog(@"Failed to load shader from file: %@", error);
            return false;
        }

        m_source = std::string([content UTF8String]);
        m_isDirty = false;

        // Initialize history with loaded source
        m_history.clear();
        m_history.push_back(m_source);
        m_historyIndex = 0;

        return true;
    }

    bool ShaderSource::saveToFile(const std::string& path) const
    {
        NSString* nsPath = [NSString stringWithUTF8String:path.c_str()];
        NSString* content = [NSString stringWithUTF8String:m_source.c_str()];
        NSError* error = nil;

        [content writeToFile:nsPath
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:&error];

        if (error) {
            NSLog(@"Failed to save shader to file: %@", error);
            return false;
        }

        return true;
    }

    void ShaderSource::pushVersion()
    {
        // Remove any history after current index (for when user undid and then made new changes)
        if (m_historyIndex < m_history.size() - 1) {
            m_history.erase(m_history.begin() + m_historyIndex + 1, m_history.end());
        }

        // Add current version
        m_history.push_back(m_source);

        // Limit history size
        if (m_history.size() > MAX_HISTORY) {
            m_history.erase(m_history.begin());
        } else {
            m_historyIndex++;
        }
    }

    bool ShaderSource::undo()
    {
        if (m_historyIndex > 0) {
            m_historyIndex--;
            m_source = m_history[m_historyIndex];
            m_isDirty = true;
            return true;
        }
        return false;
    }

    bool ShaderSource::redo()
    {
        if (m_historyIndex < m_history.size() - 1) {
            m_historyIndex++;
            m_source = m_history[m_historyIndex];
            m_isDirty = true;
            return true;
        }
        return false;
    }

    // ShaderProgram implementation

    ShaderProgram::ShaderProgram(const std::string& name)
        : m_name(name)
    {
    }

    ShaderProgram::~ShaderProgram()
    {
    }

    bool ShaderProgram::isComplete() const
    {
        // For compute shaders, only compute shader is needed
        if (m_computeShader) {
            return true;
        }

        // For graphics pipeline, both vertex and fragment are needed
        return (m_vertexShader && m_fragmentShader);
    }

} // namespace Pinnacle
