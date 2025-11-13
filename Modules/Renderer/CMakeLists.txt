# PinnacleCore - Renderer Module
# Metal rendering engine and shaders

cmake_minimum_required(VERSION 3.20)

project(PinnacleCore_Renderer)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Renderer module headers (public interface)
set(RENDERER_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Renderer/Renderer.hpp
)

# Renderer module implementation
set(RENDERER_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Renderer.mm
)

# Metal shader files
file(GLOB METAL_SHADERS "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.metal")

# Create Renderer library
add_library(PinnacleCore_Renderer STATIC
    ${RENDERER_HEADERS}
    ${RENDERER_SOURCES}
    ${METAL_SHADERS}
)

# Set include directories
target_include_directories(PinnacleCore_Renderer
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Link dependencies
target_link_libraries(PinnacleCore_Renderer
    PUBLIC
        PinnacleCore_Core
)

# Platform-specific settings
if(APPLE)
    # Enable ARC for Objective-C++
    set_source_files_properties(${RENDERER_SOURCES}
        PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
    )

    # Link Metal frameworks
    target_link_libraries(PinnacleCore_Renderer
        PUBLIC
            "-framework Metal"
            "-framework MetalKit"
            "-framework Foundation"
            "-framework Quartz"
    )

    # Set shaders as resource files
    set_source_files_properties(${METAL_SHADERS}
        PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources/Shaders
    )
endif()

# Export include directories for dependent modules
set(PINNACLE_RENDERER_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include PARENT_SCOPE)
