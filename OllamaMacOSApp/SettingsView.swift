import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @EnvironmentObject var memoryManager: MemoryManager
    @State private var serverURL: String = "http://localhost:11434"
    @State private var maxMemoryGB: Double = 8.0
    @State private var autoStartServer: Bool = true
    @State private var enableMemoryWarnings: Bool = true
    @State private var hfAPIKey: String = ""
    @State private var testResult: String = ""
    @State private var isTesting: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Ollama Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ollama Server")
                        .font(.headline)
                    
                    HStack {
                        Text("Server URL:")
                        TextField("http://localhost:11434", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    
                    Toggle("Auto-start server on launch", isOn: $autoStartServer)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Memory Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Memory Management")
                        .font(.headline)
                    
                    VStack(alignment: .leading) {
                        Text("Maximum Memory for App: \(String(format: "%.1f GB", maxMemoryGB))")
                            .font(.caption)
                        
                        Slider(value: $maxMemoryGB, in: 1.0...32.0, step: 0.5)
                    }
                    
                    Toggle("Enable memory warnings", isOn: $enableMemoryWarnings)
                    
                    Text("Available system memory: \(String(format: "%.1f GB", memoryManager.availableMemoryGB))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Model Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Model Settings")
                        .font(.headline)
                    
                    Text("Bundled models will be installed in:")
                        .font(.caption)
                    
                    Text(Bundle.main.resourcePath ?? "~/Library/Application Support/OllamaMacOSApp/models")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Hugging Face API Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hugging Face API")
                        .font(.headline)
                    
                    VStack(alignment: .leading) {
                        Text("API Key:")
                            .font(.caption)
                        SecureField("Enter your Hugging Face API key", text: $hfAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Button("Test API Key") {
                            Task {
                                isTesting = true
                                testResult = ""
                                do {
                                    let result = try await ollamaManager.testHuggingFaceAPI(apiKey: hfAPIKey)
                                    testResult = "✓ Success: \(result)"
                                } catch {
                                    testResult = "✗ Failed: \(error.localizedDescription)"
                                }
                                isTesting = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(hfAPIKey.isEmpty || isTesting)
                        
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.hasPrefix("✓") ? .green : .red)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // About
                VStack(alignment: .leading, spacing: 10) {
                    Text("About")
                        .font(.headline)
                    
                    Text("Ollama Compute Space")
                        .font(.subheadline)
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Local AI compute environment with managed memory allocation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}
