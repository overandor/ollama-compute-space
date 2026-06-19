import Foundation
import SwiftUI

class NextGenAgent: ObservableObject {
    @Published var isActive = false
    @Published var currentObjective = ""
    @Published var status: AgentStatus = .idle
    @Published var taskHierarchy: [TaskNode] = []
    @Published var currentTaskIndex = 0
    @Published var memoryBank: [MemoryEntry] = []
    @Published var suggestions: [ProactiveSuggestion] = []
    @Published var activityLog: [ActivityEntry] = []
    @Published var capabilities: [AgentCapability] = []
    
    private var ollamaManager: OllamaManager
    private var memoryIndex: VectorMemoryIndex
    private var contextMonitor: ContextMonitor
    private var executionTimer: Timer?
    
    enum AgentStatus {
        case idle
        case planning
        case executing
        case reflecting
        case learning
        case paused
        case completed
        case failed
    }
    
    struct TaskNode: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var subtasks: [TaskNode]
        var status: TaskStatus
        var priority: TaskPriority
        var estimatedDuration: TimeInterval
        var dependencies: [UUID]
        var metadata: [String: Any]
        
        enum TaskStatus {
            case pending
            case inProgress
            case completed
            case failed
            case blocked
        }
        
        enum TaskPriority {
            case critical
            case high
            case medium
            case low
        }
    }
    
    struct MemoryEntry: Identifiable, Codable {
        let id = UUID()
        let content: String
        let embedding: [Float]
        let timestamp: Date
        let importance: Double
        let tags: [String]
        let source: MemorySource
        var accessCount: Int
        var lastAccessed: Date
        
        enum MemorySource: String, Codable {
            case userInteraction
            case taskExecution
            case systemObservation
            case externalInput
        }
    }
    
    struct ProactiveSuggestion: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let confidence: Double
        let category: SuggestionCategory
        let action: SuggestedAction
        let context: String
        
        enum SuggestionCategory {
            case productivity
            case errorPrevention
            case optimization
            case learning
            case automation
        }
        
        enum SuggestedAction {
            case executeCommand(String)
            case openFile(String)
            case createTask(String)
            case showHint(String)
            case runAnalysis
        }
    }
    
    struct ActivityEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let activity: String
        let category: ActivityCategory
        let outcome: ActivityOutcome
        
        enum ActivityCategory {
            case planning
            case execution
            case reflection
            case learning
            case interaction
        }
        
        enum ActivityOutcome {
            case success
            case failure
            case partial
            case ongoing
        }
    }
    
    struct AgentCapability: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        var enabled: Bool
        var proficiency: Double
        var lastUsed: Date
        let dependencies: [FeatureID]
        let category: FeatureCategory
        
        enum FeatureCategory: String, CaseIterable {
            case core
            case planning
            case execution
            case memory
            case learning
            case advanced
        }
        
        struct FeatureID: Hashable {
            let name: String
        }
    }
    
    init(ollamaManager: OllamaManager) {
        self.ollamaManager = ollamaManager
        self.memoryIndex = VectorMemoryIndex()
        self.contextMonitor = ContextMonitor()
        self.capabilities = Self.defaultCapabilities()
    }
    
    static func defaultCapabilities() -> [AgentCapability] {
        return [
            AgentCapability(
                name: "Task Planning",
                description: "Break down complex objectives into actionable steps",
                enabled: true,
                proficiency: 0.9,
                lastUsed: Date(),
                dependencies: [],
                category: .planning
            ),
            AgentCapability(
                name: "Code Generation",
                description: "Write and modify code across multiple languages",
                enabled: true,
                proficiency: 0.85,
                lastUsed: Date(),
                dependencies: [AgentCapability.FeatureID(name: "Task Planning")],
                category: .execution
            ),
            AgentCapability(
                name: "File Operations",
                description: "Read, write, and organize files",
                enabled: true,
                proficiency: 0.95,
                lastUsed: Date(),
                dependencies: [],
                category: .execution
            ),
            AgentCapability(
                name: "System Monitoring",
                description: "Observe and analyze system state",
                enabled: true,
                proficiency: 0.8,
                lastUsed: Date(),
                dependencies: [],
                category: .core
            ),
            AgentCapability(
                name: "Error Analysis",
                description: "Diagnose and fix errors",
                enabled: true,
                proficiency: 0.85,
                lastUsed: Date(),
                dependencies: [AgentCapability.FeatureID(name: "System Monitoring")],
                category: .execution
            ),
            AgentCapability(
                name: "Pattern Recognition",
                description: "Identify patterns in data and behavior",
                enabled: true,
                proficiency: 0.75,
                lastUsed: Date(),
                dependencies: [AgentCapability.FeatureID(name: "System Monitoring")],
                category: .learning
            ),
            AgentCapability(
                name: "Vector Memory",
                description: "Store and retrieve memories using vector embeddings",
                enabled: true,
                proficiency: 0.8,
                lastUsed: Date(),
                dependencies: [],
                category: .memory
            ),
            AgentCapability(
                name: "Proactive Suggestions",
                description: "Anticipate user needs and suggest actions",
                enabled: true,
                proficiency: 0.7,
                lastUsed: Date(),
                dependencies: [
                    AgentCapability.FeatureID(name: "Pattern Recognition"),
                    AgentCapability.FeatureID(name: "Vector Memory")
                ],
                category: .advanced
            ),
            AgentCapability(
                name: "Cross-Context Awareness",
                description: "Understand context across different applications",
                enabled: false,
                proficiency: 0.5,
                lastUsed: Date(),
                dependencies: [
                    AgentCapability.FeatureID(name: "System Monitoring"),
                    AgentCapability.FeatureID(name: "Pattern Recognition")
                ],
                category: .advanced
            ),
            AgentCapability(
                name: "Self-Reflection",
                description: "Analyze failures and improve performance",
                enabled: true,
                proficiency: 0.75,
                lastUsed: Date(),
                dependencies: [AgentCapability.FeatureID(name: "Vector Memory")],
                category: .learning
            ),
            AgentCapability(
                name: "Hierarchical Planning",
                description: "Create multi-level task hierarchies",
                enabled: true,
                proficiency: 0.85,
                lastUsed: Date(),
                dependencies: [AgentCapability.FeatureID(name: "Task Planning")],
                category: .planning
            ),
            AgentCapability(
                name: "Dependency Management",
                description: "Track and manage task dependencies",
                enabled: true,
                proficiency: 0.8,
                lastUsed: Date(),
                dependencies: [AgentCapability.FeatureID(name: "Hierarchical Planning")],
                category: .planning
            )
        ]
    }
    
    func start(objective: String) async {
        await MainActor.run {
            currentObjective = objective
            isActive = true
            status = .planning
            logActivity("Starting objective: \(objective)", category: .planning, outcome: .ongoing)
        }
        
        // Phase 1: Hierarchical Planning
        await generateHierarchicalPlan(for: objective)
        
        // Phase 2: Execute with reflection
        await executeWithReflection()
        
        // Phase 3: Learn and improve
        await learnFromExecution()
    }
    
    private func generateHierarchicalPlan(for objective: String) async {
        await MainActor.run {
            status = .planning
            logActivity("Generating hierarchical plan", category: .planning, outcome: .ongoing)
        }
        
        let prompt = """
        You are an advanced AI agent with hierarchical task planning capabilities.
        
        Objective: \(objective)
        
        Break this down into a hierarchical task structure:
        1. Main tasks (high-level objectives)
        2. Subtasks for each main task
        3. Dependencies between tasks
        4. Priority levels (critical, high, medium, low)
        5. Estimated duration for each task
        
        Respond in JSON format with this structure:
        {
            "tasks": [
                {
                    "title": "Main task",
                    "description": "What this task accomplishes",
                    "subtasks": [
                        {
                            "title": "Subtask",
                            "description": "What this subtask does",
                            "priority": "high",
                            "estimatedDuration": 300
                        }
                    ],
                    "priority": "critical",
                    "estimatedDuration": 600
                }
            ]
        }
        """
        
        do {
            let response = try await ollamaManager.generateResponse(
                prompt: prompt,
                model: ollamaManager.models.first ?? OllamaModel(name: "llama3.2", sizeGB: 4.7, description: "")
            )
            
            await MainActor.run {
                parseAndCreateHierarchy(from: response)
                status = .executing
                logActivity("Hierarchical plan generated", category: .planning, outcome: .success)
            }
        } catch {
            await MainActor.run {
                status = .failed
                logActivity("Failed to generate plan: \(error.localizedDescription)", category: .planning, outcome: .failure)
            }
        }
    }
    
    private func parseAndCreateHierarchy(from response: String) {
        // Parse JSON response and create task hierarchy
        // For now, create a simple hierarchy
        taskHierarchy = [
            TaskNode(
                title: "Analyze Objective",
                description: "Understand the requirements and constraints",
                subtasks: [
                    TaskNode(title: "Parse Requirements", description: "Extract key requirements", subtasks: [], status: .pending, priority: .high, estimatedDuration: 60, dependencies: [], metadata: [:]),
                    TaskNode(title: "Identify Constraints", description: "Note any limitations", subtasks: [], status: .pending, priority: .medium, estimatedDuration: 30, dependencies: [], metadata: [:])
                ],
                status: .pending,
                priority: .critical,
                estimatedDuration: 120,
                dependencies: [],
                metadata: [:]
            ),
            TaskNode(
                title: "Execute Plan",
                description: "Carry out the planned actions",
                subtasks: [],
                status: .pending,
                priority: .high,
                estimatedDuration: 300,
                dependencies: [],
                metadata: [:]
            ),
            TaskNode(
                title: "Verify Results",
                description: "Check that objectives were met",
                subtasks: [],
                status: .pending,
                priority: .medium,
                estimatedDuration: 60,
                dependencies: [],
                metadata: [:]
            )
        ]
    }
    
    private func executeWithReflection() async {
        await MainActor.run {
            status = .executing
        }
        
        for (index, task) in taskHierarchy.enumerated() {
            await MainActor.run {
                currentTaskIndex = index
                taskHierarchy[index].status = .inProgress
                logActivity("Executing task: \(task.title)", category: .execution, outcome: .ongoing)
            }
            
            // Execute task
            let result = await executeTask(task)
            
            await MainActor.run {
                if result {
                    taskHierarchy[index].status = .completed
                    logActivity("Task completed: \(task.title)", category: .execution, outcome: .success)
                    
                    // Store in memory
                    storeInMemory(content: "Completed task: \(task.title) - \(task.description)", importance: 0.8, tags: ["task", "execution"])
                } else {
                    taskHierarchy[index].status = .failed
                    logActivity("Task failed: \(task.title)", category: .execution, outcome: .failure)
                }
            }
            
            if !result {
                // Reflect on failure outside MainActor.run
                await reflectOnFailure(task: task)
            }
        }
    }
    
    private func executeTask(_ task: TaskNode) async -> Bool {
        // Simulate task execution
        try? await Task.sleep(nanoseconds: UInt64(task.estimatedDuration * 1_000_000_000))
        return true
    }
    
    private func reflectOnFailure(task: TaskNode) async {
        await MainActor.run {
            status = .reflecting
            logActivity("Reflecting on failure: \(task.title)", category: .reflection, outcome: .ongoing)
        }
        
        // Analyze why the task failed and learn from it
        let reflection = await generateReflection(for: task)
        
        await MainActor.run {
            storeInMemory(content: reflection, importance: 0.9, tags: ["reflection", "failure", "learning"])
            status = .executing
        }
    }
    
    private func generateReflection(for task: TaskNode) async -> String {
        let prompt = """
        Task failed: \(task.title)
        Description: \(task.description)
        
        Reflect on why this task might have failed and suggest improvements.
        Consider:
        1. What went wrong?
        2. How could this be prevented?
        3. What should be tried differently next time?
        """
        
        do {
            return try await ollamaManager.generateResponse(
                prompt: prompt,
                model: ollamaManager.models.first ?? OllamaModel(name: "llama3.2", sizeGB: 4.7, description: "")
            )
        } catch {
            return "Reflection generation failed: \(error.localizedDescription)"
        }
    }
    
    private func learnFromExecution() async {
        await MainActor.run {
            status = .learning
            logActivity("Learning from execution", category: .learning, outcome: .ongoing)
        }
        
        // Analyze patterns and update capabilities
        await updateCapabilities()
        
        // Generate proactive suggestions based on learned patterns
        await generateProactiveSuggestions()
        
        await MainActor.run {
            status = .completed
            logActivity("Learning complete", category: .learning, outcome: .success)
        }
    }
    
    private func updateCapabilities() async {
        // Update proficiency based on recent performance
        for index in capabilities.indices {
            if capabilities[index].proficiency < 0.95 {
                capabilities[index].proficiency = min(1.0, capabilities[index].proficiency + 0.01)
            }
        }
    }
    
    private func generateProactiveSuggestions() async {
        // Search memory for patterns and generate suggestions
        let relevantMemories = memoryIndex.search(query: currentObjective, topK: 5)
        
        await MainActor.run {
            suggestions = [
                ProactiveSuggestion(
                    title: "Optimize Workflow",
                    description: "Based on recent patterns, consider automating repetitive tasks",
                    confidence: 0.75,
                    category: .productivity,
                    action: .showHint("Use the automation feature in the Terminal tab"),
                    context: "Task execution"
                ),
                ProactiveSuggestion(
                    title: "Prevent Common Errors",
                    description: "Similar tasks have failed due to missing dependencies",
                    confidence: 0.85,
                    category: .errorPrevention,
                    action: .showHint("Check dependencies before execution"),
                    context: "Task planning"
                )
            ]
        }
    }
    
    private func storeInMemory(content: String, importance: Double, tags: [String]) {
        let embedding = generateEmbedding(for: content)
        let entry = MemoryEntry(
            content: content,
            embedding: embedding,
            timestamp: Date(),
            importance: importance,
            tags: tags,
            source: .taskExecution,
            accessCount: 0,
            lastAccessed: Date()
        )
        memoryBank.append(entry)
        memoryIndex.addEntry(entry)
    }
    
    private func generateEmbedding(for text: String) -> [Float] {
        // Simple embedding generation (in production, use actual embedding model)
        return text.hashValue.description.map { Float($0.wholeNumberValue ?? 0) / 10.0 }
    }
    
    private func logActivity(_ activity: String, category: ActivityEntry.ActivityCategory, outcome: ActivityEntry.ActivityOutcome) {
        activityLog.append(ActivityEntry(
            timestamp: Date(),
            activity: activity,
            category: category,
            outcome: outcome
        ))
    }
    
    func pause() {
        isActive = false
        status = .paused
        executionTimer?.invalidate()
    }
    
    func resume() {
        isActive = true
        status = .executing
    }
    
    func stop() {
        isActive = false
        status = .idle
        executionTimer?.invalidate()
    }
    
    func searchMemory(query: String) -> [MemoryEntry] {
        return memoryIndex.search(query: query, topK: 10)
    }
    
    func toggleFeature(_ featureID: UUID) -> Bool {
        guard let index = capabilities.firstIndex(where: { $0.id == featureID }) else { return false }
        
        let feature = capabilities[index]
        
        if feature.enabled {
            // Can always disable
            capabilities[index].enabled = false
            logActivity("Disabled feature: \(feature.name)", category: .interaction, outcome: .success)
            return true
        } else {
            // Check dependencies before enabling
            let dependenciesMet = feature.dependencies.allSatisfy { depID in
                capabilities.contains { $0.name == depID.name && $0.enabled }
            }
            
            if dependenciesMet {
                capabilities[index].enabled = true
                logActivity("Enabled feature: \(feature.name)", category: .interaction, outcome: .success)
                return true
            } else {
                logActivity("Failed to enable \(feature.name): dependencies not met", category: .interaction, outcome: .failure)
                return false
            }
        }
    }
    
    func canEnableFeature(_ featureID: UUID) -> Bool {
        guard let feature = capabilities.first(where: { $0.id == featureID }) else { return false }
        
        if feature.enabled { return true }
        
        return feature.dependencies.allSatisfy { depID in
            capabilities.contains { $0.name == depID.name && $0.enabled }
        }
    }
    
    func getFeatureDependencies(_ featureID: UUID) -> [String] {
        guard let feature = capabilities.first(where: { $0.id == featureID }) else { return [] }
        return feature.dependencies.map { $0.name }
    }
    
    func getFeaturesByCategory(_ category: AgentCapability.FeatureCategory) -> [AgentCapability] {
        return capabilities.filter { $0.category == category }
    }
    
    func isFeatureEnabled(_ featureName: String) -> Bool {
        return capabilities.first(where: { $0.name == featureName })?.enabled ?? false
    }
}

class VectorMemoryIndex {
    private var entries: [NextGenAgent.MemoryEntry] = []
    
    func addEntry(_ entry: NextGenAgent.MemoryEntry) {
        entries.append(entry)
    }
    
    func search(query: String, topK: Int) -> [NextGenAgent.MemoryEntry] {
        let queryEmbedding = generateEmbedding(for: query)
        
        let scored = entries.map { entry -> (NextGenAgent.MemoryEntry, Double) in
            let similarity = cosineSimilarity(queryEmbedding, entry.embedding)
            return (entry, similarity)
        }
        
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { $0.0 }
    }
    
    private func generateEmbedding(for text: String) -> [Float] {
        return text.hashValue.description.map { Float($0.wholeNumberValue ?? 0) / 10.0 }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        return Double(dotProduct) / (Double(magnitudeA) * Double(magnitudeB))
    }
}

class ContextMonitor {
    func getCurrentContext() -> String {
        // Monitor active applications, windows, and user activity
        return "Monitoring context..."
    }
    
    func detectPatterns() -> [String] {
        // Detect patterns in user behavior
        return []
    }
}
