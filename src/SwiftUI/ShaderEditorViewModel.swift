import Foundation
import SwiftUI
import Combine

/// View model for the shader editor
class ShaderEditorViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var vertexShaderSource: String = ""
    @Published var fragmentShaderSource: String = ""
    @Published var isCompiling: Bool = false
    @Published var compilationSuccess: Bool = false
    @Published var compilationTime: Double = 0.0
    @Published var errors: [String] = []
    @Published var errorLines: [Int] = []
    @Published var statusMessage: String = "Ready"
    @Published var autoCompile: Bool = false
    @Published var selectedShaderTab: ShaderTab = .fragment

    // MARK: - Types

    enum ShaderTab {
        case vertex
        case fragment
    }

    // MARK: - Private Properties

    private var bridge: ShaderEditorBridge?
    private var autoCompileTimer: Timer?
    private var lastCompileTime: Date = Date()

    // MARK: - Initialization

    init(renderer: UnsafeMutableRawPointer?) {
        guard let renderer = renderer else {
            print("❌ ShaderEditorViewModel: No renderer provided")
            return
        }

        bridge = ShaderEditorBridge(renderer: renderer)

        // Load initial shader sources from bridge
        if let bridge = bridge {
            vertexShaderSource = bridge.getVertexShaderSource()
            fragmentShaderSource = bridge.getFragmentShaderSource()
        }

        // Setup auto-compile observer
        setupAutoCompile()
    }

    // MARK: - Public Methods

    /// Compile shaders and check for errors
    func compile() {
        guard let bridge = bridge else {
            statusMessage = "Error: Bridge not initialized"
            return
        }

        isCompiling = true
        statusMessage = "Compiling..."
        errors = []
        errorLines = []

        // Update bridge with current source
        bridge.setVertexShaderSource(vertexShaderSource)
        bridge.setFragmentShaderSource(fragmentShaderSource)

        // Compile on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = bridge.testCompile()

            DispatchQueue.main.async {
                self.isCompiling = false
                self.compilationSuccess = result.success
                self.compilationTime = result.compilationTime
                self.errors = result.errors as? [String] ?? []
                self.errorLines = result.errorLines as? [Int] ?? []

                if result.success {
                    self.statusMessage = String(format: "✓ Compiled in %.3fs", result.compilationTime)
                } else {
                    self.statusMessage = "✗ Compilation failed (\(self.errors.count) error\(self.errors.count == 1 ? "" : "s"))"
                }
            }
        }
    }

    /// Apply compiled shader to renderer (hot-reload)
    func applyShader() {
        guard let bridge = bridge else { return }

        // Compile first
        compile()

        // Wait a moment for compilation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.compilationSuccess else {
                self?.statusMessage = "Cannot apply: Compilation failed"
                return
            }

            if bridge.applyShader() {
                self.statusMessage = "✓ Shader hot-reloaded!"
            } else {
                self.statusMessage = "✗ Failed to apply shader"
            }
        }
    }

    /// Reset to default shaders
    func resetToDefaults() {
        bridge?.resetToDefaults()
        statusMessage = "Reset to default shaders"
    }

    /// Load a preset shader
    func loadPreset(_ name: String) {
        guard let bridge = bridge else { return }

        if bridge.loadPreset(name) {
            vertexShaderSource = bridge.getVertexShaderSource()
            fragmentShaderSource = bridge.getFragmentShaderSource()
            statusMessage = "Loaded preset: \(name)"
        } else {
            statusMessage = "Failed to load preset: \(name)"
        }
    }

    /// Get available presets
    func availablePresets() -> [String] {
        return bridge?.availablePresets() as? [String] ?? []
    }

    /// Load shader from file
    func loadFromFile(_ url: URL, isVertex: Bool) {
        guard let bridge = bridge else { return }

        if bridge.loadShaderFromFile(url.path, isVertex: isVertex) {
            if isVertex {
                vertexShaderSource = bridge.getVertexShaderSource()
            } else {
                fragmentShaderSource = bridge.getFragmentShaderSource()
            }
            statusMessage = "Loaded shader from: \(url.lastPathComponent)"
        } else {
            statusMessage = "Failed to load shader from: \(url.lastPathComponent)"
        }
    }

    /// Save shader to file
    func saveToFile(_ url: URL, isVertex: Bool) {
        guard let bridge = bridge else { return }

        // Update bridge first
        bridge.setVertexShaderSource(vertexShaderSource)
        bridge.setFragmentShaderSource(fragmentShaderSource)

        if bridge.saveShaderToFile(url.path, isVertex: isVertex) {
            statusMessage = "Saved shader to: \(url.lastPathComponent)"
        } else {
            statusMessage = "Failed to save shader to: \(url.lastPathComponent)"
        }
    }

    // MARK: - Private Methods

    private func setupAutoCompile() {
        // Watch for source changes
        $vertexShaderSource
            .combineLatest($fragmentShaderSource, $autoCompile)
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] (_, _, autoCompile) in
                guard let self = self, autoCompile else { return }

                // Avoid compiling too frequently
                let timeSinceLastCompile = Date().timeIntervalSince(self.lastCompileTime)
                if timeSinceLastCompile > 0.5 {
                    self.lastCompileTime = Date()
                    self.compile()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}
