import Foundation
import SwiftUI

class AIAgent: ObservableObject {
    @Published var isActive = false
    @Published var currentTask: String = ""
    @Published var status: AgentStatus = .idle
    @Published var messages: [AgentMessage] = []
    @Published var plan: [AgentStep] = []
    @Published var currentStepIndex = 0
    @Published var executionHistory: [ExecutionResult] = []
    
    private var ollamaManager: OllamaManager
    private var vmManager: VMManager
    private var memoryManager: MemoryManager
    private var executionTimer: Timer?
    
    enum AgentStatus {
        case idle
        case planning
        case executing
        case waiting
        case completed
        case failed
    }
    
    init(ollamaManager: OllamaManager, vmManager: VMManager, memoryManager: MemoryManager) {
        self.ollamaManager = ollamaManager
        self.vmManager = vmManager
        self.memoryManager = memoryManager
    }
    
    func startTask(_ task: String) async {
        await MainActor.run {
            currentTask = task
            isActive = true
            status = .planning
            messages.append(AgentMessage(
                role: .user,
                content: task,
                timestamp: Date()
            ))
        }
        
        // Generate plan using Ollama
        await generatePlan(for: task)
        
        // Execute plan
        await executePlan()
    }
    
    private func generatePlan(for task: String) async {
        await MainActor.run {
            status = .planning
            messages.append(AgentMessage(
                role: .system,
                content: "Generating execution plan...",
                timestamp: Date()
            ))
        }
        
        let prompt = """
        You are an autonomous AI agent similar to Devin. Your task is to: \(task)
        
        Available tools:
        - execute_command: Run shell commands in Ubuntu VM
        - read_file: Read file contents
        - write_file: Write content to a file
        - list_directory: List directory contents
        - search_files: Search for files matching a pattern
        - edit_file: Edit specific parts of a file
        
        Please break down this task into specific steps. For each step, specify:
        1. The action to take
        2. The command or file operation
        3. Expected outcome
        
        Respond in JSON format with a "steps" array containing step objects with "action", "command", and "description" fields.
        """
        
        do {
            let response = try await ollamaManager.generateResponse(
                prompt: prompt,
                model: ollamaManager.models.first ?? OllamaModel(name: "llama3.2", sizeGB: 4.7, description: "")
            )
            
            await MainActor.run {
                messages.append(AgentMessage(
                    role: .assistant,
                    content: response,
                    timestamp: Date()
                ))
                
                // Parse plan from response
                parsePlan(from: response)
            }
        } catch {
            await MainActor.run {
                status = .failed
                messages.append(AgentMessage(
                    role: .system,
                    content: "Failed to generate plan: \(error.localizedDescription)",
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func parsePlan(from response: String) {
        // Simple parsing - in production, use proper JSON parsing
        let lines = response.components(separatedBy: "\n")
        var steps: [AgentStep] = []
        var currentStep: AgentStep?
        
        for line in lines {
            if line.contains("Step") || line.contains("-") {
                if let step = currentStep {
                    steps.append(step)
                }
                currentStep = AgentStep(
                    id: UUID(),
                    action: .command,
                    command: "",
                    description: line.trimmingCharacters(in: .init(charactersIn: "-0123456789. "))
                )
            } else if line.lowercased().contains("command") || line.lowercased().contains("run") {
                currentStep?.action = .command
                currentStep?.command = line
            } else if line.lowercased().contains("file") {
                currentStep?.action = .file
                currentStep?.command = line
            }
        }
        
        if let step = currentStep {
            steps.append(step)
        }
        
        self.plan = steps
        currentStepIndex = 0
    }
    
    private func executePlan() async {
        await MainActor.run {
            status = .executing
        }
        
        for (index, step) in plan.enumerated() {
            await MainActor.run {
                currentStepIndex = index
                messages.append(AgentMessage(
                    role: .system,
                    content: "Executing step \(index + 1): \(step.description)",
                    timestamp: Date()
                ))
            }
            
            let result = await executeStep(step)
            
            await MainActor.run {
                executionHistory.append(result)
                
                if result.success {
                    messages.append(AgentMessage(
                        role: .system,
                        content: "Step completed: \(result.output)",
                        timestamp: Date()
                    ))
                } else {
                    messages.append(AgentMessage(
                        role: .system,
                        content: "Step failed: \(result.error)",
                        timestamp: Date()
                    ))
                    status = .failed
                    return
                }
            }
        }
        
        await MainActor.run {
            status = .completed
            messages.append(AgentMessage(
                role: .system,
                content: "Task completed successfully",
                timestamp: Date()
            ))
        }
    }
    
    private func executeStep(_ step: AgentStep) async -> ExecutionResult {
        do {
            switch step.action {
            case .command:
                let output = try await vmManager.executeCommand(step.command)
                return ExecutionResult(
                    stepId: step.id,
                    success: true,
                    output: output,
                    error: ""
                )
                
            case .file:
                // Parse file operation from command
                if step.command.contains("read") {
                    let path = extractPath(from: step.command)
                    let content = try await vmManager.getFileContent(path: path)
                    return ExecutionResult(
                        stepId: step.id,
                        success: true,
                        output: content,
                        error: ""
                    )
                } else if step.command.contains("write") {
                    let (path, content) = extractWriteInfo(from: step.command)
                    try await vmManager.writeFile(path: path, content: content)
                    return ExecutionResult(
                        stepId: step.id,
                        success: true,
                        output: "File written successfully",
                        error: ""
                    )
                } else {
                    return ExecutionResult(
                        stepId: step.id,
                        success: false,
                        output: "",
                        error: "Unknown file operation"
                    )
                }
            }
        } catch {
            return ExecutionResult(
                stepId: step.id,
                success: false,
                output: "",
                error: error.localizedDescription
            )
        }
    }
    
    private func extractPath(from command: String) -> String {
        // Simple path extraction
        let components = command.components(separatedBy: " ")
        return components.last ?? "~"
    }
    
    private func extractWriteInfo(from command: String) -> (path: String, content: String) {
        // Simple extraction - enhance in production
        let components = command.components(separatedBy: " ")
        let path = components.count > 1 ? components[1] : "~/file.txt"
        let content = components.count > 2 ? components[2...] .joined(separator: " ") : ""
        return (path, content)
    }
    
    func stop() {
        isActive = false
        status = .idle
        executionTimer?.invalidate()
    }
    
    func addMessage(_ message: String) {
        messages.append(AgentMessage(
            role: .user,
            content: message,
            timestamp: Date()
        ))
    }
}

struct AgentMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
}

enum MessageRole {
    case user
    case assistant
    case system
}

struct AgentStep: Identifiable {
    let id: UUID
    var action: StepAction
    var command: String
    var description: String
}

enum StepAction {
    case command
    case file
}

struct ExecutionResult: Identifiable {
    let id = UUID()
    let stepId: UUID
    let success: Bool
    let output: String
    let error: String
}
