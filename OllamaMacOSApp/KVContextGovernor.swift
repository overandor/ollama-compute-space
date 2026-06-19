import Foundation

class KVContextGovernor: ObservableObject {
    @Published var currentContextLength: Int = 4096
    @Published var maxContextLength: Int = 4096
    @Published var kvCacheType: KVCacheType = .f16
    @Published var parallelism: Int = 1
    @Published var contextPolicy: ContextPolicy = .smallestContextThatPassesTask
    
    enum KVCacheType: String, CaseIterable {
        case f16 = "f16"
        case q8_0 = "q8_0"
        case q4_0 = "q4_0"
        
        var memoryReductionFactor: Double {
            switch self {
            case .f16: return 1.0
            case .q8_0: return 0.5
            case .q4_0: return 0.25
            }
        }
        
        var qualityImpact: String {
            switch self {
            case .f16: return "None (baseline)"
            case .q8_0: return "Minimal"
            case .q4_0: return "Moderate"
            }
        }
    }
    
    enum ContextPolicy {
        case smallestContextThatPassesTask
        case balancedContext
        case fullContext
        case emergencyShrink
    }
    
    enum TaskType {
        case simple
        case complex
        case codeGeneration
        case analysis
        case smallTask
        case codingTask
        case repoAgentTask
        case chatTask
        case summarizationTask
    }
    
    private let contextLengthTiers: [Int] = [4096, 8192, 16384, 32768, 65536, 131072, 262144]
    
    init() {
        determineInitialContextLength()
    }
    
    private func determineInitialContextLength() {
        // Determine context length based on available memory
        let availableMemoryGB = getAvailableMemoryGB()
        
        switch availableMemoryGB {
        case 0..<24:
            maxContextLength = 4096
        case 24..<48:
            maxContextLength = 32768
        case 48..<96:
            maxContextLength = 262144
        default:
            maxContextLength = 262144
        }
        
        currentContextLength = maxContextLength
    }
    
    private func getAvailableMemoryGB() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let hostResult: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if hostResult == KERN_SUCCESS {
            let pageSize = vm_page_size
            let freeMemory = Double(stats.free_count) * Double(pageSize)
            return freeMemory / 1024.0 / 1024.0 / 1024.0
        }
        
        return 16.0 // Default fallback
    }
    
    func adjustContextBasedOnMemory(pressure: RAMObserver.MemoryPressure, ollamaRSSGB: Double) {
        switch pressure {
        case .normal:
            // Can use full context
            currentContextLength = maxContextLength
            
        case .yellow:
            // Reduce context by 50%
            currentContextLength = max(maxContextLength / 2, 4096)
            
        case .red:
            // Emergency: use minimum context
            currentContextLength = 4096
            contextPolicy = .emergencyShrink
        }
    }
    
    func selectOptimalKVCacheType(pressure: RAMObserver.MemoryPressure) -> KVCacheType {
        switch pressure {
        case .normal:
            return .f16
            
        case .yellow:
            return .q8_0
            
        case .red:
            return .q4_0
        }
    }
    
    func calculateKVCacheMemoryUsage(contextLength: Int, kvCacheType: KVCacheType) -> Double {
        // Rough estimation: KV cache grows with context length
        // Base: ~2GB for 4k context with f16
        let baseMemoryGB = 2.0
        let contextMultiplier = Double(contextLength) / 4096.0
        let kvMultiplier = kvCacheType.memoryReductionFactor
        
        return baseMemoryGB * contextMultiplier * kvMultiplier
    }
    
    func estimateContextTokens(content: String) -> Int {
        return content.estimatedTokenCount()
    }
    
    func shouldCompressContext(currentTokens: Int, targetTokens: Int) -> Bool {
        return currentTokens > targetTokens
    }
    
    func getRecommendedContextLength(taskComplexity: TaskComplexity) -> Int {
        switch taskComplexity {
        case .simple:
            return 4096
        case .moderate:
            return 8192
        case .complex:
            return 16384
        case .veryComplex:
            return maxContextLength
        }
    }
    
    func getDynamicContextLength(taskType: TaskType) -> Int {
        switch taskType {
        case .smallTask:
            // 4k-8k for small tasks
            return min(8192, maxContextLength)
        case .codingTask:
            // 16k-64k for coding tasks
            return min(65536, maxContextLength)
        case .repoAgentTask:
            // 64k when needed for repo agent tasks
            return min(65536, maxContextLength)
        case .chatTask:
            // 4k-16k for chat
            return min(16384, maxContextLength)
        case .summarizationTask:
            // 8k-32k for summarization
            return min(32768, maxContextLength)
        case .simple:
            return min(8192, maxContextLength)
        case .complex:
            return min(32768, maxContextLength)
        case .codeGeneration:
            return min(65536, maxContextLength)
        case .analysis:
            return min(16384, maxContextLength)
        }
    }
    
    func shouldUseLargeContext(taskType: TaskType, estimatedTokens: Int) -> Bool {
        // Rule: never use 64k context for a 2k task
        if estimatedTokens < 2048 {
            return false
        }
        
        switch taskType {
        case .smallTask:
            return false
        case .codingTask:
            return estimatedTokens > 8000
        case .repoAgentTask:
            return estimatedTokens > 16000
        case .chatTask:
            return estimatedTokens > 4000
        case .summarizationTask:
            return estimatedTokens > 8000
        case .simple:
            return estimatedTokens > 4000
        case .complex:
            return estimatedTokens > 8000
        case .codeGeneration:
            return estimatedTokens > 8000
        case .analysis:
            return estimatedTokens > 6000
        }
    }
    
    func setParallelismBasedOnMemory(availableMemoryGB: Double) {
        switch availableMemoryGB {
        case 0..<8:
            parallelism = 1
        case 8..<16:
            parallelism = 2
        case 16..<32:
            parallelism = 4
        default:
            parallelism = 4
        }
    }
    
    func generateOllamaEnvironmentVariables() -> [String: String] {
        return [
            "OLLAMA_KV_CACHE_TYPE": kvCacheType.rawValue,
            "OLLAMA_NUM_PARALLEL": String(parallelism),
            "OLLAMA_MAX_LOADED_MODELS": "1"
        ]
    }
    
    func getContextBudgetReceipt() -> ContextBudgetReceipt {
        let kvMemoryGB = calculateKVCacheMemoryUsage(
            contextLength: currentContextLength,
            kvCacheType: kvCacheType
        )
        
        return ContextBudgetReceipt(
            timestamp: Date(),
            contextLength: currentContextLength,
            maxContextLength: maxContextLength,
            kvCacheType: kvCacheType,
            kvCacheMemoryGB: kvMemoryGB,
            parallelism: parallelism,
            contextPolicy: contextPolicy,
            memoryReductionFromKV: kvCacheType.memoryReductionFactor
        )
    }
}

enum TaskComplexity {
    case simple
    case moderate
    case complex
    case veryComplex
}

enum TaskType {
    case smallTask
    case codingTask
    case repoAgentTask
    case chatTask
    case summarizationTask
}

struct ContextBudgetReceipt {
    let timestamp: Date
    let contextLength: Int
    let maxContextLength: Int
    let kvCacheType: KVContextGovernor.KVCacheType
    let kvCacheMemoryGB: Double
    let parallelism: Int
    let contextPolicy: KVContextGovernor.ContextPolicy
    let memoryReductionFromKV: Double
}
