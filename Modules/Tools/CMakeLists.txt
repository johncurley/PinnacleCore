# PinnacleCore - Tools Module
# Asset tools: Batch Converter, Texture Manager, Model Validator, Asset Optimizer, Material Fixer

cmake_minimum_required(VERSION 3.20)

project(PinnacleCore_Tools)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Tools module headers (public interface)
set(TOOLS_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Tools/BatchConverter.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Tools/TextureManager.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Tools/ModelValidator.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Tools/AssetOptimizer.hpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/Tools/MaterialFixer.hpp
)

# Tools module implementation
set(TOOLS_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/BatchConverter.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/TextureManager.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ModelValidator.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AssetOptimizer.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/src/MaterialFixer.mm
)

# Create Tools library
add_library(PinnacleCore_Tools STATIC
    ${TOOLS_HEADERS}
    ${TOOLS_SOURCES}
)

# Set include directories
target_include_directories(PinnacleCore_Tools
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Link dependencies
target_link_libraries(PinnacleCore_Tools
    PUBLIC
        PinnacleCore_Core
        PinnacleCore_Loaders
        PinnacleCore_Renderer
)

# Platform-specific settings
if(APPLE)
    # Enable ARC for Objective-C++
    set_source_files_properties(${TOOLS_SOURCES}
        PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
    )

    # Link Metal frameworks
    target_link_libraries(PinnacleCore_Tools
        PUBLIC
            "-framework Metal"
            "-framework MetalKit"
            "-framework Foundation"
    )
endif()

# Export include directories for dependent modules
set(PINNACLE_TOOLS_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include PARENT_SCOPE)
