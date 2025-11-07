import SwiftUI
import MetalKit

// This struct acts as a bridge to integrate our existing MetalView (an NSView subclass)
// into a SwiftUI view hierarchy.
struct MetalViewContainer: NSViewRepresentable {
    // We need a way to communicate with the MetalView from SwiftUI, e.g., to load models.
    // This will be a binding to a path that the MetalView can observe.
    @Binding var modelPath: String?
    
    // The actual MetalView instance that will be managed by this container.
    private let metalView = MetalView()

    func makeNSView(context: Context) -> MetalView {
        // Return the MetalView instance.
        return metalView
    }

    func updateNSView(_ nsView: MetalView, context: Context) {
        // Update the NSView when SwiftUI state changes.
        // For example, if modelPath changes, tell the MetalView to load a new model.
        if let path = modelPath {
            // Renamed from loadModelAtPath to loadModel(atPath:)
            nsView.loadModel(atPath: path)
            // Reset modelPath after loading to avoid re-loading on every update
            DispatchQueue.main.async { modelPath = nil }
        }
    }
    
    // Expose a method to get the underlying MetalView instance if needed for direct calls
    func getMetalView() -> MetalView {
        return metalView
    }
}