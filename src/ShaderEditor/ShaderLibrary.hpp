#pragma once

#include "ShaderSource.hpp"
#include <string>
#include <map>
#include <memory>
#include <vector>

namespace Pinnacle
{
    /**
     * ShaderLibrary: Manages a collection of shader programs
     * This is useful for organizing presets, templates, and user-created shaders
     */
    class ShaderLibrary
    {
    public:
        ShaderLibrary();
        ~ShaderLibrary();

        /**
         * Add a program to the library
         */
        void addProgram(std::shared_ptr<ShaderProgram> program);

        /**
         * Remove a program by name
         */
        bool removeProgram(const std::string& name);

        /**
         * Get a program by name
         */
        std::shared_ptr<ShaderProgram> getProgram(const std::string& name) const;

        /**
         * Get all program names
         */
        std::vector<std::string> getProgramNames() const;

        /**
         * Check if a program exists
         */
        bool hasProgram(const std::string& name) const;

        /**
         * Clear all programs
         */
        void clear();

        /**
         * Load library from directory
         * Scans directory for .metal files and creates programs
         */
        bool loadFromDirectory(const std::string& path);

        /**
         * Save library to directory
         * Saves all shader source files to the directory
         */
        bool saveToDirectory(const std::string& path) const;

        /**
         * Built-in shaders
         */
        static std::shared_ptr<ShaderProgram> createDefaultPBRProgram();
        static std::shared_ptr<ShaderProgram> createUnlitProgram();
        static std::shared_ptr<ShaderProgram> createWireframeProgram();
        static std::shared_ptr<ShaderProgram> createNormalVisualizerProgram();

    private:
        std::map<std::string, std::shared_ptr<ShaderProgram>> m_programs;
    };

} // namespace Pinnacle
