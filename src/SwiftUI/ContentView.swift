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

                    // Center: 3D Viewer
                    metalView
                        .frame(minWidth: 400)

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
