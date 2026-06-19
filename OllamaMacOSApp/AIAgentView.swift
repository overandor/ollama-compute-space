import SwiftUI

struct AIAgentView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @EnvironmentObject var memoryManager: MemoryManager
    @EnvironmentObject var vmManager: VMManager
    @EnvironmentObject var aiAgent: AIAgent
    @State private var taskInput = ""
    @State private var selectedModel: OllamaModel?
    
    var body: some View {
        HSplitView {
            // Chat and Task Input
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("AI Agent")
                        .font(.headline)
                    
                    Spacer()
                    
                    if aiAgent.isActive {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(for: aiAgent.status))
                                .frame(width: 8, height: 8)
                            Text(statusText(for: aiAgent.status))
                                .font(.caption)
                        }
                    }
                    
                    Button("Stop") {
                        aiAgent.stop()
                    }
                    .disabled(!aiAgent.isActive)
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(aiAgent.messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: aiAgent.messages.count) { _ in
                        if let lastMessage = aiAgent.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Task Input
                VStack(spacing: 8) {
                    HStack {
                        Text("Task:")
                            .font(.subheadline)
                        
                        Picker("Model", selection: $selectedModel) {
                            ForEach(ollamaManager.models) { model in
                                Text(model.name).tag(model as OllamaModel?)
                            }
                        }
                        .frame(width: 150)
                        
                        Spacer()
                    }
                    
                    HStack {
                        TextField("Describe your task for the AI agent...", text: $taskInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                startTask()
                            }
                        
                        Button("Start") {
                            startTask()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(taskInput.isEmpty || aiAgent.isActive)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            // Plan and Execution
            VStack(spacing: 0) {
                // Plan Header
                HStack {
                    Text("Execution Plan")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(aiAgent.plan.count) steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Plan Steps
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if aiAgent.plan.isEmpty {
                            Text("No plan generated yet")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(Array(aiAgent.plan.enumerated()), id: \.element.id) { index, step in
                                PlanStepRow(
                                    step: step,
                                    index: index,
                                    currentIndex: aiAgent.currentStepIndex,
                                    status: stepStatus(for: index)
                                )
                            }
                        }
                    }
                    .padding()
                }
                
                // Execution History
                Divider()
                
                HStack {
                    Text("Execution History")
                        .font(.headline)
                    
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if aiAgent.executionHistory.isEmpty {
                            Text("No execution history")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(aiAgent.executionHistory) { result in
                                ExecutionResultRow(result: result)
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(minWidth: 300)
        }
        .onAppear {
            selectedModel = ollamaManager.models.first
        }
    }
    
    private func startTask() {
        guard !taskInput.isEmpty else { return }
        
        Task {
            await aiAgent.startTask(taskInput)
        }
        
        taskInput = ""
    }
    
    private func statusColor(for status: AIAgent.AgentStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .planning: return .orange
        case .executing: return .blue
        case .waiting: return .yellow
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private func statusText(for status: AIAgent.AgentStatus) -> String {
        switch status {
        case .idle: return "Idle"
        case .planning: return "Planning"
        case .executing: return "Executing"
        case .waiting: return "Waiting"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
    
    private func stepStatus(for index: Int) -> StepStatus {
        if index < aiAgent.currentStepIndex {
            return .completed
        } else if index == aiAgent.currentStepIndex {
            return .inProgress
        } else {
            return .pending
        }
    }
}

struct MessageBubble: View {
    let message: AgentMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : message.role == .assistant ? "Agent" : "System")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .padding()
                    .background(message.role == .user ? Color.blue : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .foregroundColor(message.role == .user ? .white : .primary)
            }
            .frame(maxWidth: 400, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role != .user {
                Spacer()
            }
        }
    }
}

struct PlanStepRow: View {
    let step: AgentStep
    let index: Int
    let currentIndex: Int
    let status: StepStatus
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 24, height: 24)
                
                if status == .completed {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Step details
            VStack(alignment: .leading, spacing: 4) {
                Text(step.description)
                    .font(.subheadline)
                
                Text(step.command)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(status == .inProgress ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .completed: return .green
        case .inProgress: return .blue
        case .pending: return .gray
        }
    }
}

enum StepStatus {
    case completed
    case inProgress
    case pending
}

struct ExecutionResultRow: View {
    let result: ExecutionResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                if result.success {
                    Text(result.output)
                        .font(.caption)
                        .lineLimit(3)
                } else {
                    Text(result.error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
