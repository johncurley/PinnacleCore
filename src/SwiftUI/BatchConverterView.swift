import SwiftUI

struct BatchConverterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BatchConverterViewModel

    init(renderer: UnsafeMutableRawPointer?) {
        _viewModel = StateObject(wrappedValue: BatchConverterViewModel(renderer: renderer))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Batch Converter")
                    .font(.title2)
                    .bold()

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .disabled(viewModel.isProcessing)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // File Selection
                    FileSelectionSection(viewModel: viewModel)

                    Divider()

                    // Conversion Options
                    ConversionOptionsSection(viewModel: viewModel)

                    Divider()

                    // Material Options
                    MaterialOptionsSection(viewModel: viewModel)

                    Divider()

                    // Output Options
                    OutputOptionsSection(viewModel: viewModel)

                    // Progress Section (only shown during processing)
                    if viewModel.isProcessing || viewModel.conversionComplete {
                        Divider()
                        ProgressSection(viewModel: viewModel)
                    }

                    // Results Section (only shown after completion)
                    if viewModel.conversionComplete {
                        Divider()
                        ResultsSection(viewModel: viewModel)
                    }
                }
                .padding()
            }

            Divider()

            // Footer with actions
            HStack {
                if viewModel.conversionComplete {
                    Button("Reset") {
                        viewModel.reset()
                    }

                    Button("Export Log...") {
                        viewModel.exportLog()
                    }
                    .disabled(viewModel.batchResult == nil)
                }

                Spacer()

                Text("\(viewModel.selectedFiles.count) file\(viewModel.selectedFiles.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isProcessing {
                    Button("Cancel") {
                        viewModel.cancelConversion()
                    }
                    .keyboardShortcut(.escape)
                } else {
                    Button("Start Conversion") {
                        viewModel.startConversion()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedFiles.isEmpty)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 800, height: 700)
    }
}

// MARK: - File Selection Section

struct FileSelectionSection: View {
    @ObservedObject var viewModel: BatchConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input Files")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Add Files...") {
                    viewModel.selectFiles()
                }
                .disabled(viewModel.isProcessing)

                Button("Add Folder...") {
                    viewModel.selectFolder()
                }
                .disabled(viewModel.isProcessing)

                Toggle("Include Subfolders", isOn: $viewModel.includeSubfolders)
                    .disabled(viewModel.isProcessing)

                Spacer()

                if !viewModel.selectedFiles.isEmpty {
                    Button("Clear All") {
                        viewModel.selectedFiles.removeAll()
                    }
                    .disabled(viewModel.isProcessing)
                }
            }

            // File list
            if !viewModel.selectedFiles.isEmpty {
                List {
                    ForEach(Array(viewModel.selectedFiles.enumerated()), id: \.offset) { index, filePath in
                        HStack {
                            Image(systemName: "doc")
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(URL(fileURLWithPath: filePath).lastPathComponent)
                                    .font(.caption)

                                Text(filePath)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                viewModel.selectedFiles.remove(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isProcessing)
                        }
                    }
                }
                .frame(height: 150)
            }
        }
    }
}

// MARK: - Conversion Options Section

struct ConversionOptionsSection: View {
    @ObservedObject var viewModel: BatchConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion Options")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Format")
                        .font(.subheadline)

                    Picker("", selection: $viewModel.targetFormat) {
                        Text("glTF (.gltf)").tag(ConversionFormat.GLTF)
                        Text("GLB (.glb)").tag(ConversionFormat.GLB)
                        Text("USDZ (.usdz)").tag(ConversionFormat.USDZ)
                        Text("OBJ (.obj) - Coming Soon").tag(ConversionFormat.OBJ).disabled(true)
                        Text("FBX (.fbx) - Coming Soon").tag(ConversionFormat.FBX).disabled(true)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                    .disabled(viewModel.isProcessing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Engine")
                        .font(.subheadline)

                    Picker("", selection: $viewModel.targetEngine) {
                        Text("Generic PBR").tag(TargetEngine.genericPBR)
                        Text("Unity Built-in").tag(TargetEngine.unityBuiltIn)
                        Text("Unity URP").tag(TargetEngine.unityURP)
                        Text("Unity HDRP").tag(TargetEngine.unityHDRP)
                        Text("Unreal Engine").tag(TargetEngine.unrealEngine)
                        Text("Godot").tag(TargetEngine.godot)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                    .disabled(viewModel.isProcessing)
                }
            }

            // Additional options
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Embed Textures (for glTF/GLB)", isOn: $viewModel.embedTextures)
                    .disabled(viewModel.isProcessing)

                Toggle("Convert Coordinate System", isOn: $viewModel.convertCoordinates)
                    .disabled(viewModel.isProcessing)

                if viewModel.convertCoordinates {
                    HStack {
                        Text("Target:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $viewModel.targetCoordinateSystem) {
                            Text("Y-up Right-handed (glTF)").tag(CoordinateSystem.yUpRightHanded)
                            Text("Y-up Left-handed (Unity)").tag(CoordinateSystem.yUpLeftHanded)
                            Text("Z-up Right-handed (Blender)").tag(CoordinateSystem.zUpRightHanded)
                            Text("Z-up Left-handed (Unreal)").tag(CoordinateSystem.zUpLeftHanded)
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.isProcessing)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
}

// MARK: - Material Options Section

struct MaterialOptionsSection: View {
    @ObservedObject var viewModel: BatchConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Material Options")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Auto-fix Materials", isOn: $viewModel.fixMaterials)
                    .disabled(viewModel.isProcessing)

                Toggle("Validate Materials", isOn: $viewModel.validateMaterials)
                    .disabled(viewModel.isProcessing)

                Toggle("Fix Texture Paths", isOn: $viewModel.fixTexturePaths)
                    .disabled(viewModel.isProcessing)

                Toggle("Copy Textures to Output", isOn: $viewModel.copyTextures)
                    .disabled(viewModel.isProcessing)

                Toggle("Convert Normal Maps", isOn: $viewModel.convertNormalMaps)
                    .disabled(viewModel.isProcessing)

                if viewModel.convertNormalMaps {
                    HStack {
                        Text("Format:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $viewModel.normalMapFormat) {
                            Text("OpenGL (glTF, Unity)").tag(NormalMapFormat.openGL)
                            Text("DirectX (Unreal)").tag(NormalMapFormat.directX)
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.isProcessing)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
}

// MARK: - Output Options Section

struct OutputOptionsSection: View {
    @ObservedObject var viewModel: BatchConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Options")
                .font(.headline)

            HStack {
                Text("Output Directory:")
                    .font(.subheadline)

                TextField("Same as input", text: Binding(
                    get: { viewModel.outputDirectory ?? "" },
                    set: { viewModel.outputDirectory = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isProcessing)

                Button("Browse...") {
                    viewModel.selectOutputDirectory()
                }
                .disabled(viewModel.isProcessing)
            }

            HStack {
                Text("Filename Suffix:")
                    .font(.subheadline)

                TextField("_converted", text: $viewModel.filenameSuffix)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .disabled(viewModel.isProcessing)

                Text("(e.g., model.gltf → model_converted.usdz)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("Overwrite Existing Files", isOn: $viewModel.overwriteExisting)
                .disabled(viewModel.isProcessing)
        }
    }
}

// MARK: - Progress Section

struct ProgressSection: View {
    @ObservedObject var viewModel: BatchConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)

            if let currentFile = viewModel.currentFileName {
                Text("Processing: \(currentFile)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                ProgressView(value: viewModel.progress, total: 1.0)
                    .progressViewStyle(.linear)

                Text("\(viewModel.currentFileIndex)/\(viewModel.totalFiles)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }
}

// MARK: - Results Section

struct ResultsSection: View {
    @ObservedObject var viewModel: BatchConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline)

            if let result = viewModel.batchResult {
                // Summary
                HStack(spacing: 20) {
                    ResultStatistic(label: "Total", value: result.totalFiles, color: .primary)
                    ResultStatistic(label: "Success", value: result.successCount, color: .green)
                    ResultStatistic(label: "Warnings", value: result.warningCount, color: .orange)
                    ResultStatistic(label: "Failed", value: result.failureCount, color: .red)
                    ResultStatistic(label: "Skipped", value: result.skippedCount, color: .secondary)
                }
                .padding(.vertical, 8)

                Text("Total Time: \(String(format: "%.2f", result.totalTime)) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // File results list
                if !result.results.isEmpty {
                    List {
                        ForEach(Array(result.results.enumerated()), id: \.offset) { _, fileResult in
                            FileResultRow(result: fileResult)
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }
}

struct ResultStatistic: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .bold()
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FileResultRow: View {
    let result: FileConversionResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Status icon
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: result.inputPath).lastPathComponent)
                    .font(.caption)
                    .bold()

                if !result.warnings.isEmpty {
                    Text("\(result.warnings.count) warning(s)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                if let error = result.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                Text(String(format: "%.2fs", result.processingTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var statusIcon: String {
        switch result.status {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .skipped:
            return "minus.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .success:
            return .green
        case .warning:
            return .orange
        case .failed:
            return .red
        case .skipped:
            return .secondary
        @unknown default:
            return .secondary
        }
    }
}

// MARK: - View Model

class BatchConverterViewModel: ObservableObject {
    private let renderer: UnsafeMutableRawPointer?
    private var bridge: BatchConverterBridge

    // Input files
    @Published var selectedFiles: [String] = []
    @Published var includeSubfolders: Bool = false

    // Conversion options
    @Published var targetFormat: ConversionFormat = .USDZ
    @Published var targetEngine: TargetEngine = .genericPBR
    @Published var embedTextures: Bool = true
    @Published var convertCoordinates: Bool = false
    @Published var targetCoordinateSystem: CoordinateSystem = .yUpRightHanded

    // Material options
    @Published var fixMaterials: Bool = true
    @Published var validateMaterials: Bool = true
    @Published var fixTexturePaths: Bool = true
    @Published var copyTextures: Bool = false
    @Published var convertNormalMaps: Bool = false
    @Published var normalMapFormat: NormalMapFormat = .openGL

    // Output options
    @Published var outputDirectory: String? = nil
    @Published var filenameSuffix: String = "_converted"
    @Published var overwriteExisting: Bool = false

    // Progress
    @Published var isProcessing: Bool = false
    @Published var conversionComplete: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentFileIndex: Int = 0
    @Published var totalFiles: Int = 0
    @Published var currentFileName: String? = nil

    // Results
    @Published var batchResult: BatchConversionResult? = nil

    init(renderer: UnsafeMutableRawPointer?) {
        self.renderer = renderer
        self.bridge = BatchConverterBridge(renderer: renderer)
    }

    func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .init(filenameExtension: "gltf")!,
            .init(filenameExtension: "glb")!,
            .init(filenameExtension: "usdz")!,
            .init(filenameExtension: "fbx")!,
            .init(filenameExtension: "obj")!
        ]

        if panel.runModal() == .OK {
            let newFiles = panel.urls.map { $0.path }
            selectedFiles.append(contentsOf: newFiles)
            selectedFiles = Array(Set(selectedFiles)) // Remove duplicates
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let folderURL = panel.url {
            let extensions = BatchConverterBridge.supportedInputExtensions() as! [String]
            let files = BatchConverterBridge.discoverFiles(
                inDirectory: folderURL.path,
                recursive: includeSubfolders,
                extensions: extensions
            ) as! [String]

            selectedFiles.append(contentsOf: files)
            selectedFiles = Array(Set(selectedFiles)) // Remove duplicates
        }
    }

    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let folderURL = panel.url {
            outputDirectory = folderURL.path
        }
    }

    func startConversion() {
        guard !selectedFiles.isEmpty else { return }

        isProcessing = true
        conversionComplete = false
        progress = 0.0
        currentFileIndex = 0
        totalFiles = selectedFiles.count
        currentFileName = nil
        batchResult = nil

        // Create options
        let options = BatchConversionOptions()
        options.targetFormat = targetFormat
        options.embedTextures = embedTextures
        options.convertCoordinates = convertCoordinates
        options.targetCoordinateSystem = targetCoordinateSystem
        options.fixMaterials = fixMaterials
        options.validateMaterials = validateMaterials
        options.targetEngine = targetEngine
        options.convertNormalMaps = convertNormalMaps
        options.normalMapFormat = normalMapFormat
        options.fixTexturePaths = fixTexturePaths
        options.copyTextures = copyTextures
        options.outputDirectory = outputDirectory
        options.filenameSuffix = filenameSuffix
        options.overwriteExisting = overwriteExisting

        // Run conversion on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.bridge.convert(
                self.selectedFiles as NSArray,
                options: options
            ) { current, total, filename in
                DispatchQueue.main.async {
                    self.currentFileIndex = Int(current)
                    self.totalFiles = Int(total)
                    self.currentFileName = filename as String
                    self.progress = Double(current) / Double(total)
                }
            }

            DispatchQueue.main.async {
                self.batchResult = result as? BatchConversionResult
                self.isProcessing = false
                self.conversionComplete = true
                self.progress = 1.0
            }
        }
    }

    func cancelConversion() {
        // TODO: Implement cancellation
        isProcessing = false
    }

    func reset() {
        selectedFiles.removeAll()
        conversionComplete = false
        progress = 0.0
        currentFileIndex = 0
        totalFiles = 0
        currentFileName = nil
        batchResult = nil
    }

    func exportLog() {
        guard let result = batchResult else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "txt")!]
        panel.nameFieldStringValue = "conversion_log.txt"

        if panel.runModal() == .OK, let url = panel.url {
            _ = BatchConverterBridge.exportResults(toLog: result, filePath: url.path)
        }
    }
}

// MARK: - Preview

struct BatchConverterView_Previews: PreviewProvider {
    static var previews: some View {
        // Note: This won't work without a real renderer
        Text("Batch Converter Preview")
    }
}
