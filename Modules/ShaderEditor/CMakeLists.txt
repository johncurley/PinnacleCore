# PinnacleCore - ShaderEditor Module
# Shader editing, compilation, and live editing

cmake_minimum_required(VERSION 3.20)

project(PinnacleCore_ShaderEditor)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ShaderEditor module headers (public interface)
set(SHADER_EDITOR_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ShaderEditor/ShaderEditor.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ShaderEditor/ShaderLibrary.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ShaderEditor/ShaderCompiler.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ShaderEditor/ShaderSource.hpp
)

# ShaderEditor module implementation
set(SHADER_EDITOR_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditor.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderLibrary.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderCompiler.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderSource.mm
)

# Create ShaderEditor library
add_library(PinnacleCore_ShaderEditor STATIC
    ${SHADER_EDITOR_HEADERS}
    ${SHADER_EDITOR_SOURCES}
)

# Set include directories
target_include_directories(PinnacleCore_ShaderEditor
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Link dependencies
target_link_libraries(PinnacleCore_ShaderEditor
    PUBLIC
        PinnacleCore_Core
        PinnacleCore_Renderer
)

# Platform-specific settings
if(APPLE)
    # Enable ARC for Objective-C++
    set_source_files_properties(${SHADER_EDITOR_SOURCES}
        PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
    )

    # Link Metal frameworks
    target_link_libraries(PinnacleCore_ShaderEditor
        PUBLIC
            "-framework Metal"
            "-framework MetalKit"
            "-framework Foundation"
    )
endif()

# Export include directories for dependent modules
set(PINNACLE_SHADER_EDITOR_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include PARENT_SCOPE)
