import Foundation

class ModelResidencyController: ObservableObject {
    @Published var loadedModels: [LoadedModel] = []
    @Published var taskQueue: [QueuedTask] = []
    
    struct LoadedModel: Identifiable {
        let id = UUID()
        let name: String
        let sizeGB: Double
        var lastUsedAt: Date
        var keepAliveSeconds: Int
        var taskState: Data?
    }
    
    struct QueuedTask: Identifiable {
        let id = UUID()
        let modelName: String
        let priority: TaskPriority
        let estimatedDuration: TimeInterval
        let createdAt: Date
    }
    
    enum TaskPriority {
        case high
        case medium
        case low
    }
    
    enum ResidencyAction {
        case keepLoaded
        case setKeepAliveShort
        case unloadNow
        case downgradeModel
        case serializeTaskStateThenUnload
    }
    
    private let ramObserver: RAMObserver
    private let ollamaManager: OllamaManager
    
    init(ramObserver: RAMObserver, ollamaManager: OllamaManager) {
        self.ramObserver = ramObserver
        self.ollamaManager = ollamaManager
    }
    
    func evaluateResidency(modelName: String, modelSizeGB: Double, expectedNextUse: TimeInterval?) -> ResidencyAction {
        let ramPressure = ramObserver.memoryPressure
        let swapUsedGB = ramObserver.systemSwapUsedGB
        let taskQueueCount = taskQueue.count
        
        // Get model info if loaded
        let loadedModel = loadedModels.first { $0.name == modelName }
        let lastUsed = loadedModel?.lastUsedAt ?? Date.distantPast
        let timeSinceLastUse = Date().timeIntervalSince(lastUsed)
        
        // Decision logic
        if ramPressure == .red || swapUsedGB > 8.0 {
            // Emergency: unload unused models
            if taskQueueCount == 0 && timeSinceLastUse > 60 {
                return .unloadNow
            }
            if timeSinceLastUse > 300 {
                return .serializeTaskStateThenUnload
            }
            return .setKeepAliveShort
        }
        
        if ramPressure == .yellow {
            // Yellow pressure: reduce keep_alive
            if taskQueueCount == 0 {
                return .setKeepAliveShort
            }
            if timeSinceLastUse > 600 {
                return .unloadNow
            }
            return .keepLoaded
        }
        
        // Normal pressure
        if let expectedNextUse = expectedNextUse {
            if expectedNextUse < 300 {
                return .keepLoaded
            } else if expectedNextUse < 1800 {
                return .setKeepAliveShort
            } else {
                return .unloadNow
            }
        }
        
        // Default: keep loaded if recently used
        if timeSinceLastUse < 300 {
            return .keepLoaded
        } else {
            return .setKeepAliveShort
        }
    }
    
    func executeResidencyAction(_ action: ResidencyAction, modelName: String) async throws {
        switch action {
        case .keepLoaded:
            // Set keep_alive to 5 minutes (default)
            try await setKeepAlive(modelName: modelName, seconds: 300)
            
        case .setKeepAliveShort:
            // Set keep_alive to 30 seconds
            try await setKeepAlive(modelName: modelName, seconds: 30)
            
        case .unloadNow:
            // Unload model immediately
            try await unloadModel(modelName: modelName)
            
        case .downgradeModel:
            // Not implemented - would require model swapping
            print("Model downgrade not yet implemented")
            
        case .serializeTaskStateThenUnload:
            // Serialize task state then unload
            if let modelIndex = loadedModels.firstIndex(where: { $0.name == modelName }) {
                let taskState = loadedModels[modelIndex].taskState
                // Save task state to disk
                try await serializeTaskState(taskState: taskState, modelName: modelName)
                try await unloadModel(modelName: modelName)
            }
        }
    }
    
    private func setKeepAlive(modelName: String, seconds: Int) async throws {
        // Update Ollama keep_alive setting
        // This would be done via Ollama API or environment variable
        if let modelIndex = loadedModels.firstIndex(where: { $0.name == modelName }) {
            loadedModels[modelIndex].keepAliveSeconds = seconds
        }
    }
    
    private func unloadModel(modelName: String) async throws {
        // Call Ollama to unload model
        // This would be done via Ollama API
        loadedModels.removeAll { $0.name == modelName }
    }
    
    private func serializeTaskState(taskState: Data?, modelName: String) async throws {
        guard let taskState = taskState else { return }
        
        let archiveDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ollamacomputespace")
            .appendingPathComponent("model_state")
        
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        
        let archivePath = archiveDir.appendingPathComponent("\(modelName)_state.bin")
        try taskState.write(to: archivePath)
    }
    
    func addTaskToQueue(task: QueuedTask) {
        taskQueue.append(task)
        taskQueue.sort { $0.priority == .high && $1.priority != .high }
    }
    
    func loadModel(modelName: String, sizeGB: Double) {
        let model = LoadedModel(
            name: modelName,
            sizeGB: sizeGB,
            lastUsedAt: Date(),
            keepAliveSeconds: 300,
            taskState: nil
        )
        
        if !loadedModels.contains(where: { $0.name == modelName }) {
            loadedModels.append(model)
        }
    }
    
    func updateModelLastUsed(modelName: String) {
        if let index = loadedModels.firstIndex(where: { $0.name == modelName }) {
            loadedModels[index].lastUsedAt = Date()
        }
    }
    
    func getTotalLoadedModelMemoryGB() -> Double {
        return loadedModels.reduce(0.0) { $0 + $1.sizeGB }
    }
    
    func getResidencyReceipt() -> ResidencyReceipt {
        return ResidencyReceipt(
            timestamp: Date(),
            loadedModels: loadedModels.map { $0.name },
            totalMemoryGB: getTotalLoadedModelMemoryGB(),
            taskQueueCount: taskQueue.count,
            memoryPressure: ramObserver.memoryPressure,
            swapUsedGB: ramObserver.systemSwapUsedGB
        )
    }
}

struct ResidencyReceipt {
    let timestamp: Date
    let loadedModels: [String]
    let totalMemoryGB: Double
    let taskQueueCount: Int
    let memoryPressure: RAMObserver.MemoryPressure
    let swapUsedGB: Double
}
