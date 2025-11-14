import SwiftUI

struct ModelValidatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ModelValidatorViewModel

    init(renderer: UnsafeMutableRawPointer?) {
        _viewModel = StateObject(wrappedValue: ModelValidatorViewModel(renderer: renderer))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Model Validator")
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

            if viewModel.isValidating {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Validating Model...")
                        .font(.headline)

                    Text("Running comprehensive validation checks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = viewModel.validationResult {
                // Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status Header
                        ValidationStatusHeader(result: result)

                        // Performance Dashboard
                        if let metrics = result.metrics {
                            PerformanceDashboard(metrics: metrics)
                        }

                        // Issues Summary
                        if !result.issues.isEmpty {
                            IssuesSummarySection(issues: result.issues as! [ValidationIssue])
                        }

                        // Recommendations
                        if !result.recommendations.isEmpty {
                            RecommendationsSection(recommendations: result.recommendations as! [String])
                        }

                        // Mesh Details
                        if !result.meshResults.isEmpty {
                            MeshDetailsSection(meshResults: result.meshResults as! [MeshValidationResult])
                        }
                    }
                    .padding()
                }
            } else {
                // Initial state
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Ready to Validate")
                        .font(.title)

                    Text("Run comprehensive validation checks on your loaded model")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Validate Model") {
                        viewModel.validateModel()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // Footer
            HStack {
                if let result = viewModel.validationResult {
                    Button("Export Report...") {
                        viewModel.exportReport()
                    }

                    Spacer()

                    Button("Re-validate") {
                        viewModel.validateModel()
                    }
                } else {
                    Spacer()

                    Button("Validate") {
                        viewModel.validateModel()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 900, height: 700)
        .onAppear {
            viewModel.validateModel()
        }
    }
}

// MARK: - Status Header

struct ValidationStatusHeader: View {
    let result: ModelValidationResult

    var body: some View {
        HStack(spacing: 20) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(result.isValid ? "Model is Valid" : "Issues Found")
                    .font(.title)
                    .bold()

                Text(result.modelFormat)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    if result.criticalCount > 0 {
                        StatusBadge(count: Int(result.criticalCount), label: "Critical", color: .red)
                    }
                    if result.errorCount > 0 {
                        StatusBadge(count: Int(result.errorCount), label: "Errors", color: .red)
                    }
                    if result.warningCount > 0 {
                        StatusBadge(count: Int(result.warningCount), label: "Warnings", color: .orange)
                    }
                    if result.infoCount > 0 {
                        StatusBadge(count: Int(result.infoCount), label: "Info", color: .blue)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var statusIcon: String {
        if result.criticalCount > 0 {
            return "xmark.octagon.fill"
        } else if result.errorCount > 0 {
            return "xmark.circle.fill"
        } else if result.warningCount > 0 {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if result.criticalCount > 0 || result.errorCount > 0 {
            return .red
        } else if result.warningCount > 0 {
            return .orange
        }
        return .green
    }
}

struct StatusBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption)
                .bold()

            Text(label)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(4)
    }
}

// MARK: - Performance Dashboard

struct PerformanceDashboard: View {
    let metrics: PerformanceMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance Analysis")
                    .font(.headline)

                Spacer()

                // Performance Score Badge
                HStack(spacing: 8) {
                    Text("\(metrics.performanceScore)/100")
                        .font(.title2)
                        .bold()
                        .foregroundColor(scoreColor)

                    Text(metrics.performanceRating)
                        .font(.subheadline)
                        .foregroundColor(scoreColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(scoreColor.opacity(0.2))
                .cornerRadius(8)
            }

            // Metrics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(icon: "cube", label: "Vertices", value: formatNumber(Int(metrics.totalVertices)))
                MetricCard(icon: "triangle", label: "Triangles", value: formatNumber(Int(metrics.totalTriangles)))
                MetricCard(icon: "square.stack.3d.up", label: "Meshes", value: "\(metrics.totalMeshes)")
                MetricCard(icon: "paintpalette", label: "Materials", value: "\(metrics.totalMaterials)")
                MetricCard(icon: "photo", label: "Textures", value: "\(metrics.totalTextures)")
                MetricCard(icon: "arrow.triangle.branch", label: "Draw Calls", value: "\(metrics.estimatedDrawCalls)")
            }

            // Memory Usage
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.secondary)

                Text("Texture Memory:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatBytes(UInt64(metrics.totalTextureMemory)))
                    .font(.caption)
                    .bold()

                Spacer()
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var scoreColor: Color {
        if metrics.performanceScore >= 80 {
            return .green
        } else if metrics.performanceScore >= 60 {
            return .blue
        } else if metrics.performanceScore >= 40 {
            return .orange
        }
        return .red
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct MetricCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title3)
                .bold()

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Issues Summary Section

struct IssuesSummarySection: View {
    let issues: [ValidationIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Issues (\(issues.count))")
                .font(.headline)

            ForEach(Array(issues.enumerated()), id: \.offset) { index, issue in
                IssueCard(issue: issue)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct IssueCard: View {
    let issue: ValidationIssue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: severityIcon)
                .foregroundColor(severityColor)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(issue.title)
                        .font(.subheadline)
                        .bold()

                    Spacer()

                    if !issue.affectedObject.isEmpty {
                        Text(issue.affectedObject)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                Text(issue.message)
                    .font(.caption)
                    .foregroundColor(.primary)

                if !issue.suggestion.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .font(.caption2)
                            .foregroundColor(.yellow)

                        Text(issue.suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }

    private var severityIcon: String {
        switch issue.severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .critical:
            return "xmark.octagon.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var severityColor: Color {
        switch issue.severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .red
        @unknown default:
            return .secondary
        }
    }
}

// MARK: - Recommendations Section

struct RecommendationsSection: View {
    let recommendations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)

            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)

                    Text(recommendation)
                        .font(.caption)
                }
                .padding()
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Mesh Details Section

struct MeshDetailsSection: View {
    let meshResults: [MeshValidationResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mesh Details (\(meshResults.count))")
                .font(.headline)

            ForEach(Array(meshResults.enumerated()), id: \.offset) { index, meshResult in
                MeshDetailCard(meshResult: meshResult)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MeshDetailCard: View {
    let meshResult: MeshValidationResult
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(meshResult.meshName)
                        .font(.subheadline)
                        .bold()

                    Spacer()

                    HStack(spacing: 16) {
                        Label("\(formatNumber(Int(meshResult.vertexCount))) verts", systemImage: "cube")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("\(formatNumber(Int(meshResult.triangleCount))) tris", systemImage: "triangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !meshResult.issues.isEmpty {
                        Text("\(meshResult.issues.count)")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Mesh properties
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    PropertyIndicator(icon: "point.3.connected.trianglepath.dotted", label: "Normals", value: meshResult.hasNormals)
                    PropertyIndicator(icon: "grid", label: "Tex Coords", value: meshResult.hasTexCoords)
                    PropertyIndicator(icon: "square.on.square", label: "Manifold", value: meshResult.isManifold)
                    PropertyIndicator(icon: "drop.fill", label: "Watertight", value: meshResult.isWatertight)
                }

                if !meshResult.issues.isEmpty {
                    Divider()

                    ForEach(Array(meshResult.issues.enumerated()), id: \.offset) { _, issue in
                        Text("• \(issue.message)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

struct PropertyIndicator: View {
    let icon: String
    let label: String
    let value: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(value ? .green : .red)
        }
    }
}

// MARK: - View Model

class ModelValidatorViewModel: ObservableObject {
    private let renderer: UnsafeMutableRawPointer?
    private var bridge: ModelValidatorBridge

    @Published var validationResult: ModelValidationResult? = nil
    @Published var isValidating: Bool = false

    init(renderer: UnsafeMutableRawPointer?) {
        self.renderer = renderer
        self.bridge = ModelValidatorBridge(renderer: renderer)
    }

    func validateModel() {
        isValidating = true
        validationResult = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let options = ValidationOptions()
            let result = self.bridge.validate(options)

            DispatchQueue.main.async {
                self.validationResult = result
                self.isValidating = false
            }
        }
    }

    func exportReport() {
        guard let result = validationResult else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "txt")!]
        panel.nameFieldStringValue = "validation_report.txt"

        if panel.runModal() == .OK, let url = panel.url {
            _ = ModelValidatorBridge.exportValidationReport(result, filePath: url.path)
        }
    }
}

// MARK: - Preview

struct ModelValidatorView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Model Validator Preview")
    }
}
