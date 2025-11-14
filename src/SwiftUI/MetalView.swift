import SwiftUI

struct MetalView: NSViewRepresentable {
    let bridge = PinnacleMetalView(frame: .zero) // Instantiate the bridge object

    func makeNSView(context: Context) -> NSView {
        return bridge.getMetalContentView() // Return the underlying MTKView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update the view if needed
    }

    func loadModel(filename: String) {
        bridge.loadModel(filename)
    }
}