import Foundation
import SwiftUI

class OllamaManager: ObservableObject {
    @Published var isRunning = false
    @Published var models: [OllamaModel] = []
    @Published var currentModel: OllamaModel?
    @Published var serverURL = "http://localhost:11434"
    @Published var logs: [String] = []
    
    private var ollamaProcess: Process?
    private var bundledModelsPath: String {
        Bundle.main.resourcePath ?? ""
    }
    
    init() {
        loadBundledModels()
    }
    
    private func loadBundledModels() {
        // Simulate bundled models - in production, these would be actual GGUF files
        models = [
            OllamaModel(name: "llama3.2", sizeGB: 4.7, description: "Meta's Llama 3.2 - General purpose"),
            OllamaModel(name: "mistral", sizeGB: 4.1, description: "Mistral 7B - Efficient and capable"),
            OllamaModel(name: "codellama", sizeGB: 3.8, description: "Code Llama - Programming assistant"),
            OllamaModel(name: "phi3", sizeGB: 2.2, description: "Phi-3 Mini - Compact and fast"),
        ]
    }
    
    func startOllamaServer() async throws {
        guard !isRunning else { return }
        
        let ollamaPath = Bundle.main.path(forResource: "ollama", ofType: nil) ?? "/usr/local/bin/ollama"
        
        ollamaProcess = Process()
        ollamaProcess?.executableURL = URL(fileURLWithPath: ollamaPath)
        ollamaProcess?.arguments = ["serve"]
        
        let pipe = Pipe()
        ollamaProcess?.standardOutput = pipe
        ollamaProcess?.standardError = pipe
        
        ollamaProcess?.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.addLog("Ollama server stopped")
            }
        }
        
        try ollamaProcess?.run()
        
        await MainActor.run {
            isRunning = true
            addLog("Ollama server started")
        }
        
        // Wait for server to be ready
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await refreshModels()
    }
    
    func stopOllamaServer() {
        ollamaProcess?.terminate()
        ollamaProcess = nil
        isRunning = false
        addLog("Ollama server stopped")
    }
    
    func refreshModels() async {
        guard isRunning else { return }
        
        do {
            let url = URL(string: "\(serverURL)/api/tags")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let modelsArray = json["models"] as? [[String: Any]] {
                
                await MainActor.run {
                    self.models = modelsArray.compactMap { dict in
                        guard let name = dict["name"] as? String,
                              let size = dict["size"] as? Int64 else { return nil }
                        
                        let sizeGB = Double(size) / 1024.0 / 1024.0 / 1024.0
                        return OllamaModel(name: name, sizeGB: sizeGB, description: "Downloaded model")
                    }
                }
            }
        } catch {
            addLog("Failed to refresh models: \(error.localizedDescription)")
        }
    }
    
    func pullModel(_ model: OllamaModel) async throws {
        addLog("Pulling model: \(model.name)")
        
        let url = URL(string: "\(serverURL)/api/pull")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["name": model.name, "stream": false]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            addLog("Model \(model.name) pulled successfully")
            await refreshModels()
        } else {
            throw OllamaError.pullFailed
        }
    }
    
    func generateResponse(prompt: String, model: OllamaModel) async throws -> String {
        guard isRunning else { throw OllamaError.serverNotRunning }
        
        let url = URL(string: "\(serverURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model.name,
            "prompt": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let response = json["response"] as? String {
            return response
        }
        
        throw OllamaError.generationFailed
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            self.logs.append("[\(Date().timeIntervalSince1970)] \(message)")
        }
    }
}

struct OllamaModel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let sizeGB: Double
    var description: String
    var isDownloaded: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(id)
    }
    
    static func == (lhs: OllamaModel, rhs: OllamaModel) -> Bool {
        lhs.id == rhs.id || lhs.name == rhs.name
    }
}

enum OllamaError: Error {
    case serverNotRunning
    case pullFailed
    case generationFailed
    case modelNotFound
}
