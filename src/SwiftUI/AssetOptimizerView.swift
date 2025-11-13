import SwiftUI

struct AssetOptimizerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssetOptimizerViewModel

    init(renderer: PinnacleMetalRenderer) {
        _viewModel = StateObject(wrappedValue: AssetOptimizerViewModel(renderer: renderer))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Asset Optimizer")
                    .font(.title2)
                    .bold()

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if viewModel.isOptimizing {
                // Optimizing state
                OptimizingView(viewModel: viewModel)
            } else if let result = viewModel.optimizationResult {
                // Results view
                ResultsView(result: result, viewModel: viewModel)
            } else {
                // Configuration view
                ConfigurationView(viewModel: viewModel)
            }

            Divider()

            // Footer
            HStack {
                if let result = viewModel.optimizationResult {
                    Button("Export Report...") {
                        viewModel.exportReport()
                    }

                    Button("Reset") {
                        viewModel.reset()
                    }

                    Spacer()
                } else {
                    Spacer()

                    if viewModel.isOptimizing {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Optimizing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Optimize") {
                            viewModel.optimize()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canOptimize)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 900, height: 750)
        .onAppear {
            viewModel.analyze()
        }
    }
}

// MARK: - Configuration View

struct ConfigurationView: View {
    @ObservedObject var viewModel: AssetOptimizerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Profile Selection
                ProfileSelectionSection(viewModel: viewModel)

                // Preview
                if let preview = viewModel.preview {
                    OptimizationPreviewSection(preview: preview)
                }

                // Settings
                if viewModel.showCustomSettings {
                    OptimizationSettingsSection(viewModel: viewModel)
                }
            }
            .padding()
        }
    }
}

// MARK: - Profile Selection

struct ProfileSelectionSection: View {
    @ObservedObject var viewModel: AssetOptimizerViewModel

    let profiles: [(OptimizationProfile, String, String, Color)] = [
        (.mobile, "Mobile", "iOS/Android - Aggressive optimization for best performance", .green),
        (.desktop, "Desktop", "Windows/Mac - Balanced quality and performance", .blue),
        (.VR, "VR", "Quest/PSVR - Optimized for 90fps stereo rendering", .purple),
        (.AR, "AR (USDZ)", "Apple AR Quick Look - iOS/macOS AR compatibility", .orange),
        (.web, "Web", "glTF Viewer - Optimized for download size and streaming", .cyan),
        (.console, "Console", "PS5/Xbox - High quality with optimizations", .red)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Profile")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(profiles, id: \.0) { profile in
                    ProfileCard(
                        name: profile.1,
                        description: profile.2,
                        color: profile.3,
                        isSelected: viewModel.selectedProfile == profile.0,
                        action: {
                            viewModel.selectProfile(profile.0)
                        }
                    )
                }
            }

            // Custom profile toggle
            Toggle("Custom Settings", isOn: $viewModel.showCustomSettings)
                .toggleStyle(.switch)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ProfileCard: View {
    let name: String
    let description: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(color)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text(name)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(isSelected ? color.opacity(0.15) : Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch name {
        case "Mobile": return "iphone"
        case "Desktop": return "desktopcomputer"
        case "VR": return "visionpro"
        case "AR (USDZ)": return "arkit"
        case "Web": return "globe"
        case "Console": return "gamecontroller"
        default: return "gearshape"
        }
    }
}

// MARK: - Optimization Preview

struct OptimizationPreviewSection: View {
    let preview: OptimizationPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Predicted Results")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("~\(String(format: "%.1f", preview.estimatedTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Savings Summary
            SavingsComparisonView(stats: preview.predictedStatistics as! OptimizationStatistics)

            // Planned Optimizations
            VStack(alignment: .leading, spacing: 8) {
                Text("Planned Optimizations:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(Array((preview.plannedOptimizations as! [String]).enumerated()), id: \.offset) { _, opt in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        Text(opt)
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Savings Comparison

struct SavingsComparisonView: View {
    let stats: OptimizationStatistics

    var body: some View {
        VStack(spacing: 12) {
            SavingsMetricRow(
                icon: "cube",
                label: "Vertices",
                before: Int(stats.vertexCountBefore),
                after: Int(stats.vertexCountAfter),
                percent: stats.vertexReductionPercent
            )

            SavingsMetricRow(
                icon: "triangle",
                label: "Triangles",
                before: Int(stats.triangleCountBefore),
                after: Int(stats.triangleCountAfter),
                percent: stats.triangleReductionPercent
            )

            SavingsMetricRow(
                icon: "photo",
                label: "Texture Size",
                before: Int(stats.textureSizeBefore / (1024 * 1024)),
                after: Int(stats.textureSizeAfter / (1024 * 1024)),
                percent: stats.textureSavingsPercent,
                unit: "MB"
            )

            SavingsMetricRow(
                icon: "arrow.triangle.branch",
                label: "Draw Calls",
                before: Int(stats.drawCallsBefore),
                after: Int(stats.drawCallsAfter),
                percent: stats.drawCallReductionPercent
            )

            Divider()

            // Total savings highlight
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total File Size Reduction")
                        .font(.subheadline)
                        .bold()

                    Text("\(formatBytes(UInt64(stats.totalSizeBefore))) → \(formatBytes(UInt64(stats.totalSizeAfter)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("-\(String(format: "%.1f", stats.totalSavingsPercent))%")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct SavingsMetricRow: View {
    let icon: String
    let label: String
    let before: Int
    let after: Int
    let percent: Float
    var unit: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text("\(formatNumber(before))\(unit)")
                .font(.caption)
                .frame(width: 70, alignment: .trailing)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("\(formatNumber(after))\(unit)")
                .font(.caption)
                .bold()
                .frame(width: 70, alignment: .trailing)

            Spacer()

            if percent > 0 {
                Text("-\(String(format: "%.1f", percent))%")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.green)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

// MARK: - Optimization Settings

struct OptimizationSettingsSection: View {
    @ObservedObject var viewModel: AssetOptimizerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Settings")
                .font(.headline)

            // Materials
            SettingsGroup(title: "Materials", icon: "paintpalette") {
                Toggle("Fix Materials", isOn: $viewModel.settings.fixMaterials)
                Toggle("Validate Materials", isOn: $viewModel.settings.validateMaterials)
            }

            // Textures
            SettingsGroup(title: "Textures", icon: "photo") {
                Toggle("Optimize Textures", isOn: $viewModel.settings.optimizeTextures)
                Toggle("Resize Textures", isOn: $viewModel.settings.resizeTextures)
                Toggle("Remove Duplicates", isOn: $viewModel.settings.removeDuplicateTextures)
                Toggle("Remove Unused", isOn: $viewModel.settings.removeUnusedTextures)

                if viewModel.settings.resizeTextures {
                    HStack {
                        Text("Max Resolution:")
                            .font(.caption)
                        Picker("", selection: $viewModel.settings.maxTextureResolution) {
                            Text("512").tag(512)
                            Text("1024").tag(1024)
                            Text("2048").tag(2048)
                            Text("4096").tag(4096)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            // Meshes
            SettingsGroup(title: "Meshes", icon: "cube") {
                Toggle("Optimize Meshes", isOn: $viewModel.settings.optimizeMeshes)
                Toggle("Remove Degenerate Triangles", isOn: $viewModel.settings.removeDegenerateTriangles)
                Toggle("Merge Duplicate Vertices", isOn: $viewModel.settings.mergeDuplicateVertices)
            }

            // Hierarchy
            SettingsGroup(title: "Hierarchy", icon: "square.stack.3d.down.right") {
                Toggle("Optimize Hierarchy", isOn: $viewModel.settings.optimizeHierarchy)
                Toggle("Flatten Hierarchy", isOn: $viewModel.settings.flattenHierarchy)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.subheadline)
                    .bold()
            }

            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .font(.caption)
            .padding(.leading, 20)
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Optimizing View

struct OptimizingView: View {
    @ObservedObject var viewModel: AssetOptimizerViewModel

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2.0)

            Text("Optimizing Asset...")
                .font(.title2)
                .bold()

            Text(viewModel.currentOperation)
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: viewModel.progress, total: 1.0)
                .frame(width: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Results View

struct ResultsView: View {
    let result: OptimizationResult
    @ObservedObject var viewModel: AssetOptimizerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Success Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 64, height: 64)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optimization Complete!")
                            .font(.title)
                            .bold()

                        Text("Processed in \(String(format: "%.2f", result.processingTime)) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Savings Summary
                SavingsComparisonView(stats: result.statistics)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)

                // Optimizations Applied
                if !(result.optimizationsApplied as! [String]).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Optimizations Applied")
                            .font(.headline)

                        ForEach(Array((result.optimizationsApplied as! [String]).enumerated()), id: \.offset) { _, opt in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)

                                Text(opt)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }

                // Warnings
                if !(result.warnings as! [String]).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Warnings")
                            .font(.headline)

                        ForEach(Array((result.warnings as! [String]).enumerated()), id: \.offset) { _, warning in
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)

                                Text(warning)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

// MARK: - View Model

class AssetOptimizerViewModel: ObservableObject {
    private let renderer: PinnacleMetalRenderer
    private var bridge: AssetOptimizerBridge

    @Published var selectedProfile: OptimizationProfile = .desktop
    @Published var settings: OptimizationSettings
    @Published var showCustomSettings: Bool = false

    @Published var preview: OptimizationPreview? = nil
    @Published var optimizationResult: OptimizationResult? = nil

    @Published var isOptimizing: Bool = false
    @Published var currentOperation: String = ""
    @Published var progress: Double = 0.0

    init(renderer: PinnacleMetalRenderer) {
        self.renderer = renderer
        self.bridge = AssetOptimizerBridge(renderer: renderer)
        self.settings = OptimizationSettings.desktopProfile()
    }

    var canOptimize: Bool {
        return !isOptimizing && preview != nil
    }

    func selectProfile(_ profile: OptimizationProfile) {
        selectedProfile = profile
        settings = AssetOptimizerBridge.settings(for: profile)
        showCustomSettings = (profile == .custom)
        updatePreview()
    }

    func analyze() {
        updatePreview()
    }

    func updatePreview() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let preview = self.bridge.previewOptimization(self.settings)

            DispatchQueue.main.async {
                self.preview = preview
            }
        }
    }

    func optimize() {
        isOptimizing = true
        optimizationResult = nil
        progress = 0.0
        currentOperation = "Starting optimization..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.bridge.optimize(with: self.settings)

            DispatchQueue.main.async {
                self.optimizationResult = result
                self.isOptimizing = false
                self.progress = 1.0
            }
        }
    }

    func reset() {
        optimizationResult = nil
        analyze()
    }

    func exportReport() {
        guard let result = optimizationResult else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "txt")!]
        panel.nameFieldStringValue = "optimization_report.txt"

        if panel.runModal() == .OK, let url = panel.url {
            _ = AssetOptimizerBridge.exportOptimizationReport(result, filePath: url.path)
        }
    }
}

// MARK: - Preview

struct AssetOptimizerView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Asset Optimizer Preview")
    }
}
