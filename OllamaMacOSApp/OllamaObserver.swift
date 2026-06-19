import Foundation

class OllamaObserver: ObservableObject {
    @Published var loadedModels: [OllamaModelInfo] = []
    @Published var contextSettings: ContextSettings = ContextSettings()
    @Published var latencyMetrics: LatencyMetrics = LatencyMetrics()
    @Published var tokenMetrics: TokenMetrics = TokenMetrics()
    @Published var isObserving: Bool = false
    
    private var observationTimer: Timer?
    private let ollamaManager: OllamaManager
    
    init(ollamaManager: OllamaManager) {
        self.ollamaManager = ollamaManager
    }
    
    struct OllamaModelInfo: Identifiable {
        let id = UUID()
        let name: String
        let sizeGB: Double
        let loadedAt: Date
        let lastUsedAt: Date
        let contextLength: Int
        let keepAliveSeconds: Int
    }
    
    struct ContextSettings {
        var numCtx: Int = 4096
        var numBatch: Int = 512
        var numGpu: Int = 1
        var numThread: Int = 8
        var mainGpu: Int = 0
        var lowVram: Bool = false
        var f16Kv: Bool = true
        var logitsAll: Bool = false
        var vocabOnly: Bool = false
        var useMmap: Bool = true
        var useMlock: Bool = false
        var embeddingOnly: Bool = false
        var ropeFrequencyBase: Double = 0.0
        var ropeFrequencyScale: Double = 0.0
        var ropeScalingType: String = ""
    }
    
    struct LatencyMetrics {
        var timeToFirstToken: TimeInterval = 0.0
        var timePerToken: TimeInterval = 0.0
        var tokensPerSecond: Double = 0.0
        var totalGenerationTime: TimeInterval = 0.0
        var promptProcessingTime: TimeInterval = 0.0
        var lastMeasurement: Date?
    }
    
    struct TokenMetrics {
        var promptTokens: Int = 0
        var completionTokens: Int = 0
        var totalTokens: Int = 0
        var contextTokensUsed: Int = 0
        var maxContextTokens: Int = 4096
        var cacheHitRate: Double = 0.0
    }
    
    func startObserving() {
        guard !isObserving else { return }
        
        isObserving = true
        observationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateObservations()
        }
    }
    
    func stopObserving() {
        isObserving = false
        observationTimer?.invalidate()
        observationTimer = nil
    }
    
    private func updateObservations() {
        Task {
            await updateLoadedModels()
            await updateContextSettings()
            await updateLatencyMetrics()
            await updateTokenMetrics()
        }
    }
    
    private func updateLoadedModels() async {
        // Query Ollama for loaded models
        // This would use Ollama API to get currently loaded models
        // For now, simulate with available models
        
        let availableModels = ollamaManager.models
        
        await MainActor.run {
            loadedModels = availableModels.map { model in
                OllamaModelInfo(
                    name: model.name,
                    sizeGB: model.sizeGB,
                    loadedAt: Date(),
                    lastUsedAt: Date(),
                    contextLength: contextSettings.numCtx,
                    keepAliveSeconds: 300
                )
            }
        }
    }
    
    private func updateContextSettings() async {
        // Query Ollama for current context settings
        // This would use Ollama API to get current settings
        // For now, use default values
        
        await MainActor.run {
            // Context settings would be fetched from Ollama
            // Currently using defaults
        }
    }
    
    private func updateLatencyMetrics() async {
        // Calculate latency metrics from recent generations
        // This would track generation times
        
        await MainActor.run {
            // Latency metrics would be calculated from generation history
            // Currently using defaults
        }
    }
    
    private func updateTokenMetrics() async {
        // Calculate token metrics from recent generations
        // This would track token counts
        
        await MainActor.run {
            tokenMetrics.maxContextTokens = contextSettings.numCtx
        }
    }
    
    func recordGeneration(
        promptTokens: Int,
        completionTokens: Int,
        timeToFirstToken: TimeInterval,
        totalGenerationTime: TimeInterval
    ) {
        tokenMetrics.promptTokens = promptTokens
        tokenMetrics.completionTokens = completionTokens
        tokenMetrics.totalTokens = promptTokens + completionTokens
        tokenMetrics.contextTokensUsed = min(tokenMetrics.totalTokens, tokenMetrics.maxContextTokens)
        
        latencyMetrics.timeToFirstToken = timeToFirstToken
        latencyMetrics.totalGenerationTime = totalGenerationTime
        latencyMetrics.promptProcessingTime = timeToFirstToken
        
        if completionTokens > 0 {
            latencyMetrics.timePerToken = (totalGenerationTime - timeToFirstToken) / Double(completionTokens)
            latencyMetrics.tokensPerSecond = Double(completionTokens) / (totalGenerationTime - timeToFirstToken)
        }
        
        latencyMetrics.lastMeasurement = Date()
    }
    
    func setContextSetting(_ key: String, value: Any) {
        switch key {
        case "num_ctx":
            if let value = value as? Int {
                contextSettings.numCtx = value
                tokenMetrics.maxContextTokens = value
            }
        case "num_batch":
            if let value = value as? Int {
                contextSettings.numBatch = value
            }
        case "num_gpu":
            if let value = value as? Int {
                contextSettings.numGpu = value
            }
        case "num_thread":
            if let value = value as? Int {
                contextSettings.numThread = value
            }
        case "f16_kv":
            if let value = value as? Bool {
                contextSettings.f16Kv = value
            }
        default:
            break
        }
    }
    
    func getContextSettingsAsEnvironmentVariables() -> [String: String] {
        return [
            "OLLAMA_NUM_CTX": String(contextSettings.numCtx),
            "OLLAMA_NUM_BATCH": String(contextSettings.numBatch),
            "OLLAMA_NUM_GPU": String(contextSettings.numGpu),
            "OLLAMA_NUM_THREAD": String(contextSettings.numThread),
            "OLLAMA_MAIN_GPU": String(contextSettings.mainGpu),
            "OLLAMA_LOW_VRAM": contextSettings.lowVram ? "1" : "0",
            "OLLAMA_F16_KV": contextSettings.f16Kv ? "1" : "0",
            "OLLAMA_LOGITS_ALL": contextSettings.logitsAll ? "1" : "0",
            "OLLAMA_VOCAB_ONLY": contextSettings.vocabOnly ? "1" : "0",
            "OLLAMA_USE_MMAP": contextSettings.useMmap ? "1" : "0",
            "OLLAMA_USE_MLOCK": contextSettings.useMlock ? "1" : "0",
            "OLLAMA_EMBEDDING_ONLY": contextSettings.embeddingOnly ? "1" : "0"
        ]
    }
    
    func getObservationSnapshot() -> OllamaObservationSnapshot {
        return OllamaObservationSnapshot(
            timestamp: Date(),
            loadedModels: loadedModels,
            contextSettings: contextSettings,
            latencyMetrics: latencyMetrics,
            tokenMetrics: tokenMetrics
        )
    }
    
    func estimateMemoryUsage() -> Double {
        // Estimate memory usage based on loaded models and context
        let modelMemory = loadedModels.reduce(0.0) { $0 + $1.sizeGB }
        let contextMemory = Double(contextSettings.numCtx) * 0.000002 // Rough estimate: 2MB per 1k tokens
        let kvCacheMemory = contextMemory * (contextSettings.f16Kv ? 1.0 : 0.5)
        
        return modelMemory + contextMemory + kvCacheMemory
    }
}

struct OllamaObservationSnapshot {
    let timestamp: Date
    let loadedModels: [OllamaObserver.OllamaModelInfo]
    let contextSettings: OllamaObserver.ContextSettings
    let latencyMetrics: OllamaObserver.LatencyMetrics
    let tokenMetrics: OllamaObserver.TokenMetrics
}
