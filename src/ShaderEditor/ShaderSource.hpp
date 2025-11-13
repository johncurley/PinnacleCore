#pragma once

#include <string>
#include <vector>
#include <memory>

namespace Pinnacle
{
    /**
     * ShaderType: Identifies the stage of the graphics pipeline
     */
    enum class ShaderType
    {
        Vertex,
        Fragment,
        Compute,
        Mesh,      // Apple Silicon mesh shaders
        Object     // Apple Silicon object shaders (paired with mesh shaders)
    };

    /**
     * ShaderSource: Manages shader source code and metadata
     * This is the core data structure for the shader editor
     */
    class ShaderSource
    {
    public:
        ShaderSource(ShaderType type, const std::string& name);
        ~ShaderSource();

        // Source code management
        void setSource(const std::string& source);
        const std::string& getSource() const { return m_source; }

        // File I/O
        bool loadFromFile(const std::string& path);
        bool saveToFile(const std::string& path) const;

        // Metadata
        ShaderType getType() const { return m_type; }
        const std::string& getName() const { return m_name; }
        void setName(const std::string& name) { m_name = name; }

        // Entry point management (for multiple functions in one file)
        void setEntryPoint(const std::string& entryPoint) { m_entryPoint = entryPoint; }
        const std::string& getEntryPoint() const { return m_entryPoint; }

        // Version tracking (for undo/redo)
        void pushVersion(); // Save current source as a history point
        bool undo();        // Revert to previous version
        bool redo();        // Move forward in history

        // Dirty flag for unsaved changes
        bool isDirty() const { return m_isDirty; }
        void clearDirty() { m_isDirty = false; }

    private:
        ShaderType m_type;
        std::string m_name;
        std::string m_source;
        std::string m_entryPoint;
        bool m_isDirty;

        // Version history for undo/redo
        std::vector<std::string> m_history;
        size_t m_historyIndex;
        static constexpr size_t MAX_HISTORY = 50;
    };

    /**
     * ShaderProgram: Represents a complete shader program (vertex + fragment, or compute)
     * This pairs shaders together for the rendering pipeline
     */
    class ShaderProgram
    {
    public:
        ShaderProgram(const std::string& name);
        ~ShaderProgram();

        void setVertexShader(std::shared_ptr<ShaderSource> shader) { m_vertexShader = shader; }
        void setFragmentShader(std::shared_ptr<ShaderSource> shader) { m_fragmentShader = shader; }
        void setComputeShader(std::shared_ptr<ShaderSource> shader) { m_computeShader = shader; }

        std::shared_ptr<ShaderSource> getVertexShader() const { return m_vertexShader; }
        std::shared_ptr<ShaderSource> getFragmentShader() const { return m_fragmentShader; }
        std::shared_ptr<ShaderSource> getComputeShader() const { return m_computeShader; }

        const std::string& getName() const { return m_name; }
        void setName(const std::string& name) { m_name = name; }

        // Check if program is complete
        bool isComplete() const;

    private:
        std::string m_name;
        std::shared_ptr<ShaderSource> m_vertexShader;
        std::shared_ptr<ShaderSource> m_fragmentShader;
        std::shared_ptr<ShaderSource> m_computeShader;
    };

} // namespace Pinnacle
