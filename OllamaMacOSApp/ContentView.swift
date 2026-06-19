import SwiftUI

struct ContentView: View {
    @EnvironmentObject var memoryManager: MemoryManager
    @EnvironmentObject var ollamaManager: OllamaManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
                .tag(0)
            
            TerminalView()
                .tabItem {
                    Label("Terminal", systemImage: "terminal.fill")
                }
                .tag(1)
            
            BrowserView()
                .tabItem {
                    Label("Browser", systemImage: "globe")
                }
                .tag(2)
            
            AgentsView()
                .tabItem {
                    Label("Agents", systemImage: "person.2.fill")
                }
                .tag(3)
            
            AIAgentView()
                .tabItem {
                    Label("AI Agent", systemImage: "brain.head.profile")
                }
                .tag(4)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

struct DashboardView: View {
    @EnvironmentObject var memoryManager: MemoryManager
    @EnvironmentObject var ollamaManager: OllamaManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Ollama Compute Space")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack(spacing: 20) {
                    MemoryCard(title: "Total RAM", value: String(format: "%.1f GB", memoryManager.totalMemoryGB), color: .blue)
                    MemoryCard(title: "Available", value: String(format: "%.1f GB", memoryManager.availableMemoryGB), color: .green)
                    MemoryCard(title: "App Usage", value: String(format: "%.2f GB", memoryManager.appMemoryGB), color: .orange)
                    MemoryCard(title: "Allocated", value: String(format: "%.1f GB", memoryManager.agents.reduce(0) { $0 + $1.allocatedMemoryGB }), color: .purple)
                }
                
                HStack(spacing: 20) {
                    // Ollama Server Control
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ollama Server")
                            .font(.headline)
                        
                        HStack {
                            Button(ollamaManager.isRunning ? "Stop Server" : "Start Server") {
                                Task {
                                    if ollamaManager.isRunning {
                                        ollamaManager.stopOllamaServer()
                                    } else {
                                        try? await ollamaManager.startOllamaServer()
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Circle()
                                .fill(ollamaManager.isRunning ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                        }
                        
                        if ollamaManager.isRunning {
                            Text("Server running at \(ollamaManager.serverURL)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    // Models List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Available Models")
                            .font(.headline)
                        
                        List(ollamaManager.models) { model in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(model.name)
                                        .font(.subheadline)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f GB", model.sizeGB))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: 150)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Agent Memory Allocation
                VStack(alignment: .leading, spacing: 10) {
                    Text("Agent Memory Allocation")
                        .font(.headline)
                    
                    if memoryManager.agents.isEmpty {
                        Text("No agents created yet")
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            ForEach(memoryManager.agents) { agent in
                                AgentMemoryCard(agent: agent)
                            }
                        }
                    }
                    
                    Button("Create New Agent") {
                        // Show agent creation dialog
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct MemoryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct AgentMemoryCard: View {
    let agent: AgentMemory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(agent.name)
                .font(.headline)
            Text("Allocated: \(String(format: "%.1f GB", agent.allocatedMemoryGB))")
                .font(.caption)
            Text("Current: \(String(format: "%.2f GB", agent.currentMemoryGB))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 150)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
