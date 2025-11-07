cmake_minimum_required(VERSION 3.26)
project(PinnacleCore LANGUAGES CXX OBJCXX Swift)

# -----------------------------------------------------------------------------
# Build and language setup
# -----------------------------------------------------------------------------
set(CMAKE_XCODE_ATTRIBUTE_SWIFT_VERSION "5.0")
set(CMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_SWIFT_STANDARD 5)

# -----------------------------------------------------------------------------
# Source files
# -----------------------------------------------------------------------------
set(SWIFT_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/MetalExample/SwiftUI/MetalExampleApp.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/MetalExample/SwiftUI/ContentView.swift
    ${CMAKE_CURRENT_SOURCE_DIR}/MetalExample/SwiftUI/MetalViewContainer.swift
)

set(OBJCXX_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/MetalExample/MetalCppImpl.mm
)



# -----------------------------------------------------------------------------
# App target
# -----------------------------------------------------------------------------
add_executable(PinnacleCore MACOSX_BUNDLE
    ${SWIFT_FILES}
    ${OBJCXX_FILES}
)

# -----------------------------------------------------------------------------
# Framework linking
# -----------------------------------------------------------------------------
target_link_libraries(PinnacleCore
    "-framework Cocoa"
    "-framework Metal"
    "-framework MetalKit"
    "-framework SwiftUI"
)

# -----------------------------------------------------------------------------
# ARC for ObjC++
# -----------------------------------------------------------------------------
set_source_files_properties(${OBJCXX_FILES} PROPERTIES COMPILE_FLAGS "-fobjc-arc")

# -----------------------------------------------------------------------------
# Include directories
# -----------------------------------------------------------------------------
target_include_directories(PinnacleCore PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/MetalExample
)

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
    target_include_directories(PinnacleCore PRIVATE ${METAL_CPP_PATH})
else()
    message(WARNING "⚠️  Failed to locate or fetch metal-cpp.")
endif()

# -----------------------------------------------------------------------------
# Swift bridging header
# -----------------------------------------------------------------------------
set_target_properties(PinnacleCore PROPERTIES
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/MetalExample/SwiftUI/PinnacleBridge.h"
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
