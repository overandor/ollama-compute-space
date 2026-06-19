import SwiftUI

struct NextGenAgentView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @StateObject private var agent = NextGenAgent(ollamaManager: OllamaManager())
    @State private var objectiveInput = ""
    @State private var selectedTab: AgentTab = .overview
    @State private var memorySearchQuery = ""
    
    enum AgentTab: String, CaseIterable {
        case overview = "Overview"
        case tasks = "Tasks"
        case memory = "Memory"
        case capabilities = "Capabilities"
        case suggestions = "Suggestions"
        case activity = "Activity"
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Agent Status
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(statusColor(for: agent.status))
                            .frame(width: 60, height: 60)
                            .shadow(radius: 5)
                        
                        Text(statusEmoji(for: agent.status))
                            .font(.system(size: 30))
                    }
                    
                    Text(statusText(for: agent.status))
                        .font(.headline)
                    
                    if agent.isActive {
                        Text(agent.currentObjective)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Control Buttons
                VStack(spacing: 8) {
                    if !agent.isActive {
                        Button("Start Agent") {
                            Task {
                                await agent.start(objective: objectiveInput)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(objectiveInput.isEmpty)
                    } else {
                        HStack(spacing: 8) {
                            Button("Pause") {
                                agent.pause()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Resume") {
                                agent.resume()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Stop") {
                                agent.stop()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                
                // Objective Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Objective")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter objective...", text: $objectiveInput)
                        .textFieldStyle(.roundedBorder)
                        .disabled(agent.isActive)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 250)
            
            // Main Content
            VStack(spacing: 0) {
                // Tab Bar
                Picker("Tab", selection: $selectedTab) {
                    ForEach(AgentTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Tab Content
                ScrollView {
                    switch selectedTab {
                    case .overview:
                        overviewView
                    case .tasks:
                        tasksView
                    case .memory:
                        memoryView
                    case .capabilities:
                        capabilitiesView
                    case .suggestions:
                        suggestionsView
                    case .activity:
                        activityView
                    }
                }
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    var overviewView: some View {
        VStack(spacing: 20) {
            // Stats Cards
            HStack(spacing: 20) {
                StatCard(title: "Tasks", value: "\(agent.taskHierarchy.count)", color: .blue)
                StatCard(title: "Memory Entries", value: "\(agent.memoryBank.count)", color: .green)
                StatCard(title: "Suggestions", value: "\(agent.suggestions.count)", color: .orange)
                StatCard(title: "Capabilities", value: "\(agent.capabilities.count)", color: .purple)
            }
            
            // Current Status
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Status")
                    .font(.headline)
                
                HStack {
                    Circle()
                        .fill(statusColor(for: agent.status))
                        .frame(width: 12, height: 12)
                    
                    Text(statusText(for: agent.status))
                        .font(.subheadline)
                }
                
                if agent.isActive {
                    ProgressView(value: Double(agent.currentTaskIndex) / Double(max(1, agent.taskHierarchy.count)))
                        .progressViewStyle(.linear)
                    
                    Text("Task \(agent.currentTaskIndex + 1) of \(agent.taskHierarchy.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Recent Activity
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                
                if agent.activityLog.isEmpty {
                    Text("No activity yet")
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(agent.activityLog.prefix(5)) { activity in
                            ActivityRow(activity: activity)
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding()
    }
    
    var tasksView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Hierarchy")
                .font(.headline)
            
            if agent.taskHierarchy.isEmpty {
                Text("No tasks planned yet")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(agent.taskHierarchy.enumerated()), id: \.element.id) { index, task in
                        TaskHierarchyNode(
                            task: task,
                            level: 0,
                            currentIndex: agent.currentTaskIndex
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    var memoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Bank")
                .font(.headline)
            
            // Search
            HStack {
                TextField("Search memory...", text: $memorySearchQuery)
                    .textFieldStyle(.roundedBorder)
                
                Button("Search") {
                    _ = agent.searchMemory(query: memorySearchQuery)
                }
                .buttonStyle(.bordered)
            }
            
            // Memory Entries
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(agent.memoryBank) { entry in
                        MemoryEntryCard(entry: entry)
                    }
                }
            }
            .frame(height: 400)
        }
        .padding()
    }
    
    var capabilitiesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent Capabilities")
                .font(.headline)
            
            // Category selector
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(nil as NextGenAgent.AgentCapability.FeatureCategory?)
                ForEach(NextGenAgent.AgentCapability.FeatureCategory.allCases, id: \.self) { category in
                    Text(categoryName(for: category)).tag(category as NextGenAgent.AgentCapability.FeatureCategory?)
                }
            }
            .pickerStyle(.segmented)
            
            // Features list
            ScrollView {
                let filteredCapabilities = selectedCategory == nil 
                    ? agent.capabilities 
                    : agent.capabilities.filter { $0.category == selectedCategory }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredCapabilities) { capability in
                        FeatureToggleCard(
                            capability: capability,
                            canEnable: agent.canEnableFeature(capability.id),
                            dependencies: agent.getFeatureDependencies(capability.id),
                            onToggle: {
                                _ = agent.toggleFeature(capability.id)
                            }
                        )
                    }
                }
            }
            .frame(height: 400)
        }
        .padding()
    }
    
    @State private var selectedCategory: NextGenAgent.AgentCapability.FeatureCategory? = nil
    
    private func categoryName(for category: NextGenAgent.AgentCapability.FeatureCategory) -> String {
        switch category {
        case .core: return "Core"
        case .planning: return "Planning"
        case .execution: return "Execution"
        case .memory: return "Memory"
        case .learning: return "Learning"
        case .advanced: return "Advanced"
        }
    }
    
    var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proactive Suggestions")
                .font(.headline)
            
            if agent.suggestions.isEmpty {
                Text("No suggestions available")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(agent.suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion)
                    }
                }
            }
        }
        .padding()
    }
    
    var activityView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Log")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(agent.activityLog.reversed()) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
            .frame(height: 400)
        }
        .padding()
    }
    
    private func statusColor(for status: NextGenAgent.AgentStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .planning: return .orange
        case .executing: return .blue
        case .reflecting: return .purple
        case .learning: return .green
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private func statusEmoji(for status: NextGenAgent.AgentStatus) -> String {
        switch status {
        case .idle: return "😴"
        case .planning: return "🧠"
        case .executing: return "⚡"
        case .reflecting: return "🤔"
        case .learning: return "📚"
        case .paused: return "⏸️"
        case .completed: return "✅"
        case .failed: return "❌"
        }
    }
    
    private func statusText(for status: NextGenAgent.AgentStatus) -> String {
        switch status {
        case .idle: return "Idle"
        case .planning: return "Planning"
        case .executing: return "Executing"
        case .reflecting: return "Reflecting"
        case .learning: return "Learning"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
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

struct TaskHierarchyNode: View {
    let task: NextGenAgent.TaskNode
    let level: Int
    let currentIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 20, height: 20)
                    
                    if task.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                // Task details
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(priorityText)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text("\(Int(task.estimatedDuration))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, CGFloat(level * 20))
            
            // Subtasks
            if !task.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.subtasks) { subtask in
                        TaskHierarchyNode(task: subtask, level: level + 1, currentIndex: currentIndex)
                    }
                }
            }
        }
        .padding(8)
        .background(task.status == .inProgress ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch task.status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .blocked: return .orange
        }
    }
    
    private var priorityText: String {
        switch task.priority {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }
}

struct MemoryEntryCard: View {
    let entry: NextGenAgent.MemoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.content)
                .font(.body)
            
            HStack {
                ForEach(entry.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text(String(format: "%.1f", entry.importance))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(entry.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct CapabilityCard: View {
    let capability: NextGenAgent.AgentCapability
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(capability.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(capability.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f%%", capability.proficiency * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: capability.proficiency)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct FeatureToggleCard: View {
    let capability: NextGenAgent.AgentCapability
    let canEnable: Bool
    let dependencies: [String]
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(capability.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(capability.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(capability.enabled))
                    .toggleStyle(.switch)
                    .disabled(!canEnable && !capability.enabled)
                    .onChange(of: capability.enabled) { _ in
                        onToggle()
                    }
            }
            
            // Dependencies info
            if !dependencies.isEmpty && !capability.enabled {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Requires: \(dependencies.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Proficiency bar
            HStack {
                Text("Proficiency")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", capability.proficiency * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: capability.proficiency)
                .progressViewStyle(.linear)
        }
        .padding()
        .background(capability.enabled ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(canEnable || capability.enabled ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SuggestionCard: View {
    let suggestion: NextGenAgent.ProactiveSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(format: "%.0f%%", suggestion.confidence * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(suggestion.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(categoryText)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Apply") {
                    // Apply suggestion
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var categoryText: String {
        switch suggestion.category {
        case .productivity: return "Productivity"
        case .errorPrevention: return "Error Prevention"
        case .optimization: return "Optimization"
        case .learning: return "Learning"
        case .automation: return "Automation"
        }
    }
    
    private var categoryColor: Color {
        switch suggestion.category {
        case .productivity: return .blue
        case .errorPrevention: return .red
        case .optimization: return .green
        case .learning: return .purple
        case .automation: return .orange
        }
    }
}

struct ActivityRow: View {
    let activity: NextGenAgent.ActivityEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(outcomeColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.activity)
                    .font(.caption)
                
                Text(activity.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(categoryText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var outcomeColor: Color {
        switch activity.outcome {
        case .success: return .green
        case .failure: return .red
        case .partial: return .orange
        case .ongoing: return .blue
        }
    }
    
    private var categoryText: String {
        switch activity.category {
        case .planning: return "Planning"
        case .execution: return "Execution"
        case .reflection: return "Reflection"
        case .learning: return "Learning"
        case .interaction: return "Interaction"
        }
    }
}
