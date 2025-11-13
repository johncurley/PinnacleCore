# PinnacleCore - Modular Architecture

This directory contains the modular architecture of PinnacleCore, organized into independent, reusable modules with clear dependencies.

## Module Structure

```
Modules/
├── Core/               # Foundation module (no external dependencies)
├── Loaders/            # File format loaders (depends on Core)
├── Renderer/           # Metal rendering engine (depends on Core)
├── ShaderEditor/       # Shader editing system (depends on Core, Renderer)
├── Tools/              # Asset tools (depends on Core, Loaders, Renderer)
└── UI/                 # SwiftUI interface (depends on all modules)
```

## Module Descriptions

### Core
**Purpose:** Foundation components for the entire framework
**Dependencies:** Metal, MetalKit, Foundation
**Contains:**
- Scene graph management
- Camera and input handling
- Materials, meshes, textures, nodes
- Math utilities
- Core data structures

**Public Headers:**
- `Core/Camera.hpp`
- `Core/Scene.hpp`
- `Core/InputManager.hpp`
- `Core/Material.hpp`
- `Core/Mesh.hpp`
- `Core/Node.hpp`
- `Core/Texture.hpp`
- `Core/Math.hpp`

### Loaders
**Purpose:** File format import/export
**Dependencies:** Core, Assimp, tinygltf
**Contains:**
- Model loading infrastructure
- glTF/GLB loader
- FBX/OBJ loader (via Assimp)
- USDZ support

**Public Headers:**
- `Loaders/Model.hpp`
- `Loaders/AssimpLoader.hpp`

### Renderer
**Purpose:** Metal-based rendering engine
**Dependencies:** Core, Metal, MetalKit
**Contains:**
- PBR rendering pipeline
- Shader management
- Draw call execution
- Metal resource management

**Public Headers:**
- `Renderer/Renderer.hpp`

**Resources:**
- Metal shader files (.metal)

### ShaderEditor
**Purpose:** Live shader editing and compilation
**Dependencies:** Core, Renderer
**Contains:**
- Shader editor implementation
- Shader library management
- Dynamic shader compilation
- Shader source management
- Preset shader system

**Public Headers:**
- `ShaderEditor/ShaderEditor.hpp`
- `ShaderEditor/ShaderLibrary.hpp`
- `ShaderEditor/ShaderCompiler.hpp`
- `ShaderEditor/ShaderSource.hpp`

### Tools
**Purpose:** Asset pipeline tools and utilities
**Dependencies:** Core, Loaders, Renderer
**Contains:**
- Batch Converter (multi-format conversion)
- Texture Manager (analysis, optimization)
- Model Validator (format validation)
- Asset Optimizer (platform-specific optimization)
- Material Fixer (material repair tools)

**Public Headers:**
- `Tools/BatchConverter.hpp`
- `Tools/TextureManager.hpp`
- `Tools/ModelValidator.hpp`
- `Tools/AssetOptimizer.hpp`
- `Tools/MaterialFixer.hpp`

### UI
**Purpose:** SwiftUI interface and Objective-C++ bridges
**Dependencies:** All modules
**Contains:**
- SwiftUI views (ContentView, ShaderEditorView, etc.)
- Objective-C++ bridges for Swift interop
- View models
- UI utilities

**Public Headers (Bridges):**
- `UI/PinnacleBridge.h`
- `UI/CameraControlsBridge.h`
- `UI/EnvironmentControlsBridge.h`
- `UI/SceneInspectorBridge.h`
- `UI/ShaderEditorBridge.h`
- `UI/BatchConverterBridge.h`
- `UI/TextureManagerBridge.h`
- `UI/ModelValidatorBridge.h`
- `UI/AssetOptimizerBridge.h`
- `UI/MaterialFixerBridge.h`
- `UI/USDZExportBridge.h`

## Dependency Graph

```
UI
├── Tools
│   ├── Loaders
│   │   └── Core
│   └── Renderer
│       └── Core
├── ShaderEditor
│   ├── Renderer
│   │   └── Core
│   └── Core
├── Loaders
│   └── Core
├── Renderer
│   └── Core
└── Core
```

## Module Organization

Each module follows this structure:
```
ModuleName/
├── CMakeLists.txt          # Module build configuration
├── include/
│   └── ModuleName/         # Public headers
│       └── *.hpp
└── src/                    # Implementation files
    └── *.mm
```

## Building

The modular architecture is integrated into the main PinnacleCore build:

```bash
mkdir build && cd build
cmake ..
cmake --build .
```

Modules are built automatically in dependency order:
1. Core
2. Loaders & Renderer (parallel)
3. ShaderEditor
4. Tools
5. UI

## Benefits

### Modularity
- Clear separation of concerns
- Well-defined module boundaries
- Explicit dependency management

### Maintainability
- Easier to understand and navigate
- Changes isolated to specific modules
- Clear ownership of components

### Reusability
- Modules can be used independently
- Core can be reused in other projects
- Tools can be extracted as standalone utilities

### Testability
- Each module can be tested in isolation
- Mock dependencies easily
- Clear interfaces for unit testing

### Extensibility
- Easy to add new modules
- Plugin architecture foundation
- Clear extension points

## Migration Notes

This modular structure was created from the original flat source structure:
- `src/Core/` → `Modules/Core/`
- `src/Scene/` → Split between `Modules/Core/` and `Modules/Loaders/`
- `src/Renderer/` → `Modules/Renderer/`
- `src/ShaderEditor/` → `Modules/ShaderEditor/`
- `src/SwiftUI/` → `Modules/UI/` (bridges) and main app (views)

All functionality has been preserved while improving organization.
