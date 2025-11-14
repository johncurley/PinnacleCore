import SwiftUI

/// View model for scene inspection
class SceneInspectorViewModel: ObservableObject {
    @Published var statistics: SceneStatistics?
    @Published var meshes: [MeshInfo] = []
    @Published var materials: [MaterialInfo] = []
    @Published var selectedMesh: MeshInfo?
    @Published var selectedMaterial: MaterialInfo?

    private var bridge: SceneInspectorBridge?

    init(renderer: UnsafeMutableRawPointer?) {
        guard let renderer = renderer else { return }
        bridge = SceneInspectorBridge(renderer: renderer)
        refresh()
    }

    func refresh() {
        guard let bridge = bridge else { return }

        statistics = bridge.getStatistics()
        meshes = bridge.getMeshes() as? [MeshInfo] ?? []
        materials = bridge.getMaterials() as? [MaterialInfo] ?? []
    }
}

/// Main scene inspector view
struct SceneInspectorView: View {
    @ObservedObject var viewModel: SceneInspectorViewModel
    @State private var selectedTab: InspectorTab = .scene

    enum InspectorTab {
        case scene
        case materials
        case statistics
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Inspector", selection: $selectedTab) {
                Label("Scene", systemImage: "cube.transparent").tag(InspectorTab.scene)
                Label("Materials", systemImage: "paintpalette").tag(InspectorTab.materials)
                Label("Stats", systemImage: "chart.bar").tag(InspectorTab.statistics)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(8)

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .scene:
                    SceneHierarchyView(meshes: viewModel.meshes, selectedMesh: $viewModel.selectedMesh)
                case .materials:
                    MaterialListView(materials: viewModel.materials, selectedMaterial: $viewModel.selectedMaterial)
                case .statistics:
                    StatisticsView(statistics: viewModel.statistics)
                }
            }

            Divider()

            // Refresh button
            HStack {
                Button(action: { viewModel.refresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - Scene Hierarchy View

struct SceneHierarchyView: View {
    let meshes: [MeshInfo]
    @Binding var selectedMesh: MeshInfo?

    var body: some View {
        if meshes.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "cube.transparent")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No model loaded")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List(meshes, id: \.name, selection: $selectedMesh) { mesh in
                MeshRowView(mesh: mesh)
            }
            .listStyle(SidebarListStyle())
        }
    }
}

struct MeshRowView: View {
    let mesh: MeshInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cube")
                    .foregroundColor(.blue)
                Text(mesh.name)
                    .font(.headline)
            }

            HStack(spacing: 12) {
                Label("\(mesh.triangleCount) tris", systemImage: "triangle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(mesh.vertexCount) verts", systemImage: "point.3.filled.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                if mesh.hasNormals {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .help("Has normals")
                }
                if mesh.hasTexCoords {
                    Image(systemName: "grid.circle.fill")
                        .foregroundColor(.green)
                        .help("Has UV coordinates")
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Material List View

struct MaterialListView: View {
    let materials: [MaterialInfo]
    @Binding var selectedMaterial: MaterialInfo?

    var body: some View {
        if materials.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "paintpalette")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No materials")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List(materials, id: \.name, selection: $selectedMaterial) { material in
                MaterialRowView(material: material)
            }
            .listStyle(SidebarListStyle())
        }
    }
}

struct MaterialRowView: View {
    let material: MaterialInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .foregroundColor(.purple)
                Text(material.name)
                    .font(.headline)
            }

            // Color swatch
            if let baseColor = material.baseColorFactor as? [NSNumber], baseColor.count == 4 {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(
                            red: baseColor[0].doubleValue,
                            green: baseColor[1].doubleValue,
                            blue: baseColor[2].doubleValue
                        ))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Metallic: \(String(format: "%.2f", material.metallicFactor))")
                            .font(.caption)
                        Text("Roughness: \(String(format: "%.2f", material.roughnessFactor))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Texture indicators
            HStack(spacing: 6) {
                if material.hasBaseColorTexture {
                    TextureBadge(name: "Base", icon: "photo", color: .blue)
                }
                if material.hasMetallicRoughnessTexture {
                    TextureBadge(name: "MR", icon: "square.grid.2x2", color: .orange)
                }
                if material.hasNormalTexture {
                    TextureBadge(name: "Normal", icon: "arrow.up.right", color: .green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TextureBadge: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(name)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(4)
    }
}

// MARK: - Statistics View

struct StatisticsView: View {
    let statistics: SceneStatistics?

    var body: some View {
        if let stats = statistics {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatisticsSection(title: "Geometry", icon: "cube") {
                        SceneInspectorStatRow(label: "Meshes", value: "\(stats.meshCount)")
                        SceneInspectorStatRow(label: "Triangles", value: formatNumber(stats.triangleCount))
                        SceneInspectorStatRow(label: "Vertices", value: formatNumber(stats.vertexCount))
                    }

                    Divider()

                    StatisticsSection(title: "Materials", icon: "paintpalette") {
                        SceneInspectorStatRow(label: "Materials", value: "\(stats.materialCount)")
                        SceneInspectorStatRow(label: "Textures", value: "\(stats.textureCount)")
                        SceneInspectorStatRow(label: "Texture Memory", value: String(format: "%.2f MB", stats.textureMemoryMB))
                    }

                    Divider()

                    StatisticsSection(title: "Bounding Box", icon: "cube.transparent") {
                        if let bbox = stats.boundingBox as? [NSNumber], bbox.count == 6 {
                            let minX = bbox[0].doubleValue
                            let minY = bbox[1].doubleValue
                            let minZ = bbox[2].doubleValue
                            let maxX = bbox[3].doubleValue
                            let maxY = bbox[4].doubleValue
                            let maxZ = bbox[5].doubleValue

                            let sizeX = maxX - minX
                            let sizeY = maxY - minY
                            let sizeZ = maxZ - minZ

                            SceneInspectorStatRow(label: "Size X", value: String(format: "%.3f", sizeX))
                            SceneInspectorStatRow(label: "Size Y", value: String(format: "%.3f", sizeY))
                            SceneInspectorStatRow(label: "Size Z", value: String(format: "%.3f", sizeZ))
                        }
                    }
                }
                .padding()
            }
        } else {
            VStack {
                Spacer()
                Image(systemName: "chart.bar")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No statistics available")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct StatisticsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding(.leading, 8)
        }
    }
}

struct SceneInspectorStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Preview

struct SceneInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        SceneInspectorView(viewModel: SceneInspectorViewModel(renderer: nil))
            .frame(width: 300, height: 600)
    }
}
