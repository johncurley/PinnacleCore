# PinnacleCore - Modular Architecture
# Main build configuration for all modules

cmake_minimum_required(VERSION 3.20)

project(PinnacleCore_Modules)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable Objective-C++ support
enable_language(OBJCXX)

# Fetch or locate metal-cpp (bkaradzic fork)
include(FetchContent)

find_path(METAL_CPP_PATH "metal/metal.hpp"
    PATHS
        "${CMAKE_SOURCE_DIR}/external/metal-cpp"
        "${CMAKE_SOURCE_DIR}/metal-cpp"
        "/usr/local/include/metal-cpp"
    NO_DEFAULT_PATH
)

if(NOT METAL_CPP_PATH)
    message(STATUS "Fetching metal-cpp from bkaradzic/metal-cpp ...")
    FetchContent_Declare(
        metalcpp
        GIT_REPOSITORY https://github.com/bkaradzic/metal-cpp.git
        GIT_TAG main
    )
    FetchContent_MakeAvailable(metalcpp)
    set(METAL_CPP_PATH ${metalcpp_SOURCE_DIR})
endif()

if(METAL_CPP_PATH)
    message(STATUS "Using metal-cpp from: ${METAL_CPP_PATH}")
else()
    message(FATAL_ERROR "Failed to locate or fetch metal-cpp")
endif()

# Add metal-cpp to include path for all modules
include_directories(
    ${METAL_CPP_PATH}
    ${CMAKE_SOURCE_DIR}/metal-cpp
    ${CMAKE_SOURCE_DIR}/libs
)

# -----------------------------------------------------------------------------
# Build modules in dependency order
# -----------------------------------------------------------------------------

# 1. Core module (foundation - no dependencies)
message(STATUS "Configuring Core module...")
add_subdirectory(Core)

# 2. Loaders module (depends on Core)
message(STATUS "Configuring Loaders module...")
add_subdirectory(Loaders)

# 3. Renderer module (depends on Core)
message(STATUS "Configuring Renderer module...")
add_subdirectory(Renderer)

# 4. ShaderEditor module (depends on Core, Renderer)
message(STATUS "Configuring ShaderEditor module...")
add_subdirectory(ShaderEditor)

# 5. Tools module (depends on Core, Loaders, Renderer)
message(STATUS "Configuring Tools module...")
add_subdirectory(Tools)

# 6. UI module (depends on all other modules)
message(STATUS "Configuring UI module...")
add_subdirectory(UI)

# -----------------------------------------------------------------------------
# Export module information to parent scope
# -----------------------------------------------------------------------------

# Collect all module libraries
set(PINNACLE_MODULE_LIBS
    PinnacleCore_Core
    PinnacleCore_Loaders
    PinnacleCore_Renderer
    PinnacleCore_ShaderEditor
    PinnacleCore_Tools
    PinnacleCore_UI
    PARENT_SCOPE
)

# Collect all include directories
set(PINNACLE_MODULE_INCLUDES
    ${PINNACLE_CORE_INCLUDE_DIR}
    ${PINNACLE_LOADERS_INCLUDE_DIR}
    ${PINNACLE_RENDERER_INCLUDE_DIR}
    ${PINNACLE_SHADER_EDITOR_INCLUDE_DIR}
    ${PINNACLE_TOOLS_INCLUDE_DIR}
    ${PINNACLE_UI_INCLUDE_DIR}
    PARENT_SCOPE
)

# Export Swift files
set(PINNACLE_SWIFT_FILES ${PINNACLE_UI_SWIFT_FILES} PARENT_SCOPE)

message(STATUS "")
message(STATUS "========================================")
message(STATUS "PinnacleCore Modular Build Configuration")
message(STATUS "========================================")
message(STATUS "Modules configured:")
message(STATUS "  ✓ Core         - Scene graph, materials, meshes")
message(STATUS "  ✓ Loaders      - glTF, FBX, OBJ file loaders")
message(STATUS "  ✓ Renderer     - Metal rendering engine")
message(STATUS "  ✓ ShaderEditor - Shader editing system")
message(STATUS "  ✓ Tools        - Asset tools and utilities")
message(STATUS "  ✓ UI           - SwiftUI views and bridges")
message(STATUS "========================================")
message(STATUS "")
