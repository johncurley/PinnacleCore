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
    @StateObject private var shaderEditorViewModel: ShaderEditorViewModel
    @StateObject private var sceneInspectorViewModel: SceneInspectorViewModel

    init() {
        let view = MetalView()
        _metalView = State(initialValue: view)

        // Get renderer from metal view
        let renderer = view.bridge.getRenderer()
        _shaderEditorViewModel = StateObject(wrappedValue: ShaderEditorViewModel(renderer: renderer))
        _sceneInspectorViewModel = StateObject(wrappedValue: SceneInspectorViewModel(renderer: renderer))
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
