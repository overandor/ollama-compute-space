import SwiftUI
import AppKit

struct TerminalView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @StateObject private var vmManager = VMManager()
    @State private var terminalOutput: String = ""
    @State private var currentCommand: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var useVM = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // VM Controls
            HStack {
                Toggle("Ubuntu VM", isOn: $useVM)
                    .toggleStyle(.switch)
                
                if useVM {
                    Button(vmManager.isRunning ? "Stop VM" : "Start VM") {
                        Task {
                            if vmManager.isRunning {
                                try? await vmManager.stopVM()
                            } else {
                                try? await vmManager.startVM()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Circle()
                        .fill(vmManager.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                
                Button("Clear") {
                    terminalOutput = ""
                    vmManager.clearTerminal()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(terminalOutput)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: terminalOutput) { _ in
                    if let lastLine = terminalOutput.components(separatedBy: "\n").last {
                        withAnimation {
                            proxy.scrollTo(lastLine, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.black)
            
            // Command input
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                
                TextField("Enter command...", text: $currentCommand)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand(currentCommand)
                    }
                    .onChange(of: currentCommand) { newValue in
                        // Handle arrow keys for history
                    }
                
                Button("Execute") {
                    executeCommand(currentCommand)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            isInputFocused = true
            terminalOutput = "Ollama Terminal v1.0\nType 'help' for available commands\n\n"
        }
    }
    
    private func executeCommand(_ command: String) {
        guard !command.isEmpty else { return }
        
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        commandHistory.append(trimmedCommand)
        historyIndex = commandHistory.count
        
        terminalOutput += "$ \(trimmedCommand)\n"
        
        Task {
            let output: String
            if useVM && vmManager.isRunning {
                do {
                    output = try await vmManager.executeCommand(trimmedCommand)
                } catch {
                    output = "Error: \(error.localizedDescription)"
                }
            } else {
                output = await processCommand(trimmedCommand)
            }
            
            await MainActor.run {
                terminalOutput += output + "\n\n"
                currentCommand = ""
            }
        }
    }
    
    private func processCommand(_ command: String) async -> String {
        let parts = command.components(separatedBy: .whitespacesAndNewlines)
        let cmd = parts.first?.lowercased() ?? ""
        let args = Array(parts.dropFirst())
        
        switch cmd {
        case "help":
            return """
            Available commands:
            - help: Show this help message
            - list: List available models
            - pull <model>: Pull a model from Ollama
            - run <model> <prompt>: Run a model with a prompt
            - status: Show Ollama server status
            - memory: Show memory usage
            - clear: Clear terminal
            - exit: Exit terminal
            """
            
        case "list":
            if ollamaManager.models.isEmpty {
                return "No models available"
            }
            return ollamaManager.models.map { "\($0.name) (\(String(format: "%.1f GB", $0.sizeGB)))" }.joined(separator: "\n")
            
        case "pull":
            guard args.count >= 1 else { return "Usage: pull <model>" }
            let modelName = args[0]
            if let model = ollamaManager.models.first(where: { $0.name == modelName }) {
                do {
                    try await ollamaManager.pullModel(model)
                    return "Successfully pulled \(modelName)"
                } catch {
                    return "Failed to pull model: \(error.localizedDescription)"
                }
            } else {
                return "Model not found: \(modelName)"
            }
            
        case "run":
            guard args.count >= 2 else { return "Usage: run <model> <prompt>" }
            let modelName = args[0]
            let prompt = args.dropFirst().joined(separator: " ")
            
            if let model = ollamaManager.models.first(where: { $0.name == modelName }) {
                do {
                    let response = try await ollamaManager.generateResponse(prompt: prompt, model: model)
                    return response
                } catch {
                    return "Failed to generate response: \(error.localizedDescription)"
                }
            } else {
                return "Model not found: \(modelName)"
            }
            
        case "status":
            return ollamaManager.isRunning ? "Ollama server is running" : "Ollama server is not running"
            
        case "memory":
            // This would need to be passed from MemoryManager
            return "Memory info not available in terminal context"
            
        case "clear":
            await MainActor.run {
                terminalOutput = ""
            }
            return "Terminal cleared"
            
        case "exit":
            await MainActor.run {
                terminalOutput += "Goodbye!\n"
            }
            return "Exiting..."
            
        default:
            return "Unknown command: \(cmd). Type 'help' for available commands."
        }
    }
}
