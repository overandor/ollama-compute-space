import Foundation

class AutonomousAgent: ObservableObject {
    @Published var isRunning = false
    @Published var currentTask: String = ""
    @Published var taskHistory: [String] = []
    @Published var completedTasks: Int = 0
    @Published var logs: [String] = []
    
    private var ollamaManager: OllamaManager
    private var workspacePath: String
    private var currentModel: OllamaModel?
    private var executionTimer: Timer?
    var taskQueue: [String] = []
    
    init(ollamaManager: OllamaManager, workspacePath: String = "/tmp/ollama-workspace") {
        self.ollamaManager = ollamaManager
        self.workspacePath = workspacePath
    }
    
    func start(model: OllamaModel, objective: String = "Explore and create useful tools") {
        guard !isRunning else { return }
        
        // Auto-start Ollama server if not running
        Task {
            if !ollamaManager.isRunning {
                do {
                    try await ollamaManager.startOllamaServer()
                    addLog("Ollama server auto-started for autonomous agent")
                } catch {
                    addLog("Error: Failed to start Ollama server: \(error.localizedDescription)")
                    return
                }
            }
            
            await MainActor.run {
                currentModel = model
                isRunning = true
                addLog("Autonomous agent started with objective: \(objective)")
                addLog("Using model: \(model.name)")
                
                // Generate initial tasks
                Task {
                    await generateTasks(objective: objective)
                    startExecutionLoop()
                }
            }
        }
    }
    
    func stop() {
        isRunning = false
        executionTimer?.invalidate()
        executionTimer = nil
        addLog("Autonomous agent stopped")
    }
    
    private func generateTasks(objective: String) async {
        let prompt = """
        You are an autonomous AI agent with the objective: \(objective)
        
        Generate 3-5 specific, actionable tasks to work toward this objective.
        Each task should be something you can execute using these commands:
        - mkdir <path>: Create directory
        - write <file> <content>: Write content to file
        - exec <command>: Execute shell command
        
        Format your response as a numbered list:
        1. Task description
        2. Task description
        3. Task description
        
        Keep tasks focused and achievable.
        """
        
        do {
            guard let model = currentModel else {
                addLog("Error: No model selected")
                stop()
                return
            }
            
            addLog("Checking Ollama server status...")
            guard ollamaManager.isRunning else {
                addLog("Error: Ollama server is not running")
                stop()
                return
            }
            
            addLog("Checking if model \(model.name) is available...")
            if ollamaManager.models.isEmpty {
                addLog("Error: No models loaded in OllamaManager")
                addLog("Available models count: \(ollamaManager.models.count)")
                stop()
                return
            }
            
            if !ollamaManager.models.contains(where: { $0.name == model.name }) {
                addLog("Error: Model \(model.name) not found in available models")
                addLog("Available models: \(ollamaManager.models.map { $0.name }.joined(separator: ", "))")
                stop()
                return
            }
            
            addLog("Generating tasks using model: \(model.name)...")
            addLog("Available models: \(ollamaManager.models.map { $0.name }.joined(separator: ", "))")
            
            let response = try await ollamaManager.generateResponse(prompt: prompt, model: model)
            
            await MainActor.run {
                parseTasksFromResponse(response)
                addLog("Generated \(taskQueue.count) tasks")
            }
        } catch OllamaError.serverNotRunning {
            addLog("Error: Ollama server is not running")
            stop()
        } catch OllamaError.modelNotFound {
            addLog("Error: Model not found. Please pull the model first.")
            stop()
        } catch {
            addLog("Failed to generate tasks: \(error.localizedDescription)")
            addLog("Error type: \(type(of: error))")
            stop()
        }
    }
    
    private func parseTasksFromResponse(_ response: String) {
        taskQueue.removeAll()
        let lines = response.components(separatedBy: "\n")
        
        for line in lines {
            if line.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                let task = line.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                if !task.isEmpty {
                    taskQueue.append(task.trimmingCharacters(in: .whitespaces))
                }
            }
        }
    }
    
    private func startExecutionLoop() {
        executionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.executeNextTask()
            }
        }
    }
    
    private func executeNextTask() async {
        guard isRunning, !taskQueue.isEmpty else {
            if taskQueue.isEmpty && isRunning {
                // Generate new tasks when queue is empty
                await generateNewTasks()
            }
            return
        }
        
        let task = taskQueue.removeFirst()
        await MainActor.run {
            currentTask = task
            taskHistory.append(task)
            addLog("Starting task: \(task)")
        }
        
        let prompt = """
        You are executing this task: \(task)
        
        Use COMMAND format to execute the task:
        COMMAND: mkdir <path>
        COMMAND: write <file> <content>
        COMMAND: exec <command>
        
        Execute the task step by step. Report your progress.
        """
        
        do {
            guard let model = currentModel else { return }
            let response = try await ollamaManager.generateAndExecute(
                prompt: prompt,
                model: model,
                allowExecution: true,
                workspacePath: workspacePath
            )
            
            await MainActor.run {
                addLog("Task completed: \(task)")
                addLog("Result: \(response)")
                completedTasks += 1
                currentTask = ""
            }
        } catch {
            await MainActor.run {
                addLog("Task failed: \(task) - \(error.localizedDescription)")
                currentTask = ""
            }
        }
    }
    
    private func generateNewTasks() async {
        let prompt = """
        You have completed \(completedTasks) tasks. 
        Your task history: \(taskHistory.suffix(5).joined(separator: ", "))
        
        Generate 3 new tasks to continue your work. Focus on:
        1. Building on what you've created
        2. Testing and improving existing work
        3. Exploring new useful tools
        
        Format as numbered list.
        """
        
        do {
            guard let model = currentModel else { return }
            let response = try await ollamaManager.generateResponse(prompt: prompt, model: model)
            
            await MainActor.run {
                parseTasksFromResponse(response)
                addLog("Generated \(taskQueue.count) new tasks")
            }
        } catch {
            addLog("Failed to generate new tasks: \(error.localizedDescription)")
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logs.append("[\(timestamp)] \(message)")
    }
}
