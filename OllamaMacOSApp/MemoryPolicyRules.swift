import Foundation

class MemoryPolicyRules {
    private let ramObserver: RAMObserver
    private let kvContextGovernor: KVContextGovernor
    private let modelResidencyController: ModelResidencyController
    private let operatingModes: OperatingModeManager
    
    init(
        ramObserver: RAMObserver,
        kvContextGovernor: KVContextGovernor,
        modelResidencyController: ModelResidencyController,
        operatingModes: OperatingModeManager
    ) {
        self.ramObserver = ramObserver
        self.kvContextGovernor = kvContextGovernor
        self.modelResidencyController = modelResidencyController
        self.operatingModes = operatingModes
    }
    
    enum MemoryPressure {
        case green
        case yellow
        case red
        case suspectedLeak
    }
    
    struct PolicyAction {
        let action: ActionType
        let description: String
        let priority: ActionPriority
        let parameters: [String: Any]
    }
    
    enum ActionType {
        case keepModelLoaded
        case allowLargerContext
        case preserveRicherWorkingMemory
        case summarizeOldContext
        case reduceNumCtx
        case stopUnusedModels
        case serializeInactiveBranches
        case stopUnusedOllamaModels
        case forceShortContext
        case runSmallModelForSummarization
        case restartRetainedWorker
        case blockLargeRepoIndexing
        case checkpointCognitionState
        case restartWorker
        case reloadOnlyCapsule
    }
    
    enum ActionPriority {
        case critical
        case high
        case medium
        case low
    }
    
    func evaluateMemoryState() -> MemoryPressure {
        let pressure = ramObserver.memoryPressure
        let swapUsedGB = ramObserver.systemSwapUsedGB
        let anomalies = detectAnomalies()
        
        // Check for suspected leak
        let hasLeakAnomaly = anomalies.contains { $0.type == .rssGrowth && $0.severity == .high }
        
        if hasLeakAnomaly {
            return .suspectedLeak
        }
        
        // Check for swap spike
        let hasSwapSpike = anomalies.contains { $0.type == .swapSpike && $0.severity == .critical }
        if hasSwapSpike {
            return .red
        }
        
        switch pressure {
        case .normal:
            return .green
        case .yellow:
            return .yellow
        case .red:
            return .red
        }
    }
    
    func getPolicyActions(for memoryPressure: MemoryPressure) -> [PolicyAction] {
        switch memoryPressure {
        case .green:
            return greenPressureActions()
            
        case .yellow:
            return yellowPressureActions()
            
        case .red:
            return redPressureActions()
            
        case .suspectedLeak:
            return suspectedLeakActions()
        }
    }
    
    private func greenPressureActions() -> [PolicyAction] {
        return [
            PolicyAction(
                action: .keepModelLoaded,
                description: "Keep model loaded if task queue is active",
                priority: .low,
                parameters: ["keep_alive": "300"]
            ),
            PolicyAction(
                action: .allowLargerContext,
                description: "Allow larger context for complex tasks",
                priority: .low,
                parameters: ["max_context": "131072"]
            ),
            PolicyAction(
                action: .preserveRicherWorkingMemory,
                description: "Preserve richer working memory",
                priority: .low,
                parameters: ["working_memory": "rich"]
            )
        ]
    }
    
    private func yellowPressureActions() -> [PolicyAction] {
        return [
            PolicyAction(
                action: .summarizeOldContext,
                description: "Summarize old context into capsules",
                priority: .high,
                parameters: ["compression_level": "L1"]
            ),
            PolicyAction(
                action: .reduceNumCtx,
                description: "Reduce num_ctx by 50%",
                priority: .high,
                parameters: ["reduction_factor": "0.5"]
            ),
            PolicyAction(
                action: .stopUnusedModels,
                description: "Stop unused models",
                priority: .medium,
                parameters: ["idle_threshold": "300"]
            ),
            PolicyAction(
                action: .serializeInactiveBranches,
                description: "Serialize inactive branches to disk",
                priority: .medium,
                parameters: ["branch_age_threshold": "600"]
            )
        ]
    }
    
    private func redPressureActions() -> [PolicyAction] {
        return [
            PolicyAction(
                action: .stopUnusedOllamaModels,
                description: "Stop all unused Ollama models immediately",
                priority: .critical,
                parameters: ["force": "true"]
            ),
            PolicyAction(
                action: .forceShortContext,
                description: "Force short context (4k tokens)",
                priority: .critical,
                parameters: ["num_ctx": "4096"]
            ),
            PolicyAction(
                action: .runSmallModelForSummarization,
                description: "Run small model for summarization",
                priority: .high,
                parameters: ["summarization_model": "phi3"]
            ),
            PolicyAction(
                action: .restartRetainedWorker,
                description: "Restart retained worker",
                priority: .high,
                parameters: ["worker": "retained"]
            ),
            PolicyAction(
                action: .blockLargeRepoIndexing,
                description: "Block large repo indexing operations",
                priority: .medium,
                parameters: ["max_repo_size": "1000"]
            )
        ]
    }
    
    private func suspectedLeakActions() -> [PolicyAction] {
        return [
            PolicyAction(
                action: .checkpointCognitionState,
                description: "Checkpoint cognition state before restart",
                priority: .critical,
                parameters: ["checkpoint_path": "~/.ollamacomputespace/checkpoints"]
            ),
            PolicyAction(
                action: .restartWorker,
                description: "Restart worker to clear potential leak",
                priority: .critical,
                parameters: ["force": "true"]
            ),
            PolicyAction(
                action: .reloadOnlyCapsule,
                description: "Reload only compressed capsule after restart",
                priority: .high,
                parameters: ["load_mode": "capsule_only"]
            )
        ]
    }
    
    func applyPolicyAction(_ action: PolicyAction) async throws {
        switch action.action {
        case .keepModelLoaded:
            try await applyKeepModelLoaded(parameters: action.parameters)
            
        case .allowLargerContext:
            try await applyAllowLargerContext(parameters: action.parameters)
            
        case .preserveRicherWorkingMemory:
            try await applyPreserveRicherWorkingMemory(parameters: action.parameters)
            
        case .summarizeOldContext:
            try await applySummarizeOldContext(parameters: action.parameters)
            
        case .reduceNumCtx:
            try await applyReduceNumCtx(parameters: action.parameters)
            
        case .stopUnusedModels:
            try await applyStopUnusedModels(parameters: action.parameters)
            
        case .serializeInactiveBranches:
            try await applySerializeInactiveBranches(parameters: action.parameters)
            
        case .stopUnusedOllamaModels:
            try await applyStopUnusedOllamaModels(parameters: action.parameters)
            
        case .forceShortContext:
            try await applyForceShortContext(parameters: action.parameters)
            
        case .runSmallModelForSummarization:
            try await applyRunSmallModelForSummarization(parameters: action.parameters)
            
        case .restartRetainedWorker:
            try await applyRestartRetainedWorker(parameters: action.parameters)
            
        case .blockLargeRepoIndexing:
            try await applyBlockLargeRepoIndexing(parameters: action.parameters)
            
        case .checkpointCognitionState:
            try await applyCheckpointCognitionState(parameters: action.parameters)
            
        case .restartWorker:
            try await applyRestartWorker(parameters: action.parameters)
            
        case .reloadOnlyCapsule:
            try await applyReloadOnlyCapsule(parameters: action.parameters)
        }
    }
    
    // MARK: - Action Implementations
    
    private func applyKeepModelLoaded(parameters: [String: Any]) async throws {
        let keepAlive = parameters["keep_alive"] as? String ?? "300"
        print("Setting keep_alive to \(keepAlive) seconds")
        // Would call modelResidencyController
    }
    
    private func applyAllowLargerContext(parameters: [String: Any]) async throws {
        let maxContext = parameters["max_context"] as? String ?? "131072"
        kvContextGovernor.maxContextLength = Int(maxContext) ?? 131072
        print("Allowing larger context up to \(maxContext) tokens")
    }
    
    private func applyPreserveRicherWorkingMemory(parameters: [String: Any]) async throws {
        print("Preserving richer working memory")
        // Would adjust memory allocation settings
    }
    
    private func applySummarizeOldContext(parameters: [String: Any]) async throws {
        let compressionLevel = parameters["compression_level"] as? String ?? "L1"
        print("Summarizing old context at level \(compressionLevel)")
        // Would call contextCompressor
    }
    
    private func applyReduceNumCtx(parameters: [String: Any]) async throws {
        let reductionFactor = parameters["reduction_factor"] as? String ?? "0.5"
        let factor = Double(reductionFactor) ?? 0.5
        kvContextGovernor.currentContextLength = Int(Double(kvContextGovernor.maxContextLength) * factor)
        print("Reducing num_ctx by factor \(reductionFactor)")
    }
    
    private func applyStopUnusedModels(parameters: [String: Any]) async throws {
        let idleThreshold = parameters["idle_threshold"] as? String ?? "300"
        print("Stopping models idle for more than \(idleThreshold) seconds")
        // Would call modelResidencyController
    }
    
    private func applySerializeInactiveBranches(parameters: [String: Any]) async throws {
        let branchAgeThreshold = parameters["branch_age_threshold"] as? String ?? "600"
        print("Serializing branches older than \(branchAgeThreshold) seconds")
        // Would serialize inactive branches to disk
    }
    
    private func applyStopUnusedOllamaModels(parameters: [String: Any]) async throws {
        let force = parameters["force"] as? String ?? "false"
        print("Stopping unused Ollama models (force: \(force))")
        // Would call modelResidencyController to unload all unused models
    }
    
    private func applyForceShortContext(parameters: [String: Any]) async throws {
        let numCtx = parameters["num_ctx"] as? String ?? "4096"
        kvContextGovernor.currentContextLength = Int(numCtx) ?? 4096
        kvContextGovernor.contextPolicy = .emergencyShrink
        print("Forcing short context to \(numCtx) tokens")
    }
    
    private func applyRunSmallModelForSummarization(parameters: [String: Any]) async throws {
        let summarizationModel = parameters["summarization_model"] as? String ?? "phi3"
        print("Running small model \(summarizationModel) for summarization")
        // Would switch to smaller model for summarization tasks
    }
    
    private func applyRestartRetainedWorker(parameters: [String: Any]) async throws {
        let worker = parameters["worker"] as? String ?? "retained"
        print("Restarting \(worker) worker")
        // Would restart the worker process
    }
    
    private func applyBlockLargeRepoIndexing(parameters: [String: Any]) async throws {
        let maxRepoSize = parameters["max_repo_size"] as? String ?? "1000"
        print("Blocking repo indexing for repos larger than \(maxRepoSize) files")
        // Would block large repo indexing operations
    }
    
    private func applyCheckpointCognitionState(parameters: [String: Any]) async throws {
        let checkpointPath = parameters["checkpoint_path"] as? String ?? "~/.ollamacomputespace/checkpoints"
        print("Checkpointing cognition state to \(checkpointPath)")
        // Would save current cognition state to disk
    }
    
    private func applyRestartWorker(parameters: [String: Any]) async throws {
        let force = parameters["force"] as? String ?? "false"
        print("Restarting worker (force: \(force))")
        // Would restart the worker process
    }
    
    private func applyReloadOnlyCapsule(parameters: [String: Any]) async throws {
        let loadMode = parameters["load_mode"] as? String ?? "capsule_only"
        print("Reloading in \(loadMode) mode")
        // Would reload only the compressed capsule
    }
    
    // MARK: - Anomaly Detection
    
    private func detectAnomalies() -> [Anomaly] {
        // This would integrate with MLXPCAWorker
        // For now, return empty array
        return []
    }
    
    struct Anomaly {
        let type: AnomalyType
        let severity: AnomalySeverity
        let description: String
        let value: Double
    }
    
    enum AnomalyType {
        case rssGrowth
        case swapSpike
        case pageoutSpike
        case contextExpansion
        case modelResidency
    }
    
    enum AnomalySeverity {
        case low
        case medium
        case high
        case critical
    }
}
