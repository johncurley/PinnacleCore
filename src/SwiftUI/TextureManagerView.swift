import SwiftUI

struct TextureManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TextureManagerViewModel

    init(renderer: UnsafeMutableRawPointer?) {
        _viewModel = StateObject(wrappedValue: TextureManagerViewModel(renderer: renderer))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Texture Manager")
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

            HSplitView {
                // Left: Texture List
                TextureListSection(viewModel: viewModel)
                    .frame(minWidth: 300)

                // Right: Details and Actions
                VStack(spacing: 0) {
                    if let selectedTexture = viewModel.selectedTexture {
                        TextureDetailSection(texture: selectedTexture, viewModel: viewModel)
                    } else {
                        // Overview when no texture selected
                        TextureOverviewSection(viewModel: viewModel)
                    }
                }
                .frame(minWidth: 400)
            }

            Divider()

            // Footer with actions
            HStack {
                if viewModel.analysisComplete {
                    Button("Export Report...") {
                        viewModel.exportReport()
                    }
                }

                Spacer()

                if !viewModel.isAnalyzing {
                    Button("Analyze Textures") {
                        viewModel.analyzeTextures()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 900, height: 700)
        .onAppear {
            viewModel.analyzeTextures()
        }
    }
}

// MARK: - Texture List Section

struct TextureListSection: View {
    @ObservedObject var viewModel: TextureManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Textures")
                    .font(.headline)
                    .padding()

                Spacer()

                if let result = viewModel.analysisResult {
                    Text("\(result.totalTextures) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Filters
            HStack(spacing: 12) {
                Picker("Filter", selection: $viewModel.filterMode) {
                    Text("All").tag(TextureFilterMode.all)
                    Text("Issues Only").tag(TextureFilterMode.issuesOnly)
                    Text("Missing").tag(TextureFilterMode.missing)
                    Text("Unused").tag(TextureFilterMode.unused)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Texture list
            if viewModel.filteredTextures.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No textures found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if !viewModel.analysisComplete {
                        Button("Analyze Textures") {
                            viewModel.analyzeTextures()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredTextures, id: \.index, selection: $viewModel.selectedTextureIndex) { texture in
                    TextureRow(texture: texture, viewModel: viewModel)
                }
            }
        }
    }
}

struct TextureRow: View {
    let texture: TextureInfo
    @ObservedObject var viewModel: TextureManagerViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(texture.name)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if texture.exists {
                        Text("\(texture.width)x\(texture.height)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(formatFileSize(texture.fileSize))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if texture.referenceCount > 0 {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text("\(texture.referenceCount) ref\(texture.referenceCount == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Missing")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            // Issue badge
            if let issueCount = viewModel.textureIssues[Int(texture.index)]?.count, issueCount > 0 {
                Text("\(issueCount)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        if !texture.exists {
            return "exclamationmark.triangle.fill"
        } else if texture.referenceCount == 0 {
            return "minus.circle"
        } else if let issues = viewModel.textureIssues[Int(texture.index)], !issues.isEmpty {
            return "exclamationmark.circle"
        }
        return "checkmark.circle"
    }

    private var statusColor: Color {
        if !texture.exists {
            return .red
        } else if texture.referenceCount == 0 {
            return .secondary
        } else if let issues = viewModel.textureIssues[Int(texture.index)], !issues.isEmpty {
            return .orange
        }
        return .green
    }

    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Texture Overview Section

struct TextureOverviewSection: View {
    @ObservedObject var viewModel: TextureManagerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let result = viewModel.analysisResult {
                    // Statistics
                    Text("Statistics")
                        .font(.headline)

                    VStack(spacing: 12) {
                        TextureManagerStatRow(label: "Total Textures", value: "\(result.totalTextures)")
                        TextureManagerStatRow(label: "Missing Textures", value: "\(result.missingTextures)",
                               valueColor: result.missingTextures > 0 ? .red : nil)
                        TextureManagerStatRow(label: "Unused Textures", value: "\(result.unusedTextures)",
                               valueColor: result.unusedTextures > 0 ? .orange : nil)
                        TextureManagerStatRow(label: "Duplicate Groups", value: "\(result.duplicateGroups)",
                               valueColor: result.duplicateGroups > 0 ? .orange : nil)
                        TextureManagerStatRow(label: "Total Memory", value: formatBytes(result.totalMemoryUsage))
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Issues Summary
                    if !result.issues.isEmpty {
                        Text("Issues")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(result.issues.prefix(10).enumerated()), id: \.offset) { _, issue in
                                IssueRow(issue: issue)
                            }

                            if result.issues.count > 10 {
                                Text("+ \(result.issues.count - 10) more issues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    // Quick Actions
                    Text("Quick Actions")
                        .font(.headline)

                    VStack(spacing: 12) {
                        if result.missingTextures > 0 {
                            Button(action: {
                                viewModel.showFixPathsDialog = true
                            }) {
                                Label("Fix Missing Texture Paths", systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if result.unusedTextures > 0 {
                            Button(action: {
                                viewModel.removeUnusedTextures()
                            }) {
                                Label("Remove Unused Textures (\(result.unusedTextures))", systemImage: "trash")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if result.duplicateGroups > 0 {
                            Button(action: {
                                viewModel.removeDuplicates()
                            }) {
                                Label("Remove Duplicate Textures", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct TextureManagerStatRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(valueColor ?? .primary)
        }
    }
}

struct IssueRow: View {
    let issue: TextureIssue

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: severityIcon)
                .foregroundColor(severityColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.message)
                    .font(.caption)

                Text(issue.textureName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var severityIcon: String {
        switch issue.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        @unknown default:
            return "questionmark.circle"
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

// MARK: - Texture Detail Section

struct TextureDetailSection: View {
    let texture: TextureInfo
    @ObservedObject var viewModel: TextureManagerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(texture.name)
                            .font(.title3)
                            .bold()

                        Text(texture.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    Spacer()
                }

                Divider()

                // Properties
                if texture.exists {
                    Text("Properties")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        PropertyRow(label: "Dimensions", value: "\(texture.width) x \(texture.height)")
                        PropertyRow(label: "Format", value: texture.format)
                        PropertyRow(label: "File Size", value: formatBytes(texture.fileSize))
                        PropertyRow(label: "Power of Two", value: texture.isPowerOfTwo ? "Yes" : "No")
                        PropertyRow(label: "References", value: "\(texture.referenceCount) material(s)")
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Issues
                if let issues = viewModel.textureIssues[Int(texture.index)], !issues.isEmpty {
                    Text("Issues")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                            IssueDetailRow(issue: issue)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Actions
                Text("Actions")
                    .font(.headline)

                VStack(spacing: 12) {
                    if !texture.exists {
                        Button(action: {
                            viewModel.searchForTexture(texture)
                        }) {
                            Label("Search for Missing File", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button(action: {
                        // TODO: Optimize texture
                    }) {
                        Label("Optimize Texture", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(true)

                    if texture.referenceCount == 0 {
                        Button(action: {
                            viewModel.removeTexture(texture)
                        }) {
                            Label("Remove Unused Texture", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct PropertyRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.caption)
        }
    }
}

struct IssueDetailRow: View {
    let issue: TextureIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)

                Text(issue.message)
                    .font(.caption)
                    .bold()
            }

            if !issue.suggestion.isEmpty {
                Text(issue.suggestion)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: String {
        switch issue.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        @unknown default:
            return "questionmark.circle"
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

// MARK: - Enums

enum TextureFilterMode {
    case all
    case issuesOnly
    case missing
    case unused
}

// MARK: - View Model

class TextureManagerViewModel: ObservableObject {
    private let renderer: UnsafeMutableRawPointer?
    private var bridge: TextureManagerBridge

    @Published var analysisResult: TextureAnalysisResult? = nil
    @Published var isAnalyzing: Bool = false
    @Published var analysisComplete: Bool = false

    @Published var filterMode: TextureFilterMode = .all
    @Published var selectedTextureIndex: Int? = nil
    @Published var showFixPathsDialog: Bool = false

    init(renderer: UnsafeMutableRawPointer?) {
        self.renderer = renderer
        self.bridge = TextureManagerBridge(renderer: renderer)
    }

    var filteredTextures: [TextureInfo] {
        guard let result = analysisResult else { return [] }

        switch filterMode {
        case .all:
            return result.textures as! [TextureInfo]
        case .issuesOnly:
            return (result.textures as! [TextureInfo]).filter { texture in
                textureIssues[Int(texture.index)]?.isEmpty == false
            }
        case .missing:
            return (result.textures as! [TextureInfo]).filter { !$0.exists }
        case .unused:
            return (result.textures as! [TextureInfo]).filter { $0.referenceCount == 0 }
        }
    }

    var selectedTexture: TextureInfo? {
        guard let index = selectedTextureIndex,
              let result = analysisResult else { return nil }

        return (result.textures as! [TextureInfo]).first { $0.index == index }
    }

    var textureIssues: [Int: [TextureIssue]] {
        guard let result = analysisResult else { return [:] }

        var dict: [Int: [TextureIssue]] = [:]
        for issue in result.issues as! [TextureIssue] {
            let index = Int(issue.textureIndex)
            if dict[index] == nil {
                dict[index] = []
            }
            dict[index]?.append(issue)
        }
        return dict
    }

    func analyzeTextures() {
        isAnalyzing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.bridge.analyzeTextures()

            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
                self.analysisComplete = true
            }
        }
    }

    func searchForTexture(_ texture: TextureInfo) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select folder to search for \(texture.name)"

        if panel.runModal() == .OK, let folderURL = panel.url {
            let matches = bridge.search(forMissingTexture: texture.name,
                                       inDirectory: folderURL.path,
                                       recursive: true) as! [String]

            // TODO: Show results and allow user to select correct path
            print("Found \(matches.count) matches for \(texture.name)")
        }
    }

    func removeTexture(_ texture: TextureInfo) {
        // TODO: Implement texture removal
        print("Remove texture: \(texture.name)")
    }

    func removeUnusedTextures() {
        let result = bridge.removeUnusedTextures()
        // TODO: Show result dialog
        print("Removed unused textures: \(result.texturesProcessed)")
        analyzeTextures() // Refresh
    }

    func removeDuplicates() {
        let result = bridge.removeDuplicateTextures()
        // TODO: Show result dialog
        print("Removed duplicates: \(result.duplicatesRemoved)")
        analyzeTextures() // Refresh
    }

    func exportReport() {
        guard let result = analysisResult else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "txt")!]
        panel.nameFieldStringValue = "texture_analysis.txt"

        if panel.runModal() == .OK, let url = panel.url {
            _ = TextureManagerBridge.exportAnalysisReport(result, filePath: url.path)
        }
    }
}

// MARK: - Preview

struct TextureManagerView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Texture Manager Preview")
    }
}
