import SwiftUI

struct ShaderEditorView: View {
    @ObservedObject var viewModel: ShaderEditorViewModel
    @State private var showingPresets = false
    @State private var showingFileImporter = false
    @State private var showingFileExporter = false
    @State private var fileImporterIsVertex = false

    var body: some View {
        HSplitView {
            // Left side: Code editors
            VStack(spacing: 0) {
                // Tab selector
                Picker("Shader", selection: $viewModel.selectedShaderTab) {
                    Text("Fragment Shader").tag(ShaderEditorViewModel.ShaderTab.fragment)
                    Text("Vertex Shader").tag(ShaderEditorViewModel.ShaderTab.vertex)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                // Editor
                if viewModel.selectedShaderTab == .fragment {
                    CodeEditorView(
                        text: $viewModel.fragmentShaderSource,
                        language: "metal"
                    )
                } else {
                    CodeEditorView(
                        text: $viewModel.vertexShaderSource,
                        language: "metal"
                    )
                }

                // Toolbar
                HStack {
                    // Status
                    HStack(spacing: 4) {
                        if viewModel.isCompiling {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        } else if viewModel.compilationSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if !viewModel.errors.isEmpty {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }

                        Text(viewModel.statusMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Auto-compile toggle
                    Toggle("Auto", isOn: $viewModel.autoCompile)
                        .toggleStyle(SwitchToggleStyle())
                        .help("Auto-compile on source change")

                    Divider()
                        .frame(height: 20)

                    // Preset button
                    Button(action: { showingPresets.toggle() }) {
                        Label("Presets", systemImage: "star")
                    }
                    .popover(isPresented: $showingPresets) {
                        PresetsPopover(viewModel: viewModel)
                    }

                    // Compile button
                    Button(action: { viewModel.compile() }) {
                        Label("Compile", systemImage: "hammer")
                    }
                    .keyboardShortcut("b", modifiers: [.command])
                    .help("Compile shader (⌘B)")

                    // Apply button
                    Button(action: { viewModel.applyShader() }) {
                        Label("Apply", systemImage: "arrow.up.circle.fill")
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Hot-reload shader (⌘R)")
                    .disabled(viewModel.isCompiling)

                    // Reset button
                    Button(action: { viewModel.resetToDefaults() }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .help("Reset to default shader")
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor))
            }

            // Right side: Errors and info
            VStack(spacing: 0) {
                Text("Compilation Errors")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))

                if viewModel.errors.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No errors")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ErrorListView(
                        errors: viewModel.errors,
                        errorLines: viewModel.errorLines
                    )
                }

                Divider()

                // Info panel
                VStack(alignment: .leading, spacing: 8) {
                    Text("Info")
                        .font(.headline)

                    if viewModel.compilationTime > 0 {
                        HStack {
                            Text("Compilation Time:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.3fs", viewModel.compilationTime))
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    HStack {
                        Text("Error Count:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.errors.count)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(viewModel.errors.isEmpty ? .green : .red)
                    }
                }
                .padding()
                .frame(height: 120)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 250, idealWidth: 300)
        }
    }
}

// MARK: - Code Editor View

struct CodeEditorView: View {
    @Binding var text: String
    let language: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .padding(4)
            .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Error List View

struct ErrorListView: View {
    let errors: [String]
    let errorLines: [Int]

    var body: some View {
        List {
            ForEach(Array(errors.enumerated()), id: \.offset) { index, error in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .frame(width: 16)

                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Presets Popover

struct PresetsPopover: View {
    @ObservedObject var viewModel: ShaderEditorViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shader Presets")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(viewModel.availablePresets(), id: \.self) { preset in
                Button(action: {
                    viewModel.loadPreset(preset)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: presetIcon(for: preset))
                        Text(preset)
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            }
        }
        .padding()
        .frame(width: 250)
    }

    private func presetIcon(for preset: String) -> String {
        switch preset {
        case "Unlit": return "sun.max"
        case "Wireframe": return "scribble.variable"
        case "Normal Visualizer": return "arrow.up.and.down.and.arrow.left.and.right"
        default: return "star"
        }
    }
}

// MARK: - Preview

struct ShaderEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ShaderEditorView(viewModel: ShaderEditorViewModel(renderer: nil))
            .frame(width: 1000, height: 600)
    }
}
