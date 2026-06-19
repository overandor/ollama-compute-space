import SwiftUI
import AppKit

struct TerminalView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @StateObject private var vmManager = VMManager()
    @State private var autonomousAgent: AutonomousAgent?
    @State private var terminalOutput: String = ""
    @State private var currentCommand: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var useVM = false
    @State private var allowCodeExecution = false
    @State private var autonomousMode = false
    @State private var chatMode = false
    @State private var multiResponseMode = false
    @State private var responseCount: Int = 3
    @State private var pendingResponses: [String] = []
    @State private var awaitingResponseSelection = false
    @State private var chatModel: String = "llama3.2"
    @State private var workspacePath: String = "/tmp/ollama-workspace"
    @State private var parallelAgentsMode = false
    @State private var parallelAgents: [AutonomousAgent] = []
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
                
                Toggle("Code Execution", isOn: $allowCodeExecution)
                    .toggleStyle(.switch)
                    .help("Allow LLM to create folders and execute code")
                
                if allowCodeExecution {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
                
                Toggle("Autonomous Mode", isOn: $autonomousMode)
                    .toggleStyle(.switch)
                    .help("Enable autonomous LLM agent that works without prompts")
                
                if autonomousMode {
                    Button(autonomousAgent?.isRunning == true ? "Stop Agent" : "Start Agent") {
                        if autonomousAgent?.isRunning == true {
                            autonomousAgent?.stop()
                        } else {
                            if let model = ollamaManager.models.first {
                                autonomousAgent = AutonomousAgent(ollamaManager: ollamaManager, workspacePath: workspacePath)
                                autonomousAgent?.start(model: model, objective: "Explore and create useful tools")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Circle()
                        .fill(autonomousAgent?.isRunning == true ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Toggle("Chat Mode", isOn: $chatMode)
                    .toggleStyle(.switch)
                    .help("Chat directly with LLM in terminal")
                
                if chatMode {
                    Picker("Model", selection: $chatModel) {
                        ForEach(ollamaManager.models, id: \.name) { model in
                            Text(model.name).tag(model.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    
                    Toggle("Multi-Response", isOn: $multiResponseMode)
                        .toggleStyle(.switch)
                        .help("Generate 3-6 responses to choose from")
                    
                    if multiResponseMode {
                        Picker("Count", selection: $responseCount) {
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("5").tag(5)
                            Text("6").tag(6)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 60)
                    }
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
                
                Toggle("Parallel Agents", isOn: $parallelAgentsMode)
                    .toggleStyle(.switch)
                    .help("Run 6 autonomous agents in parallel")
                
                if parallelAgentsMode {
                    Button(parallelAgents.isEmpty ? "Start 6 Agents" : "Stop Agents") {
                        if parallelAgents.isEmpty {
                            startParallelAgents()
                        } else {
                            stopParallelAgents()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("\(parallelAgents.count) agents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(parallelAgents.allSatisfy { $0.isRunning } ? Color.green : Color.orange)
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
        .onChange(of: autonomousAgent?.logs) { _ in
            if let agent = autonomousAgent, !agent.logs.isEmpty {
                let newLogs = agent.logs.suffix(5)
                for log in newLogs {
                    terminalOutput += "[AUTONOMOUS] \(log)\n"
                }
            }
        }
        .onChange(of: autonomousAgent?.currentTask) { _ in
            if let agent = autonomousAgent, !agent.currentTask.isEmpty {
                terminalOutput += "[AUTONOMOUS] Current task: \(agent.currentTask)\n"
            }
        }
    }
    
    private func executeCommand(_ command: String) {
        guard !command.isEmpty else { return }
        
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        commandHistory.append(trimmedCommand)
        historyIndex = commandHistory.count
        
        // Handle response selection
        if awaitingResponseSelection {
            if trimmedCommand.lowercased() == "retry" {
                awaitingResponseSelection = false
                pendingResponses = []
                terminalOutput += "Regenerating responses...\n"
                Task {
                    let output = await chatWithLLM(commandHistory[commandHistory.count - 2])
                    await MainActor.run {
                        terminalOutput += output + "\n\n"
                        currentCommand = ""
                    }
                }
                return
            } else if let index = Int(trimmedCommand), index >= 1 && index <= pendingResponses.count {
                let selectedResponse = pendingResponses[index - 1]
                terminalOutput += "Selected response [\(index)]: \(selectedResponse)\n\n"
                awaitingResponseSelection = false
                pendingResponses = []
                currentCommand = ""
                return
            } else {
                terminalOutput += "Invalid selection. Please enter a number between 1 and \(pendingResponses.count), or 'retry'.\n\n"
                currentCommand = ""
                return
            }
        }
        
        // In chat mode, send directly to LLM
        if chatMode {
            terminalOutput += "You: \(trimmedCommand)\n"
            Task {
                let output = await chatWithLLM(trimmedCommand)
                await MainActor.run {
                    terminalOutput += "AI: \(output)\n\n"
                    currentCommand = ""
                }
            }
            return
        }
        
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
    
    private func chatWithLLM(_ prompt: String) async -> String {
        // Auto-start Ollama server if not running
        if !ollamaManager.isRunning {
            do {
                try await ollamaManager.startOllamaServer()
                terminalOutput += "[SYSTEM] Ollama server auto-started\n"
            } catch {
                return "Error: Failed to start Ollama server: \(error.localizedDescription)"
            }
        }
        
        // Find the selected model
        let modelName = chatModel
        
        // Check if models are available
        if ollamaManager.models.isEmpty {
            return "Error: No models available. Please pull a model first using 'pull <model>' command."
        }
        
        // Match model name with or without version tag (e.g., "mistral" matches "mistral:latest")
        let modelNameWithoutTag = modelName.components(separatedBy: ":").first ?? modelName
        guard let model = ollamaManager.models.first(where: { availableModel in
            let availableNameWithoutTag = availableModel.name.components(separatedBy: ":").first ?? availableModel.name
            return availableNameWithoutTag == modelNameWithoutTag
        }) else {
            return "Error: Model '\(modelName)' not found. Available models: \(ollamaManager.models.map { $0.name }.joined(separator: ", ")). Please pull the model first."
        }
        
        do {
            if multiResponseMode {
                let responses = try await ollamaManager.generateMultipleResponses(prompt: prompt, model: model, count: responseCount)
                await MainActor.run {
                    pendingResponses = responses
                    awaitingResponseSelection = true
                }
                var output = "Generated \(responseCount) responses:\n\n"
                for (index, response) in responses.enumerated() {
                    output += "[\(index + 1)] \(response)\n\n"
                }
                output += "Type a number (1-\(responseCount)) to select a response, or 'retry' to regenerate."
                return output
            } else {
                let response = try await ollamaManager.generateResponse(prompt: prompt, model: model)
                return response
            }
        } catch OllamaError.serverNotRunning {
            return "Error: Ollama server is not running. Please start the Ollama server first."
        } catch OllamaError.modelNotFound {
            return "Error: Model not found. Please pull the model first."
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func startParallelAgents() {
        guard allowCodeExecution else { return }
        guard ollamaManager.isRunning else { return }
        guard let model = ollamaManager.models.first else { return }
        
        parallelAgents.removeAll()
        
        for i in 1...6 {
            let agent = AutonomousAgent(ollamaManager: ollamaManager, workspacePath: "\(workspacePath)/agent\(i)")
            agent.start(model: model, objective: "Agent \(i): Explore and create useful tools in parallel")
            parallelAgents.append(agent)
        }
        
        terminalOutput += "\n[PARALLEL] Started 6 autonomous agents in parallel\n"
    }
    
    private func stopParallelAgents() {
        for agent in parallelAgents {
            agent.stop()
        }
        parallelAgents.removeAll()
        terminalOutput += "\n[PARALLEL] Stopped all parallel agents\n"
    }
    
    private func resetToInitialState() -> String {
        // Stop all agents
        autonomousAgent?.stop()
        autonomousAgent = nil
        stopParallelAgents()
        
        // Stop Ollama server
        ollamaManager.stopOllamaServer()
        
        // Reset all toggles
        useVM = false
        allowCodeExecution = false
        autonomousMode = false
        chatMode = false
        multiResponseMode = false
        responseCount = 3
        parallelAgentsMode = false
        
        // Clear pending responses
        pendingResponses = []
        awaitingResponseSelection = false
        
        // Clear terminal
        terminalOutput = ""
        commandHistory = []
        historyIndex = -1
        currentCommand = ""
        
        // Reset workspace
        workspacePath = "/tmp/ollama-workspace"
        
        return "Reset to initial state. All processes stopped and settings reset."
    }
    
    private func processCommand(_ command: String) async -> String {
        let parts = command.components(separatedBy: .whitespacesAndNewlines)
        let cmd = parts.first?.lowercased() ?? ""
        let args = Array(parts.dropFirst())
        
        switch cmd {
        case "start":
            // Start Ollama server
            Task {
                do {
                    try await ollamaManager.startOllamaServer()
                    await MainActor.run {
                        terminalOutput += "Ollama server started successfully\n\n"
                    }
                } catch {
                    await MainActor.run {
                        terminalOutput += "Failed to start Ollama server: \(error.localizedDescription)\n\n"
                    }
                }
            }
            return "Starting Ollama server..."
            
        case "stop":
            // Stop Ollama server
            ollamaManager.stopOllamaServer()
            return "Ollama server stopped"
            
        case "reset":
            // Reset everything to initial state
            return resetToInitialState()
            
        case "help":
            return """
            Available commands:
            - help: Show this help message
            - start: Start Ollama server
            - stop: Stop Ollama server
            - reset: Reset everything to initial state
            - list: List available models
            - pull <model>: Pull a model from Ollama
            - run <model> <prompt>: Run a model with a prompt
            - status: Show Ollama server status
            - memory: Show memory usage
            - clear: Clear terminal
            - exit: Exit terminal
            - mkdir <path>: Create directory (requires code execution)
            - write <file> <content>: Write content to file (requires code execution)
            - exec <command>: Execute shell command (requires code execution)
            - workspace: Show/set workspace path
            - auto: Toggle autonomous agent (on/off/status)
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
                    let response: String
                    if allowCodeExecution {
                        response = try await ollamaManager.generateAndExecute(
                            prompt: prompt,
                            model: model,
                            allowExecution: true,
                            workspacePath: workspacePath
                        )
                    } else {
                        response = try await ollamaManager.generateResponse(prompt: prompt, model: model)
                    }
                    return response
                } catch {
                    return "Failed to generate response: \(error.localizedDescription)"
                }
            } else {
                return "Model not found: \(modelName)"
            }
            
        case "status":
            let daemonStatus = checkDaemonStatus()
            let serverStatus = ollamaManager.isRunning ? "Ollama server is running" : "Ollama server is not running"
            return "\(daemonStatus)\n\(serverStatus)"
            
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
            
        case "mkdir":
            guard allowCodeExecution else { return "Error: Code execution is disabled. Enable 'Code Execution' toggle to use this command." }
            guard args.count >= 1 else { return "Usage: mkdir <path>" }
            let path = args[0].hasPrefix("/") ? args[0] : "\(workspacePath)/\(args[0])"
            return await executeShellCommand("mkdir -p \(path)")
            
        case "write":
            guard allowCodeExecution else { return "Error: Code execution is disabled. Enable 'Code Execution' toggle to use this command." }
            guard args.count >= 2 else { return "Usage: write <file> <content>" }
            let file = args[0].hasPrefix("/") ? args[0] : "\(workspacePath)/\(args[0])"
            let content = args.dropFirst().joined(separator: " ")
            return await executeShellCommand("echo '\(content)' > \(file)")
            
        case "exec":
            guard allowCodeExecution else { return "Error: Code execution is disabled. Enable 'Code Execution' toggle to use this command." }
            guard args.count >= 1 else { return "Usage: exec <command>" }
            let command = args.joined(separator: " ")
            return await executeShellCommand("cd \(workspacePath) && \(command)")
            
        case "workspace":
            if args.count >= 1 {
                workspacePath = args[0]
                // Create workspace if it doesn't exist
                _ = await executeShellCommand("mkdir -p \(workspacePath)")
                return "Workspace set to: \(workspacePath)"
            } else {
                return "Current workspace: \(workspacePath)"
            }
            
        case "auto":
            guard allowCodeExecution else { return "Error: Enable 'Code Execution' first" }
            
            // Check if Ollama server is running
            guard ollamaManager.isRunning else {
                return "Error: Ollama server is not running. Please start the Ollama server first using the Dashboard."
            }
            
            if args.isEmpty {
                // Toggle or show status
                if let agent = autonomousAgent {
                    if agent.isRunning {
                        agent.stop()
                        return "Autonomous agent stopped"
                    } else {
                        return """
                        Autonomous Agent Status:
                        Running: \(agent.isRunning)
                        Current Task: \(agent.currentTask.isEmpty ? "None" : agent.currentTask)
                        Completed Tasks: \(agent.completedTasks)
                        Tasks in Queue: \(agent.taskQueue.count)
                        """
                    }
                } else {
                    // Start if not initialized
                    if let model = ollamaManager.models.first {
                        autonomousAgent = AutonomousAgent(ollamaManager: ollamaManager, workspacePath: workspacePath)
                        autonomousAgent?.start(model: model, objective: "Explore and create useful tools")
                        return "Autonomous agent started with model: \(model.name)"
                    } else {
                        return "Error: No models available. Please pull a model first using 'pull <model>' command."
                    }
                }
            } else {
                let subcommand = args[0].lowercased()
                switch subcommand {
                case "on", "start":
                    if let model = ollamaManager.models.first {
                        autonomousAgent = AutonomousAgent(ollamaManager: ollamaManager, workspacePath: workspacePath)
                        autonomousAgent?.start(model: model, objective: "Explore and create useful tools")
                        return "Autonomous agent started with model: \(model.name)"
                    } else {
                        return "Error: No models available. Please pull a model first using 'pull <model>' command."
                    }
                    
                case "off", "stop":
                    autonomousAgent?.stop()
                    return "Autonomous agent stopped"
                    
                default:
                    return "Usage: auto [on|off]"
                }
            }
            
        default:
            return "Unknown command: \(cmd). Type 'help' for available commands."
        }
    }
    
    private func executeShellCommand(_ command: String) async -> String {
        // Safety sandbox validation
        guard validateCommandSafety(command) else {
            return "Error: Command blocked by safety sandbox. Dangerous or unauthorized commands are not allowed."
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        
        // Restrict environment for safety
        task.environment = [
            "PATH": "/usr/bin:/bin:/usr/local/bin",
            "HOME": workspacePath
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            if task.terminationStatus == 0 {
                return output.isEmpty ? "Command executed successfully" : output
            } else {
                return "Error (exit code \(task.terminationStatus)): \(error)"
            }
        } catch {
            return "Failed to execute command: \(error.localizedDescription)"
        }
    }
    
    private func validateCommandSafety(_ command: String) -> Bool {
        let dangerousPatterns = [
            "rm -rf /",
            "rm -rf ~",
            "rm -rf /usr",
            "rm -rf /System",
            "rm -rf /bin",
            "rm -rf /sbin",
            "sudo",
            "su ",
            "chmod 777 /",
            "chown",
            "dd if=",
            ":(){:|:&};:",
            "mkfs",
            "format",
            "fdisk",
            "shutdown",
            "reboot",
            "halt",
            "poweroff",
            "killall",
            "pkill",
            "kill -9",
            "> /dev/",
            "> /etc/",
            "> /usr/",
            "> /System/",
            "curl.*|.*sh",
            "wget.*|.*sh",
            "eval.*\\$",
            "exec.*\\$",
            "\\$\\(",
            "`.*`"
        ]
        
        for pattern in dangerousPatterns {
            if command.range(of: pattern, options: .regularExpression) != nil {
                return false
            }
        }
        
        // Ensure command doesn't try to escape workspace
        if command.contains("..") && (command.contains("cd") || command.contains("mv") || command.contains("cp")) {
            return false
        }
        
        // Block network access for safety
        if command.contains("curl") || command.contains("wget") || command.contains("nc ") || command.contains("netcat") {
            return false
        }
        
        return true
    }
    
    private func checkDaemonStatus() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["list", "com.ollamamacos.daemon"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus == 0 && !output.isEmpty {
                return "✓ Ollama daemon is running (PID: \(output.trimmingCharacters(in: .whitespaces)))"
            } else {
                return "✗ Ollama daemon is not running"
            }
        } catch {
            return "✗ Failed to check daemon status: \(error.localizedDescription)"
        }
    }
}
