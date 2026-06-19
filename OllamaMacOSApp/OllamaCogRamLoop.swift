import Foundation

class OllamaCogRamLoop: ObservableObject {
    private let ramObserver: RAMObserver
    private let ollamaObserver: OllamaObserver
    private let contextCompressor: ContextCompressor
    private let kvContextGovernor: KVContextGovernor
    private let modelResidencyController: ModelResidencyController
    private let qualityVerifier: QualityVerifier
    private let receiptSystem: CompressionReceiptSystem
    private let mlxPCAWorker: MLXPCAWorker
    private let operatingModes: OperatingModes
    
    @Published var currentLoopState: LoopState = .idle
    @Published var lastLoopResult: LoopResult?
    
    enum LoopState {
        case idle
        case measuring
        case classifying
        case compressing
        case running
        case writingReceipt
        case managingResidency
    }
    
    struct LoopResult {
        let timestamp: Date
        let ramBefore: CompressionReceipt
        let ramAfter: CompressionReceipt
        let contextTokensBefore: Int
        let contextTokensAfter: Int
        let compressionRatio: Double
        let memoryState: MemoryState
        let policyAction: PolicyAction
        let receipt: CognitionCompressionReceipt
    }
    
    enum MemoryState {
        case green
        case yellow
        case red
        case suspectedLeak
    }
    
    enum PolicyAction {
        case keepModelLoaded
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
    
    init(
        ramObserver: RAMObserver,
        ollamaObserver: OllamaObserver,
        contextCompressor: ContextCompressor,
        kvContextGovernor: KVContextGovernor,
        modelResidencyController: ModelResidencyController,
        qualityVerifier: QualityVerifier,
        receiptSystem: CompressionReceiptSystem,
        mlxPCAWorker: MLXPCAWorker,
        operatingModes: OperatingModes
    ) {
        self.ramObserver = ramObserver
        self.ollamaObserver = ollamaObserver
        self.contextCompressor = contextCompressor
        self.kvContextGovernor = kvContextGovernor
        self.modelResidencyController = modelResidencyController
        self.qualityVerifier = qualityVerifier
        self.receiptSystem = receiptSystem
        self.mlxPCAWorker = mlxPCAWorker
        self.operatingModes = operatingModes
    }
    
    func executeLoop(
        model: String,
        task: String,
        rawContext: String,
        taskType: KVContextGovernor.TaskType
    ) async throws -> LoopResult {
        currentLoopState = .measuring
        
        // Step 1: Measure RAM QUAD
        let ramBefore = measureRAMQuad()
        
        // Step 2: Measure Ollama model residency
        let modelResidency = await measureOllamaModelResidency()
        
        // Step 3: Estimate context tokens
        let contextTokensBefore = estimateContextTokens(rawContext: rawContext)
        
        // Step 4: Classify memory state
        let memoryState = classifyMemoryState(ramBefore: ramBefore, modelResidency: modelResidency)
        
        // Step 5: Choose context budget
        let contextBudget = chooseContextBudget(memoryState: memoryState, taskType: taskType)
        
        // Step 6: Compress history to capsule
        currentLoopState = .compressing
        let compressionResult = await compressHistoryToCapsule(
            rawContext: rawContext,
            targetTokens: contextBudget
        )
        
        // Step 7: Run Ollama with budget
        currentLoopState = .running
        let (response, contextTokensAfter) = try await runOllamaWithBudget(
            model: model,
            compressedContext: compressionResult.compressedContent,
            contextBudget: contextBudget
        )
        
        // Step 8: Write receipt
        currentLoopState = .writingReceipt
        let ramAfter = measureRAMQuad()
        let receipt = await writeReceipt(
            model: model,
            task: task,
            rawContextTokens: contextTokensBefore,
            hydratedContextTokens: contextTokensAfter,
            ramBefore: ramBefore,
            ramAfter: ramAfter,
            compressionResult: compressionResult
        )
        
        // Step 9: Unload or keep model based on pressure
        currentLoopState = .managingResidency
        let policyAction = await manageModelResidency(
            memoryState: memoryState,
            model: model
        )
        
        currentLoopState = .idle
        
        let result = LoopResult(
            timestamp: Date(),
            ramBefore: ramBefore,
            ramAfter: ramAfter,
            contextTokensBefore: contextTokensBefore,
            contextTokensAfter: contextTokensAfter,
            compressionRatio: Double(contextTokensBefore) / Double(contextTokensAfter),
            memoryState: memoryState,
            policyAction: policyAction,
            receipt: receipt
        )
        
        lastLoopResult = result
        return result
    }
    
    // Step 1: Measure RAM QUAD
    private func measureRAMQuad() -> CompressionReceipt {
        return CompressionReceipt(
            ollamaRSSGB: ramObserver.ollamaRSSGB,
            swapUsedGB: ramObserver.systemSwapUsedGB
        )
    }
    
    // Step 2: Measure Ollama model residency
    private func measureOllamaModelResidency() async -> ModelResidencyController.ResidencyReceipt {
        return modelResidencyController.getResidencyReceipt()
    }
    
    // Step 3: Estimate context tokens
    private func estimateContextTokens(rawContext: String) -> Int {
        return rawContext.estimatedTokenCount()
    }
    
    // Step 4: Classify memory state
    private func classifyMemoryState(
        ramBefore: CompressionReceipt,
        modelResidency: ModelResidencyController.ResidencyReceipt
    ) -> MemoryState {
        let pressure = ramObserver.memoryPressure
        let swapUsed = ramBefore.swapUsedGB
        let anomalies = mlxPCAWorker.detectAnomalies()
        
        // Check for suspected leak
        let hasLeakAnomaly = anomalies.contains { $0.type == .rssGrowth && $0.severity == .high }
        
        if hasLeakAnomaly {
            return .suspectedLeak
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
    
    // Step 5: Choose context budget
    private func chooseContextBudget(
        memoryState: MemoryState,
        taskType: KVContextGovernor.TaskType
    ) -> Int {
        let currentMode = operatingModes.currentMode
        
        switch memoryState {
        case .green:
            return kvContextGovernor.getDynamicContextLength(taskType: taskType)
            
        case .yellow:
            // Reduce context by 50%
            let fullBudget = kvContextGovernor.getDynamicContextLength(taskType: taskType)
            return max(fullBudget / 2, 4096)
            
        case .red:
            // Emergency: use minimum context
            return 4096
            
        case .suspectedLeak:
            // Use minimal context for summarization
            return 2048
        }
    }
    
    // Step 6: Compress history to capsule
    private func compressHistoryToCapsule(
        rawContext: String,
        targetTokens: Int
    ) async -> ContextCompressor.CompressionResult {
        let currentTokens = rawContext.estimatedTokenCount()
        
        if currentTokens <= targetTokens {
            // No compression needed
            return ContextCompressor.CompressionResult(
                compressedContent: rawContext,
                originalTokens: currentTokens,
                compressedTokens: currentTokens,
                level: .L0_raw_recent_context,
                preservedElements: ["full_context"],
                droppedElements: []
            )
        }
        
        // Compress to L1 capsule
        return contextCompressor.compressContext(
            rawContext: rawContext,
            targetLevel: .L1_structured_summary
        )
    }
    
    // Step 7: Run Ollama with budget
    private func runOllamaWithBudget(
        model: String,
        compressedContext: String,
        contextBudget: Int
    ) async throws -> (String, Int) {
        // Apply context budget to Ollama settings
        ollamaObserver.setContextSetting("num_ctx", value: contextBudget)
        
        // Run inference (this would call OllamaManager)
        // For now, simulate response
        let response = "Simulated Ollama response"
        let contextTokensUsed = compressedContext.estimatedTokenCount()
        
        // Record generation metrics
        ollamaObserver.recordGeneration(
            promptTokens: contextTokensUsed,
            completionTokens: response.estimatedTokenCount(),
            timeToFirstToken: 0.5,
            totalGenerationTime: 2.0
        )
        
        return (response, contextTokensUsed)
    }
    
    // Step 8: Write receipt
    private func writeReceipt(
        model: String,
        task: String,
        rawContextTokens: Int,
        hydratedContextTokens: Int,
        ramBefore: CompressionReceipt,
        ramAfter: CompressionReceipt,
        compressionResult: ContextCompressor.CompressionResult
    ) async -> CognitionCompressionReceipt {
        let verification = qualityVerifier.verifyCompression(
            original: "",
            compressed: compressionResult.compressedContent
        )
        
        return receiptSystem.generateReceipt(
            model: model,
            task: task,
            rawContextTokens: rawContextTokens,
            hydratedContextTokens: hydratedContextTokens,
            ramBefore: ramBefore,
            ramAfter: ramAfter,
            verification: verification,
            preserved: compressionResult.preservedElements,
            dropped: compressionResult.droppedElements
        )
    }
    
    // Step 9: Unload or keep model based on pressure
    private func manageModelResidency(
        memoryState: MemoryState,
        model: String
    ) async -> PolicyAction {
        let action = modelResidencyController.evaluateResidency(
            modelName: model,
            modelSizeGB: 4.0, // Would get from actual model
            expectedNextUse: nil
        )
        
        try? await modelResidencyController.executeResidencyAction(action, modelName: model)
        
        // Map residency action to policy action
        switch action {
        case .keepLoaded:
            return .keepModelLoaded
        case .setKeepAliveShort:
            return .summarizeOldContext
        case .unloadNow:
            return .stopUnusedModels
        case .downgradeModel:
            return .runSmallModelForSummarization
        case .serializeTaskStateThenUnload:
            return .checkpointCognitionState
        }
    }
    
    func applyMemoryPolicy(memoryState: MemoryState) -> [PolicyAction] {
        switch memoryState {
        case .green:
            return [
                .keepModelLoaded,
                .allowLargerContext,
                .preserveRicherWorkingMemory
            ]
            
        case .yellow:
            return [
                .summarizeOldContext,
                .reduceNumCtx,
                .stopUnusedModels,
                .serializeInactiveBranches
            ]
            
        case .red:
            return [
                .stopUnusedOllamaModels,
                .forceShortContext,
                .runSmallModelForSummarization,
                .restartRetainedWorker,
                .blockLargeRepoIndexing
            ]
            
        case .suspectedLeak:
            return [
                .checkpointCognitionState,
                .restartWorker,
                .reloadOnlyCapsule
            ]
        }
    }
    
    // Additional policy actions
    private func allowLargerContext() -> PolicyAction { .keepModelLoaded }
    private func preserveRicherWorkingMemory() -> PolicyAction { .keepModelLoaded }
    private func reduceNumCtx() -> PolicyAction { .reduceNumCtx }
    private func stopUnusedModels() -> PolicyAction { .stopUnusedModels }
    private func serializeInactiveBranches() -> PolicyAction { .serializeInactiveBranches }
    private func stopUnusedOllamaModels() -> PolicyAction { .stopUnusedOllamaModels }
    private func forceShortContext() -> PolicyAction { .forceShortContext }
    private func runSmallModelForSummarization() -> PolicyAction { .runSmallModelForSummarization }
    private func restartRetainedWorker() -> PolicyAction { .restartRetainedWorker }
    private func blockLargeRepoIndexing() -> PolicyAction { .blockLargeRepoIndexing }
    private func checkpointCognitionState() -> PolicyAction { .checkpointCognitionState }
    private func restartWorker() -> PolicyAction { .restartWorker }
    private func reloadOnlyCapsule() -> PolicyAction { .reloadOnlyCapsule }
}
