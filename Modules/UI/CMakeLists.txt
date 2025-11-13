# PinnacleCore - UI Module
# SwiftUI views and Objective-C++ bridges

cmake_minimum_required(VERSION 3.20)

project(PinnacleCore_UI)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# UI module headers (bridges - public interface)
set(UI_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/PinnacleBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/CameraControlsBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/EnvironmentControlsBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/SceneInspectorBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/ShaderEditorBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/BatchConverterBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/TextureManagerBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/ModelValidatorBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/AssetOptimizerBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/MaterialFixerBridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/UI/USDZExportBridge.h
)

# UI module bridge implementation
set(UI_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/PinnacleBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/CameraControlsBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/EnvironmentControlsBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SceneInspectorBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditorBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/BatchConverterBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/TextureManagerBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ModelValidatorBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AssetOptimizerBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/MaterialFixerBridge.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/USDZExportBridge.mm
)

# SwiftUI view files
set(UI_SWIFT_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ContentView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/MetalView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditorView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/SceneInspectorView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/MaterialCreatorView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/BatchConverterView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/TextureManagerView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ModelValidatorView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AssetOptimizerView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ShaderEditorViewModel.swift
)

# Create UI library (Objective-C++ bridges only)
add_library(PinnacleCore_UI STATIC
    ${UI_HEADERS}
    ${UI_SOURCES}
)

# Set include directories
target_include_directories(PinnacleCore_UI
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Link dependencies
target_link_libraries(PinnacleCore_UI
    PUBLIC
        PinnacleCore_Core
        PinnacleCore_Loaders
        PinnacleCore_Renderer
        PinnacleCore_ShaderEditor
        PinnacleCore_Tools
)

# Platform-specific settings
if(APPLE)
    # Enable ARC for Objective-C++
    set_source_files_properties(${UI_SOURCES}
        PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
    )

    # Link frameworks
    target_link_libraries(PinnacleCore_UI
        PUBLIC
            "-framework Cocoa"
            "-framework Metal"
            "-framework MetalKit"
            "-framework Foundation"
            "-framework SwiftUI"
            "-framework Quartz"
    )
endif()

# Export Swift files for main app target
set(PINNACLE_UI_SWIFT_FILES ${UI_SWIFT_FILES} PARENT_SCOPE)
set(PINNACLE_UI_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include PARENT_SCOPE)
