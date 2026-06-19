import SwiftUI

@main
struct OllamaMacOSAppApp: App {
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var ollamaManager = OllamaManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(memoryManager)
                .environmentObject(ollamaManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
