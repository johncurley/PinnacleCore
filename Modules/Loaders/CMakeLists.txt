# PinnacleCore - Loaders Module
# File format loaders: glTF, GLB, FBX, OBJ, USDZ

cmake_minimum_required(VERSION 3.20)

project(PinnacleCore_Loaders)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fetch Assimp for FBX/OBJ support
include(FetchContent)
message(STATUS "Fetching Assimp for FBX/OBJ support...")
FetchContent_Declare(
    assimp
    GIT_REPOSITORY https://github.com/assimp/assimp.git
    GIT_TAG v5.3.1
)

# Assimp build options
set(ASSIMP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(ASSIMP_BUILD_ASSIMP_TOOLS OFF CACHE BOOL "" FORCE)
set(ASSIMP_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
set(ASSIMP_INSTALL OFF CACHE BOOL "" FORCE)
set(ASSIMP_INJECT_DEBUG_POSTFIX OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(assimp)
message(STATUS "Assimp configured successfully")

# Loaders module headers (public interface)
set(LOADERS_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Loaders/Model.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Loaders/AssimpLoader.hpp
)

# Loaders module implementation
set(LOADERS_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Model.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AssimpLoader.mm
)

# Create Loaders library
add_library(PinnacleCore_Loaders STATIC
    ${LOADERS_HEADERS}
    ${LOADERS_SOURCES}
)

# Set include directories
target_include_directories(PinnacleCore_Loaders
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${assimp_SOURCE_DIR}/include
        ${assimp_BINARY_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Link dependencies
target_link_libraries(PinnacleCore_Loaders
    PUBLIC
        PinnacleCore_Core
        assimp
)

# Platform-specific settings
if(APPLE)
    # Enable ARC for Objective-C++
    set_source_files_properties(${LOADERS_SOURCES}
        PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
    )

    # Link Metal frameworks
    target_link_libraries(PinnacleCore_Loaders
        PUBLIC
            "-framework Metal"
            "-framework Foundation"
    )
endif()

# Export include directories for dependent modules
set(PINNACLE_LOADERS_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include PARENT_SCOPE)
