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
    
    private var huggingFaceAPIKey: String {
        ProcessInfo.processInfo.environment["HUGGINGFACE_API_KEY"] ?? ""
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
        
        // Try multiple paths for Ollama binary
        let possiblePaths = [
            Bundle.main.path(forResource: "ollama", ofType: nil),
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
            "/usr/bin/ollama"
        ]
        
        var ollamaPath: String?
        for path in possiblePaths {
            if let p = path, FileManager.default.fileExists(atPath: p) {
                ollamaPath = p
                addLog("Found Ollama at: \(p)")
                break
            }
        }
        
        guard let path = ollamaPath else {
            addLog("Error: Ollama binary not found. Tried paths: \(possiblePaths.compactMap { $0 }.joined(separator: ", "))")
            addLog("Please install Ollama from https://ollama.com or specify the path manually")
            throw OllamaError.serverNotRunning
        }
        
        ollamaProcess = Process()
        ollamaProcess?.executableURL = URL(fileURLWithPath: path)
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
        
        do {
            try ollamaProcess?.run()
            
            await MainActor.run {
                isRunning = true
                addLog("Ollama server started successfully")
            }
            
            // Wait for server to be ready
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await refreshModels()
        } catch {
            addLog("Failed to start Ollama server: \(error.localizedDescription)")
            throw error
        }
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                addLog("Ollama API returned status: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    addLog("Error response: \(errorString)")
                }
                throw OllamaError.generationFailed
            }
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let response = json["response"] as? String {
            return response
        }
        
        // Try to get error message from response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            addLog("Ollama error: \(error)")
            throw OllamaError.generationFailed
        }
        
        addLog("Failed to parse Ollama response")
        throw OllamaError.generationFailed
    }
    
    func generateMultipleResponses(prompt: String, model: OllamaModel, count: Int = 3) async throws -> [String] {
        guard isRunning else { throw OllamaError.serverNotRunning }
        guard count >= 3 && count <= 6 else { throw OllamaError.generationFailed }
        
        var responses: [String] = []
        var errors: [Error] = []
        
        // Generate responses in parallel
        await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
            for i in 0..<count {
                group.addTask {
                    do {
                        let response = try await self.generateResponse(prompt: prompt, model: model)
                        return (i, .success(response))
                    } catch {
                        return (i, .failure(error))
                    }
                }
            }
            
            for await (index, result) in group {
                switch result {
                case .success(let response):
                    responses.append(response)
                case .failure(let error):
                    errors.append(error)
                }
            }
        }
        
        // Sort responses by index to maintain order
        responses.sort()
        
        if responses.isEmpty {
            throw errors.first ?? OllamaError.generationFailed
        }
        
        return responses
    }
    
    func generateAndExecute(prompt: String, model: OllamaModel, allowExecution: Bool, workspacePath: String) async throws -> String {
        let systemPrompt = """
        You are an AI coding assistant. When the user asks you to create files or execute code, 
        respond with commands in this format:
        
        COMMAND: <command>
        
        For example:
        COMMAND: mkdir test_project
        COMMAND: write hello.py print("Hello World")
        COMMAND: exec python hello.py
        
        Available commands:
        - mkdir <path>: Create directory
        - write <file> <content>: Write content to file
        - exec <command>: Execute shell command
        
        Only use COMMAND format when the user explicitly asks you to create files or run code.
        Otherwise, respond normally.
        """
        
        let fullPrompt = "\(systemPrompt)\n\nUser: \(prompt)"
        let response = try await generateResponse(prompt: fullPrompt, model: model)
        
        guard allowExecution else {
            return response
        }
        
        // Parse and execute commands
        var output = response
        let lines = response.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("COMMAND:") {
                let command = line.replacingOccurrences(of: "COMMAND:", with: "").trimmingCharacters(in: .whitespaces)
                let execResult = try await executeCommand(command, workspacePath: workspacePath)
                output += "\n\nExecuted: \(command)\nResult: \(execResult)"
            }
        }
        
        return output
    }
    
    private func executeCommand(_ command: String, workspacePath: String) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        // Parse command
        let parts = command.components(separatedBy: .whitespaces)
        guard let cmd = parts.first else { throw OllamaError.generationFailed }
        let args = Array(parts.dropFirst())
        
        var fullCommand: String
        switch cmd {
        case "mkdir":
            let path = args.first?.hasPrefix("/") == true ? args[0] : "\(workspacePath)/\(args.first ?? "")"
            fullCommand = "mkdir -p \(path)"
        case "write":
            guard args.count >= 2 else { throw OllamaError.generationFailed }
            let file = args[0].hasPrefix("/") ? args[0] : "\(workspacePath)/\(args[0])"
            let content = args.dropFirst().joined(separator: " ")
            fullCommand = "echo '\(content)' > \(file)"
        case "exec":
            let shellCommand = args.joined(separator: " ")
            fullCommand = "cd \(workspacePath) && \(shellCommand)"
        default:
            fullCommand = command
        }
        
        task.arguments = ["-c", fullCommand]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        try task.run()
        task.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        if task.terminationStatus == 0 {
            return output.isEmpty ? "Success" : output
        } else {
            return "Error: \(error)"
        }
    }
    
    func testHuggingFaceAPI(apiKey: String? = nil) async throws -> String {
        let key = apiKey ?? huggingFaceAPIKey
        guard !key.isEmpty else { throw OllamaError.invalidAPIKey }
        
        let url = URL(string: "https://api-inference.huggingface.co/models/gpt2")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "inputs": "Hello, I'm testing the API."
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                addLog("Hugging Face API test successful")
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let firstResult = json.first,
                   let generatedText = firstResult["generated_text"] as? String {
                    return generatedText
                }
                return "API key valid - request succeeded"
            } else if httpResponse.statusCode == 401 {
                throw OllamaError.invalidAPIKey
            } else {
                addLog("Hugging Face API returned status: \(httpResponse.statusCode)")
                throw OllamaError.apiRequestFailed
            }
        }
        
        throw OllamaError.apiRequestFailed
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
    case invalidAPIKey
    case apiRequestFailed
}
