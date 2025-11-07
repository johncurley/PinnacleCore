import SwiftUI

struct ContentView: View {
    @State private var selectedModelPath: String? = nil

    var body: some View {
        VStack {
            MetalViewContainer(modelPath: $selectedModelPath)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button("Load Model") {
                let openPanel = NSOpenPanel()
                openPanel.allowedFileTypes = ["gltf", "glb"]
                openPanel.canChooseDirectories = false
                openPanel.canChooseFiles = true
                openPanel.allowsMultipleSelection = false

                openPanel.begin {
                    response in
                    if response == .OK {
                        if let url = openPanel.url {
                            selectedModelPath = url.path
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
