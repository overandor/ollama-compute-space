import SwiftUI

struct AgentsView: View {
    @EnvironmentObject var memoryManager: MemoryManager
    @EnvironmentObject var ollamaManager: OllamaManager
    @EnvironmentObject var autonomousAgent: AutonomousAgent
    @State private var showingCreateAgent = false
    @State private var showingCreateChat = false
    @State private var selectedAgent: AgentMemory?
    @State private var newAgentName = ""
    @State private var newAgentMemory = 2.0
    @State private var newChatName = ""
    @State private var newChatMemory = 1.0
    @State private var autonomousObjective = ""
    @State private var selectedAutonomousModel: OllamaModel?
    
    var body: some View {
        HSplitView {
            // Agents list
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Agents")
                        .font(.headline)
                    Spacer()
                    Button("New Agent") {
                        showingCreateAgent = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                List(memoryManager.agents, selection: $selectedAgent) { agent in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name)
                            .font(.subheadline)
                        HStack {
                            Text("\(String(format: "%.1f GB", agent.allocatedMemoryGB)) allocated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.2f GB", agent.currentMemoryGB)) used")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(4)
                }
            }
            .padding()
            .frame(minWidth: 250)
            
            // Agent details and chats
            VStack(alignment: .leading, spacing: 10) {
                if let agent = selectedAgent {
                    HStack {
                        Text(agent.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("New Chat") {
                            showingCreateChat = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Memory allocation for this agent
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Allocation")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Allocated")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f GB", agent.allocatedMemoryGB))")
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Current Usage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.2f GB", agent.currentMemoryGB))")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.2f GB", agent.allocatedMemoryGB - agent.currentMemoryGB))")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            // Memory usage bar
                            VStack(alignment: .trailing) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                        
                                        Rectangle()
                                            .fill(Color.green)
                                            .frame(width: geometry.size.width * CGFloat(agent.currentMemoryGB / agent.allocatedMemoryGB))
                                    }
                                }
                                .frame(height: 8)
                                .frame(width: 100)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    // Chats for this agent
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chats")
                            .font(.headline)
                        
                        let agentChats = memoryManager.chats.filter { $0.agentId == agent.id }
                        
                        if agentChats.isEmpty {
                            Text("No chats yet")
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(agentChats) { chat in
                                        ChatRow(chat: chat)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    // Autonomous Agent Control
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Autonomous Agent")
                            .font(.headline)
                        
                        HStack {
                            if autonomousAgent.isRunning {
                                Button("Stop Agent") {
                                    autonomousAgent.stop()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("Start Agent") {
                                    if let model = selectedAutonomousModel {
                                        autonomousAgent.start(model: model, objective: autonomousObjective)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(autonomousObjective.isEmpty || selectedAutonomousModel == nil)
                            }
                            
                            Circle()
                                .fill(autonomousAgent.isRunning ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Objective:")
                                .font(.caption)
                            TextField("Enter objective for autonomous agent...", text: $autonomousObjective)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Model:")
                                .font(.caption)
                            Picker("Model", selection: $selectedAutonomousModel) {
                                ForEach(ollamaManager.models) { model in
                                    Text(model.name).tag(model as OllamaModel?)
                                }
                            }
                        }
                        
                        Divider()
                        
                        Text("Agent Logs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(autonomousAgent.logs, id: \.self) { log in
                                    Text(log)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 150)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Select an agent to view details")
                            .foregroundColor(.secondary)
                        
                        Text("Or create a new agent to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingCreateAgent) {
            CreateAgentSheet(
                agentName: $newAgentName,
                agentMemory: $newAgentMemory,
                isPresented: $showingCreateAgent,
                onCreate: {
                    memoryManager.createAgent(name: newAgentName, allocatedMemoryGB: newAgentMemory)
                    newAgentName = ""
                    newAgentMemory = 2.0
                }
            )
        }
        .sheet(isPresented: $showingCreateChat) {
            if let agent = selectedAgent {
                CreateChatSheet(
                    chatName: $newChatName,
                    chatMemory: $newChatMemory,
                    isPresented: $showingCreateChat,
                    onCreate: {
                        memoryManager.createChat(agentId: agent.id, name: newChatName, allocatedMemoryGB: newChatMemory)
                        newChatName = ""
                        newChatMemory = 1.0
                    }
                )
            }
        }
    }
}

struct ChatRow: View {
    let chat: ChatMemory
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name)
                    .font(.subheadline)
                Text(chat.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.1f GB", chat.allocatedMemoryGB))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(String(format: "%.2f GB", chat.currentMemoryGB))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

struct CreateAgentSheet: View {
    @Binding var agentName: String
    @Binding var agentMemory: Double
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Agent")
                .font(.headline)
            
            TextField("Agent Name", text: $agentName)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading) {
                Text("Memory Allocation: \(String(format: "%.1f GB", agentMemory))")
                    .font(.caption)
                
                Slider(value: $agentMemory, in: 0.5...16.0, step: 0.5)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    onCreate()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(agentName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct CreateChatSheet: View {
    @Binding var chatName: String
    @Binding var chatMemory: Double
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Chat")
                .font(.headline)
            
            TextField("Chat Name", text: $chatName)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading) {
                Text("Memory Allocation: \(String(format: "%.1f GB", chatMemory))")
                    .font(.caption)
                
                Slider(value: $chatMemory, in: 0.1...8.0, step: 0.1)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    onCreate()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(chatName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
