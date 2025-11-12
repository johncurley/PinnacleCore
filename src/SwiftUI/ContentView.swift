import SwiftUI

struct ContentView: View {
    @State private var metalView = MetalView()

    var body: some View {
        metalView
            .onAppear {
                // Load a sample model. You might need to adjust the path.
                // For now, let's assume a model exists at this relative path.
                metalView.loadModel(filename: "Models/Box/glTF/Box.gltf")
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}