import SwiftUI

struct MaterialCreatorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var materialName: String = "New Material"
    @State private var assignedTextures: [PBRTextureChannel: String] = [:]
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PBR Material Creator")
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Material Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Material Name")
                            .font(.headline)

                        TextField("Enter material name", text: $materialName)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Texture Channels
                    Text("Texture Channels")
                        .font(.headline)

                    Text("Drag and drop texture files below. Channels will be auto-detected from filenames.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Base Color
                    TextureDropZone(
                        channel: .baseColor,
                        title: "Base Color / Albedo",
                        description: "RGB color map (basecolor, albedo, diffuse)",
                        assignedPath: assignedTextures[.baseColor],
                        onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .baseColor) },
                        onClear: { assignedTextures.removeValue(forKey: .baseColor) }
                    )

                    // Metallic + Roughness (Combined)
                    TextureDropZone(
                        channel: .metallicRoughness,
                        title: "Metallic-Roughness (Combined)",
                        description: "B=Metallic, G=Roughness (glTF standard)",
                        assignedPath: assignedTextures[.metallicRoughness],
                        onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .metallicRoughness) },
                        onClear: { assignedTextures.removeValue(forKey: .metallicRoughness) }
                    )

                    HStack(spacing: 12) {
                        // Metallic (Separate)
                        TextureDropZone(
                            channel: .metallic,
                            title: "Metallic",
                            description: "Metallic map only",
                            assignedPath: assignedTextures[.metallic],
                            onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .metallic) },
                            onClear: { assignedTextures.removeValue(forKey: .metallic) }
                        )

                        // Roughness (Separate)
                        TextureDropZone(
                            channel: .roughness,
                            title: "Roughness",
                            description: "Roughness map only",
                            assignedPath: assignedTextures[.roughness],
                            onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .roughness) },
                            onClear: { assignedTextures.removeValue(forKey: .roughness) }
                        )
                    }

                    // Normal Map
                    TextureDropZone(
                        channel: .normal,
                        title: "Normal Map",
                        description: "Tangent-space normal map",
                        assignedPath: assignedTextures[.normal],
                        onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .normal) },
                        onClear: { assignedTextures.removeValue(forKey: .normal) }
                    )

                    HStack(spacing: 12) {
                        // Ambient Occlusion
                        TextureDropZone(
                            channel: .ambientOcclusion,
                            title: "Ambient Occlusion",
                            description: "AO map",
                            assignedPath: assignedTextures[.ambientOcclusion],
                            onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .ambientOcclusion) },
                            onClear: { assignedTextures.removeValue(forKey: .ambientOcclusion) }
                        )

                        // Emissive
                        TextureDropZone(
                            channel: .emissive,
                            title: "Emissive",
                            description: "Emission map",
                            assignedPath: assignedTextures[.emissive],
                            onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .emissive) },
                            onClear: { assignedTextures.removeValue(forKey: .emissive) }
                        )
                    }

                    // Height/Displacement
                    TextureDropZone(
                        channel: .height,
                        title: "Height / Displacement",
                        description: "Height map for parallax/displacement",
                        assignedPath: assignedTextures[.height],
                        onDrop: { path in handleTextureDrop(path: path, suggestedChannel: .height) },
                        onClear: { assignedTextures.removeValue(forKey: .height) }
                    )
                }
                .padding()
            }

            Divider()

            // Footer with actions
            HStack {
                Button("Clear All") {
                    assignedTextures.removeAll()
                }
                .disabled(assignedTextures.isEmpty)

                Spacer()

                Text("\(assignedTextures.count) texture\(assignedTextures.count == 1 ? "" : "s") assigned")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Create Material") {
                    createMaterial()
                }
                .buttonStyle(.borderedProminent)
                .disabled(assignedTextures.isEmpty || materialName.isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 800)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Material '\(materialName)' created successfully with \(assignedTextures.count) texture(s).")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func handleTextureDrop(path: String, suggestedChannel: PBRTextureChannel) {
        // Auto-detect channel from filename
        let detectedChannel = MaterialFixerBridge.detectTextureChannel(path)

        // Use detected channel if valid, otherwise use suggested
        let finalChannel: PBRTextureChannel
        if detectedChannel.rawValue >= 0 {
            finalChannel = detectedChannel
        } else {
            finalChannel = suggestedChannel
        }

        assignedTextures[finalChannel] = path
    }

    private func createMaterial() {
        // Convert Swift dictionary to NSDictionary with NSNumber keys
        var textureDict: [NSNumber: String] = [:]
        for (channel, path) in assignedTextures {
            textureDict[NSNumber(value: channel.rawValue)] = path
        }

        let result = MaterialFixerBridge.createMaterial(
            fromTextures: textureDict as NSDictionary,
            materialName: materialName
        )

        if result.success {
            showSuccess = true
        } else {
            errorMessage = result.errorMessage ?? "Unknown error"
            showError = true
        }
    }
}

// MARK: - Texture Drop Zone Component

struct TextureDropZone: View {
    let channel: PBRTextureChannel
    let title: String
    let description: String
    let assignedPath: String?
    let onDrop: (String) -> Void
    let onClear: () -> Void

    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .bold()

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if assignedPath != nil {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear texture")
                }
            }

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                                style: StrokeStyle(lineWidth: 2, dash: assignedPath == nil ? [5, 3] : [])
                            )
                    )

                if let path = assignedPath {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)

                            Text(path)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("Drop texture here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                }
            }
            .frame(height: 60)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }

            // Check if it's an image file
            let ext = url.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "tga", "tiff", "exr", "hdr"].contains(ext) else { return }

            DispatchQueue.main.async {
                onDrop(url.path)
            }
        }

        return true
    }
}

// MARK: - PBRTextureChannel Extension for Swift

extension PBRTextureChannel {
    var displayName: String {
        switch self {
        case .baseColor: return "Base Color"
        case .metallic: return "Metallic"
        case .roughness: return "Roughness"
        case .metallicRoughness: return "Metallic-Roughness"
        case .normal: return "Normal"
        case .ambientOcclusion: return "Ambient Occlusion"
        case .emissive: return "Emissive"
        case .height: return "Height"
        @unknown default: return "Unknown"
        }
    }
}

struct MaterialCreatorView_Previews: PreviewProvider {
    static var previews: some View {
        MaterialCreatorView()
    }
}
