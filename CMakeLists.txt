cmake_minimum_required(VERSION 3.26)
project(PinnacleCore LANGUAGES CXX OBJCXX Swift)
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0")

# -----------------------------------------------------------------------------
# Build and language setup
# -----------------------------------------------------------------------------
set(CMAKE_XCODE_ATTRIBUTE_SWIFT_VERSION "5.0")
set(CMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD 17)

# -----------------------------------------------------------------------------
# Source files
# -----------------------------------------------------------------------------


set(SWIFT_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/MetalExampleApp.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/ContentView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/MetalView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/ShaderEditorView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/ShaderEditorViewModel.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/SceneInspectorView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/MaterialCreatorView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/BatchConverterView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/TextureManagerView.swift
)

set(OBJCXX_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Core/Camera.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Core/InputManager.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Core/Scene.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Renderer/Renderer.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Scene/Material.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Scene/Mesh.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Scene/Model.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Scene/Node.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Scene/Texture.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditor/ShaderSource.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditor/ShaderCompiler.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditor/ShaderEditor.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditor/ShaderLibrary.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditor/ShaderEditorExample.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/PinnacleBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/ShaderEditorBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/SceneInspectorBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/CameraControlsBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/EnvironmentControlsBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/USDZExportBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/MaterialFixerBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/BatchConverterBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/TextureManagerBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/PinnacleMetalImplementation.mm
)



set(CXX_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/libs.cpp
)

set(METAL_SHADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Shaders/triangle.metal
)

set_source_files_properties(${METAL_SHADERS} PROPERTIES LANGUAGE METAL)

# -----------------------------------------------------------------------------
# App target
# -----------------------------------------------------------------------------
add_executable(PinnacleCore MACOSX_BUNDLE
    ${SWIFT_FILES}
    ${OBJCXX_FILES}
    ${CXX_FILES}
    ${METAL_SHADERS}
)

# -----------------------------------------------------------------------------
# Framework linking
# -----------------------------------------------------------------------------
target_link_libraries(PinnacleCore
    "-framework Cocoa"
    "-framework Metal"
    "-framework MetalKit"
    "-framework Foundation"
    "-framework SwiftUI"
    "-framework Quartz"
)

# -----------------------------------------------------------------------------
# ARC for ObjC++
# -----------------------------------------------------------------------------
set_source_files_properties(${OBJCXX_FILES} PROPERTIES COMPILE_FLAGS "-fobjc-arc")

# Disable ARC for PinnacleMetalImplementation.mm due to manual memory management
set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/src/PinnacleMetalImplementation.mm PROPERTIES COMPILE_FLAGS "-fno-objc-arc")

# -----------------------------------------------------------------------------
# Include directories
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Fetch or locate metal-cpp (bkaradzic fork)
# -----------------------------------------------------------------------------
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
    target_include_directories(PinnacleCore PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/MetalExample
        ${CMAKE_SOURCE_DIR}
        ${CMAKE_SOURCE_DIR}/metal-cpp
        ${CMAKE_SOURCE_DIR}/libs
    )
else()
    message(WARNING "⚠️  Failed to locate or fetch metal-cpp.")
endif()

# -----------------------------------------------------------------------------
# Swift bridging header
# -----------------------------------------------------------------------------
set_target_properties(PinnacleCore PROPERTIES
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/src/SwiftUI/PinnacleBridge.h"
    RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/Shaders"
)

# -----------------------------------------------------------------------------
# Bundle metadata
# -----------------------------------------------------------------------------
set_target_properties(PinnacleCore PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.pinnacle.core"
    MACOSX_BUNDLE_BUNDLE_NAME "PinnacleCore"
    MACOSX_BUNDLE_BUNDLE_VERSION "1.0"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)
