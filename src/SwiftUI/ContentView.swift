import SwiftUI

struct ContentView: View {
    @State private var metalView = MetalView()
    @State private var showShaderEditor = false
    @State private var showSceneInspector = true
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
