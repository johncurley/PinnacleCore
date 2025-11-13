# PinnacleCore - Core Module
# Foundation components: Scene Graph, Camera, Materials, Meshes, Textures

cmake_minimum_required(VERSION 3.20)

project(PinnacleCore_Core)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Core module headers (public interface)
set(CORE_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/Camera.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/Scene.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/InputManager.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/Material.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/Mesh.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/Node.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/Texture.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Core/Math.hpp
)

# Core module implementation
set(CORE_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Camera.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Scene.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/InputManager.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Material.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Mesh.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Node.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Texture.mm
)

# Create Core library
add_library(PinnacleCore_Core STATIC
    ${CORE_HEADERS}
    ${CORE_SOURCES}
)

# Set include directories
target_include_directories(PinnacleCore_Core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Platform-specific settings
if(APPLE)
    # Enable ARC for Objective-C++
    set_source_files_properties(${CORE_SOURCES}
        PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
    )

    # Link Metal frameworks
    target_link_libraries(PinnacleCore_Core
        PUBLIC
            "-framework Metal"
            "-framework MetalKit"
            "-framework Foundation"
    )
endif()

# Export include directories for dependent modules
set(PINNACLE_CORE_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include PARENT_SCOPE)
