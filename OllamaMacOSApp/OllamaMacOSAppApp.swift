import SwiftUI

// Wrapper classes to allow deferred initialization with shared instances
class AIAgentWrapper: ObservableObject {
    @Published var agent: AIAgent = AIAgent(ollamaManager: OllamaManager(), vmManager: VMManager(), memoryManager: MemoryManager())
    
    func initialize(ollamaManager: OllamaManager, vmManager: VMManager, memoryManager: MemoryManager) {
        agent = AIAgent(ollamaManager: ollamaManager, vmManager: vmManager, memoryManager: memoryManager)
    }
}

class AutonomousAgentWrapper: ObservableObject {
    @Published var agent: AutonomousAgent = AutonomousAgent(ollamaManager: OllamaManager())
    
    func initialize(ollamaManager: OllamaManager) {
        agent = AutonomousAgent(ollamaManager: ollamaManager)
    }
}

@main
struct OllamaMacOSAppApp: App {
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var ollamaManager = OllamaManager()
    @StateObject private var vmManager = VMManager()
    @StateObject private var aiAgent = AIAgentWrapper()
    @StateObject private var autonomousAgent = AutonomousAgentWrapper()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(memoryManager)
                .environmentObject(ollamaManager)
                .environmentObject(vmManager)
                .environmentObject(aiAgent.agent)
                .environmentObject(autonomousAgent.agent)
                .onAppear {
                    // Initialize agents with shared instances
                    aiAgent.initialize(ollamaManager: ollamaManager, vmManager: vmManager, memoryManager: memoryManager)
                    autonomousAgent.initialize(ollamaManager: ollamaManager)
                    
                    // Auto-start Ollama server on app launch with retry mechanism
                    Task {
                        // Wait for app to fully load
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        
                        // Retry up to 3 times
                        for attempt in 1...3 {
                            if ollamaManager.isRunning {
                                print("Ollama server is already running")
                                break
                            }
                            
                            do {
                                print("Auto-start attempt \(attempt)/3")
                                try await ollamaManager.startOllamaServer()
                                print("Ollama server started successfully on attempt \(attempt)")
                                break
                            } catch {
                                print("Attempt \(attempt) failed: \(error)")
                                if attempt < 3 {
                                    // Wait before retry
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                } else {
                                    print("Failed to auto-start Ollama server after 3 attempts")
                                }
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
