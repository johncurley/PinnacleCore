import SwiftUI

// View mode options for the PBR viewer
enum ViewMode: String, CaseIterable, Identifiable {
    case pbr = "PBR"
    case unlit = "Unlit"
    case wireframe = "Wireframe"
    case normals = "Normals"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .pbr: return "cube.fill"
        case .unlit: return "circle"
        case .wireframe: return "square.grid.3x3"
        case .normals: return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    var presetName: String? {
        switch self {
        case .pbr: return nil  // Default shader
        case .unlit: return "Unlit"
        case .wireframe: return "Wireframe"
        case .normals: return "Normal Visualizer"
        }
    }
}

struct ContentView: View {
    @State private var metalView = MetalView()
    @State private var showShaderEditor = false
    @State private var showSceneInspector = true
    @State private var selectedViewMode: ViewMode = .pbr
    @State private var showEnvironmentPanel = false
    @State private var showFilePicker = false
    @State private var currentModelPath: String = "Models/Box/glTF/Box.gltf"
    @State private var currentModelName: String = "Box.gltf"
    @State private var recentFiles: [String] = []
    @State private var lastExportedUSDZ: String? = nil
    @State private var showExportError: Bool = false
    @State private var exportErrorMessage: String = ""
    @State private var showMaterialCreator: Bool = false
    @State private var showBatchConverter: Bool = false
    @State private var showTextureManager: Bool = false
    @State private var showModelValidator: Bool = false
    @State private var showAssetOptimizer: Bool = false
    @StateObject private var shaderEditorViewModel: ShaderEditorViewModel
    @StateObject private var sceneInspectorViewModel: SceneInspectorViewModel

    private var cameraControlsBridge: CameraControlsBridge?
    private var environmentControlsBridge: EnvironmentControlsBridge?

    init() {
        let view = MetalView()
        _metalView = State(initialValue: view)

        // Get renderer from metal view
        let renderer = view.bridge.getRenderer()
        _shaderEditorViewModel = StateObject(wrappedValue: ShaderEditorViewModel(renderer: renderer))
        _sceneInspectorViewModel = StateObject(wrappedValue: SceneInspectorViewModel(renderer: renderer))

        // Create control bridges
        if let renderer = renderer {
            cameraControlsBridge = CameraControlsBridge(renderer: renderer)
            environmentControlsBridge = EnvironmentControlsBridge(renderer: renderer)
        }

        // Load recent files from UserDefaults
        if let saved = UserDefaults.standard.array(forKey: "RecentFiles") as? [String] {
            _recentFiles = State(initialValue: saved)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("PinnacleCore")
                        .font(.title2)
                        .bold()

                    Spacer()

                    // Model loading menu
                    Menu {
                        Button(action: openFilePicker) {
                            Label("Open Model...", systemImage: "doc.badge.plus")
                        }
                        .keyboardShortcut("o", modifiers: [.command])

                        Divider()

                        // USDZ Export & AR
                        Button(action: exportToUSDZ) {
                            Label("Export to USDZ...", systemImage: "cube.transparent")
                        }
                        .disabled(currentModelPath.isEmpty)

                        if let usdzPath = lastExportedUSDZ {
                            Button(action: {
                                USDZExportBridge.openInARQuickLook(usdzPath)
                            }) {
                                Label("Preview in AR Quick Look", systemImage: "arkit")
                            }
                        }

                        Divider()

                        // Material Tools
                        Button(action: {
                            showMaterialCreator = true
                        }) {
                            Label("Material Creator...", systemImage: "wand.and.stars")
                        }

                        Button(action: {
                            showBatchConverter = true
                        }) {
                            Label("Batch Converter...", systemImage: "square.stack.3d.up")
                        }

                        Button(action: {
                            showTextureManager = true
                        }) {
                            Label("Texture Manager...", systemImage: "photo.on.rectangle")
                        }

                        Button(action: {
                            showModelValidator = true
                        }) {
                            Label("Model Validator...", systemImage: "checkmark.shield")
                        }

                        Divider()

                        Button(action: {
                            showAssetOptimizer = true
                        }) {
                            Label("Asset Optimizer...", systemImage: "wand.and.stars.inverse")
                        }

                        if !recentFiles.isEmpty {
                            Divider()

                            Menu("Recent Files") {
                                ForEach(recentFiles.prefix(5), id: \.self) { path in
                                    Button(action: {
                                        loadModel(path: path)
                                    }) {
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                    }
                                }

                                if recentFiles.count > 0 {
                                    Divider()
                                    Button("Clear Recent Files") {
                                        recentFiles = []
                                        UserDefaults.standard.set([], forKey: "RecentFiles")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cube.box")
                            Text(currentModelName)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .help("Load Model")

                    Spacer()

                    // View Mode Picker
                    HStack(spacing: 8) {
                        Text("View:")
                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedViewMode) {
                            ForEach(ViewMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: mode.iconName)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                        .onChange(of: selectedViewMode) { newMode in
                            applyViewMode(newMode)
                        }
                    }

                    Spacer()

                    // Camera & Environment Controls
                    HStack(spacing: 4) {
                        Button(action: {
                            cameraControlsBridge?.resetCamera()
                        }) {
                            Image(systemName: "camera")
                                .help("Reset Camera")
                        }
                        .buttonStyle(.borderless)

                        Button(action: {
                            cameraControlsBridge?.fitToModel()
                        }) {
                            Image(systemName: "viewfinder")
                                .help("Fit to Model")
                        }
                        .buttonStyle(.borderless)

                        Divider()
                            .frame(height: 16)

                        Button(action: {
                            showEnvironmentPanel.toggle()
                        }) {
                            Image(systemName: "light.max")
                                .help("Lighting & Environment")
                        }
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showEnvironmentPanel, arrowEdge: .bottom) {
                            EnvironmentControlsPanel(bridge: environmentControlsBridge)
                                .frame(width: 300)
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()

                    Button(action: { showSceneInspector.toggle() }) {
                        Label(showSceneInspector ? "Hide Inspector" : "Show Inspector",
                              systemImage: "sidebar.left")
                    }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                    .help("Toggle Scene Inspector (⌘⌥I)")

                    Button(action: { showShaderEditor.toggle() }) {
                        Label(showShaderEditor ? "Hide Shader Editor" : "Show Shader Editor",
                              systemImage: "chevron.left.slash.chevron.right")
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .help("Toggle Shader Editor (⌘⇧E)")
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Main content - Three-panel layout
                HSplitView {
                    // Left: Scene Inspector (optional)
                    if showSceneInspector {
                        SceneInspectorView(viewModel: sceneInspectorViewModel)
                            .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
                    }

                    // Center: 3D Viewer with drag & drop
                    ZStack {
                        metalView
                            .frame(minWidth: 400)

                        // Drag & drop overlay
                        Color.clear
                            .contentShape(Rectangle())
                            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                                handleDrop(providers: providers)
                            }
                    }

                    // Right: Shader Editor (optional)
                    if showShaderEditor {
                        ShaderEditorView(viewModel: shaderEditorViewModel)
                            .frame(minWidth: 600, idealWidth: 700)
                    }
                }
            }
        }
        .navigationTitle("PinnacleCore")
        .onAppear {
            // Load a sample model. You might need to adjust the path.
            // For now, let's assume a model exists at this relative path.
            metalView.loadModel(filename: "Models/Box/glTF/Box.gltf")
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
        .sheet(isPresented: $showMaterialCreator) {
            MaterialCreatorView()
        }
        .sheet(isPresented: $showBatchConverter) {
            BatchConverterView(renderer: metalView.bridge.getRenderer())
        }
        .sheet(isPresented: $showTextureManager) {
            TextureManagerView(renderer: metalView.bridge.getRenderer())
        }
        .sheet(isPresented: $showModelValidator) {
            ModelValidatorView(renderer: metalView.bridge.getRenderer())
        }
        .sheet(isPresented: $showAssetOptimizer) {
            AssetOptimizerView(renderer: metalView.bridge.getRenderer())
        }
    }

    // MARK: - View Mode Management

    /// Apply the selected view mode by loading and applying the appropriate shader preset
    private func applyViewMode(_ mode: ViewMode) {
        if let presetName = mode.presetName {
            // Load and apply preset shader
            shaderEditorViewModel.loadPreset(presetName)
            shaderEditorViewModel.applyShader()
        } else {
            // Reset to default PBR shader
            shaderEditorViewModel.resetToDefaults()
        }
    }

    // MARK: - Model Loading

    /// Open file picker to select a 3D model file
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .init(filenameExtension: "gltf")!,
            .init(filenameExtension: "glb")!,
            .init(filenameExtension: "usdz")!,
            .init(filenameExtension: "fbx")!,
            .init(filenameExtension: "obj")!
        ]
        panel.message = "Select a 3D model file (glTF, GLB, USDZ, FBX, or OBJ)"

        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.pathExtension.lowercased()
            if ext == "usdz" {
                // USDZ files can be previewed in AR Quick Look but not loaded in the viewer
                lastExportedUSDZ = url.path
                USDZExportBridge.openInARQuickLook(url.path)
            } else {
                loadModel(path: url.path)
            }
        }
    }

    /// Load a model from the given file path
    private func loadModel(path: String) {
        // Update current model info
        currentModelPath = path
        currentModelName = URL(fileURLWithPath: path).lastPathComponent

        // Load the model
        metalView.loadModel(filename: path)

        // Add to recent files
        addToRecentFiles(path: path)

        // Refresh scene inspector
        sceneInspectorViewModel.refresh()

        // Fit camera to new model
        cameraControlsBridge?.fitToModel()
    }

    /// Add file path to recent files list
    private func addToRecentFiles(path: String) {
        // Remove if already exists
        recentFiles.removeAll { $0 == path }

        // Add to beginning
        recentFiles.insert(path, at: 0)

        // Keep only last 10
        if recentFiles.count > 10 {
            recentFiles = Array(recentFiles.prefix(10))
        }

        // Save to UserDefaults
        UserDefaults.standard.set(recentFiles, forKey: "RecentFiles")
    }

    /// Handle drag and drop of model files
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }

            // Check if it's a supported file type
            let ext = url.pathExtension.lowercased()
            guard ext == "gltf" || ext == "glb" || ext == "usdz" || ext == "fbx" || ext == "obj" else { return }

            DispatchQueue.main.async {
                if ext == "usdz" {
                    // USDZ files can be previewed in AR Quick Look
                    lastExportedUSDZ = url.path
                    USDZExportBridge.openInARQuickLook(url.path)
                } else {
                    loadModel(path: url.path)
                }
            }
        }

        return true
    }

    // MARK: - USDZ Export

    /// Export current model to USDZ format
    private func exportToUSDZ() {
        // Check if converter is available
        if !USDZExportBridge.isUSDZConverterAvailable() {
            exportErrorMessage = "USDZ converter not found. Please install Xcode Command Line Tools:\nxcode-select --install"
            showExportError = true
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: "usdz")!]
        savePanel.nameFieldStringValue = URL(fileURLWithPath: currentModelPath).deletingPathExtension().lastPathComponent + ".usdz"
        savePanel.message = "Export model to USDZ for AR Quick Look"

        if savePanel.runModal() == .OK, let outputURL = savePanel.url {
            // Perform conversion in background
            DispatchQueue.global(qos: .userInitiated).async {
                let result = USDZExportBridge.convert(toUSDZ: currentModelPath, outputPath: outputURL.path)

                DispatchQueue.main.async {
                    if result.success {
                        lastExportedUSDZ = result.outputPath
                        // Optionally show success message or auto-open in AR Quick Look
                        print("✓ Successfully exported to USDZ: \(result.outputPath ?? "")")
                    } else {
                        exportErrorMessage = result.errorMessage ?? "Unknown error during USDZ conversion"
                        showExportError = true
                    }
                }
            }
        }
    }
}

// MARK: - Environment Controls Panel

struct EnvironmentControlsPanel: View {
    let bridge: EnvironmentControlsBridge?

    @State private var lightIntensity: Double = 1.0
    @State private var lightColor: Color = .white
    @State private var backgroundColor: Color = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lighting & Environment")
                .font(.headline)
                .padding(.bottom, 4)

            // Light Intensity
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Light Intensity")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2f", lightIntensity))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                Slider(value: $lightIntensity, in: 0...3) { editing in
                    if !editing {
                        bridge?.setLightIntensity(Float(lightIntensity))
                    }
                }
            }

            Divider()

            // Light Color
            VStack(alignment: .leading, spacing: 4) {
                Text("Light Color")
                    .font(.subheadline)

                ColorPicker("", selection: $lightColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: lightColor) { newColor in
                        let components = NSColor(newColor).usingColorSpace(.deviceRGB)!
                        let r = Float(components.redComponent)
                        let g = Float(components.greenComponent)
                        let b = Float(components.blueComponent)
                        bridge?.setLightColor(simd_make_float3(r, g, b))
                    }
            }

            Divider()

            // Background Color
            VStack(alignment: .leading, spacing: 4) {
                Text("Background Color")
                    .font(.subheadline)

                ColorPicker("", selection: $backgroundColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: backgroundColor) { newColor in
                        let components = NSColor(newColor).usingColorSpace(.deviceRGB)!
                        let r = Float(components.redComponent)
                        let g = Float(components.greenComponent)
                        let b = Float(components.blueComponent)
                        bridge?.setBackgroundColor(simd_make_float4(r, g, b, 1.0))
                    }
            }

            Divider()

            // Light Direction (simplified - could be expanded)
            VStack(alignment: .leading, spacing: 4) {
                Text("Light Direction")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Automatic (top-right)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            // Load current values from bridge
            if let info = bridge?.getLightingInfo() {
                lightIntensity = Double(info.intensity)

                let r = Double(info.color.x)
                let g = Double(info.color.y)
                let b = Double(info.color.z)
                lightColor = Color(red: r, green: g, blue: b)
            }

            if let bgColor = bridge?.getBackgroundColor() {
                let r = Double(bgColor.x)
                let g = Double(bgColor.y)
                let b = Double(bgColor.z)
                backgroundColor = Color(red: r, green: g, blue: b)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
