import Foundation

class OllamaMemoryLevers {
    private let kvGovernor: KVContextGovernor
    private let ramObserver: RAMObserver
    
    init(kvGovernor: KVContextGovernor, ramObserver: RAMObserver) {
        self.kvGovernor = kvGovernor
        self.ramObserver = ramObserver
    }
    
    struct MemoryLever {
        let name: String
        let effect: String
        let currentValue: String
        let action: String
        let claimStatus: ClaimStatus
    }
    
    enum ClaimStatus {
        case verified
        case inferred
        case experimental
    }
    
    func getAllLevers() -> [MemoryLever] {
        return [
            MemoryLever(
                name: "Context Length",
                effect: "Larger context increases KV cache memory usage",
                currentValue: "\(kvGovernor.currentContextLength) tokens",
                action: "Lower when swap or latency rises",
                claimStatus: .verified
            ),
            MemoryLever(
                name: "KV Cache Type",
                effect: "Quantized KV cache reduces memory when Flash Attention enabled",
                currentValue: kvGovernor.kvCacheType.rawValue,
                action: "Test q8 then q4 quality",
                claimStatus: .verified
            ),
            MemoryLever(
                name: "Parallelism",
                effect: "Parallel requests duplicate or expand context memory",
                currentValue: "\(kvGovernor.parallelism) concurrent",
                action: "Keep low on small RAM",
                claimStatus: .verified
            ),
            MemoryLever(
                name: "Model Size",
                effect: "Larger models consume more weight memory",
                currentValue: "Varies by model",
                action: "Route simple tasks to smaller models",
                claimStatus: .verified
            ),
            MemoryLever(
                name: "Prompt Hydration",
                effect: "Dumping full chat expands context and KV",
                currentValue: "Retrieval-based",
                action: "Retrieve memory packets instead",
                claimStatus: .inferred
            )
        ]
    }
    
    func adjustContextLength(trigger: TriggerCondition) {
        switch trigger {
        case .swapPressure:
            kvGovernor.currentContextLength = max(kvGovernor.currentContextLength / 2, 2048)
        case .latencyHigh:
            kvGovernor.currentContextLength = max(kvGovernor.currentContextLength / 2, 4096)
        case .memoryAvailable:
            kvGovernor.currentContextLength = min(kvGovernor.currentContextLength * 2, kvGovernor.maxContextLength)
        case .userRequest(let length):
            kvGovernor.currentContextLength = min(length, kvGovernor.maxContextLength)
        case .userRequestKV:
            break // KV cache type change doesn't affect context length
        }
    }
    
    func adjustKVCacheType(trigger: TriggerCondition) {
        switch trigger {
        case .swapPressure:
            kvGovernor.kvCacheType = .q4_0
        case .latencyHigh:
            kvGovernor.kvCacheType = .q8_0
        case .memoryAvailable:
            kvGovernor.kvCacheType = .f16
        case .userRequest:
            break // Context length change doesn't affect KV cache type
        case .userRequestKV(let type):
            kvGovernor.kvCacheType = type
        }
    }
    
    func adjustParallelism(trigger: TriggerCondition) {
        switch trigger {
        case .swapPressure:
            kvGovernor.parallelism = 1
        case .latencyHigh:
            kvGovernor.parallelism = max(kvGovernor.parallelism - 1, 1)
        case .memoryAvailable:
            kvGovernor.parallelism = min(kvGovernor.parallelism + 1, 4)
        case .userRequest(let count):
            kvGovernor.parallelism = count
        case .userRequestKV:
            break // KV cache type change doesn't affect parallelism
        }
    }
    
    func getCurrentMemoryEstimate() -> MemoryEstimate {
        let kvMemory = kvGovernor.calculateKVCacheMemoryUsage(
            contextLength: kvGovernor.currentContextLength,
            kvCacheType: kvGovernor.kvCacheType
        )
        
        return MemoryEstimate(
            contextLength: kvGovernor.currentContextLength,
            kvCacheMemoryGB: kvMemory,
            kvCacheType: kvGovernor.kvCacheType,
            parallelism: kvGovernor.parallelism,
            estimatedTotalMemoryGB: kvMemory + 2.0 // Base model weight estimate
        )
    }
    
    func getOptimalConfiguration(taskComplexity: TaskComplexity) -> LeverConfiguration {
        let contextLength = kvGovernor.getRecommendedContextLength(taskComplexity: taskComplexity)
        let kvType: KVContextGovernor.KVCacheType
        
        switch ramObserver.memoryPressure {
        case .normal:
            kvType = .f16
        case .yellow:
            kvType = .q8_0
        case .red:
            kvType = .q4_0
        }
        
        return LeverConfiguration(
            contextLength: contextLength,
            kvCacheType: kvType,
            parallelism: taskComplexity == .simple ? 1 : 2,
            promptHydrationStrategy: .retrievalBased
        )
    }
    
    enum TriggerCondition {
        case swapPressure
        case latencyHigh
        case memoryAvailable
        case userRequest(Int)
        case userRequestKV(KVContextGovernor.KVCacheType)
    }
    
    enum PromptHydrationStrategy {
        case fullContext
        case retrievalBased
        case hybrid
    }
}

struct MemoryEstimate {
    let contextLength: Int
    let kvCacheMemoryGB: Double
    let kvCacheType: KVContextGovernor.KVCacheType
    let parallelism: Int
    let estimatedTotalMemoryGB: Double
}

struct LeverConfiguration {
    let contextLength: Int
    let kvCacheType: KVContextGovernor.KVCacheType
    let parallelism: Int
    let promptHydrationStrategy: OllamaMemoryLevers.PromptHydrationStrategy
}
