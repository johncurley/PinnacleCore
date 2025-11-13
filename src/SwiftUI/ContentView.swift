import SwiftUI

struct ContentView: View {
    @State private var metalView = MetalView()
    @State private var showShaderEditor = false
    @StateObject private var shaderEditorViewModel: ShaderEditorViewModel

    init() {
        let view = MetalView()
        _metalView = State(initialValue: view)

        // Get renderer from metal view for shader editor
        let renderer = view.bridge.getRenderer()
        _shaderEditorViewModel = StateObject(wrappedValue: ShaderEditorViewModel(renderer: renderer))
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

                // Main content
                if showShaderEditor {
                    HSplitView {
                        // Left: 3D Viewer
                        metalView
                            .frame(minWidth: 400)

                        // Right: Shader Editor
                        ShaderEditorView(viewModel: shaderEditorViewModel)
                            .frame(minWidth: 600)
                    }
                } else {
                    // Full-width 3D viewer
                    metalView
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
