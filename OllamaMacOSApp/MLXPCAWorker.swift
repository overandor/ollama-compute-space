import Foundation

class MLXPCAWorker {
    private var telemetryHistory: [MemoryTelemetrySample] = []
    private var components: [PCAComponent] = []
    private let maxHistorySize = 1000
    
    struct MemoryTelemetrySample {
        let timestamp: Date
        let usedGB: Double
        let appGB: Double
        let wiredGB: Double
        let cachedGB: Double
        let compressedGB: Double
        let compressionRatio: Double
        let swapUsedGB: Double
        let pageinsPerSec: Double
        let pageoutsPerSec: Double
        let topProcessRSS: Double
        let rssSlope: Double
        let ollamaLoadedModels: Int
        let contextTokens: Int
        let tokensPerSecond: Double
    }
    
    struct PCAComponent {
        let name: String
        let weights: [Double]
        var currentValue: Double
        let interpretation: String
    }
    
    init() {
        initializeComponents()
    }
    
    private func initializeComponents() {
        // Initialize 6 engineered state indices (not true PCA until MLX worker performs real PCA)
        components = [
            PCAComponent(
                name: "pc1_unified_memory_pressure",
                weights: [0.3, 0.25, 0.2, 0.15, 0.1],
                currentValue: 0.0,
                interpretation: "Combined pressure from used, app, wired, cached, compressed memory"
            ),
            PCAComponent(
                name: "pc2_swap_collapse_risk",
                weights: [0.5, 0.3, 0.2],
                currentValue: 0.0,
                interpretation: "Risk of swap collapse based on swap usage and page rates"
            ),
            PCAComponent(
                name: "pc3_llm_context_pressure",
                weights: [0.4, 0.4, 0.2],
                currentValue: 0.0,
                interpretation: "Pressure from LLM context tokens and loaded models"
            ),
            PCAComponent(
                name: "pc4_model_residency_pressure",
                weights: [0.5, 0.3, 0.2],
                currentValue: 0.0,
                interpretation: "Pressure from model residency and RSS growth"
            ),
            PCAComponent(
                name: "pc5_repo_agent_expansion",
                weights: [0.3, 0.4, 0.3],
                currentValue: 0.0,
                interpretation: "Expansion pressure from repo agent operations"
            ),
            PCAComponent(
                name: "pc6_leak_or_retention_risk",
                weights: [0.4, 0.3, 0.3],
                currentValue: 0.0,
                interpretation: "Risk of memory leak or excessive retention"
            )
        ]
    }
    
    func addTelemetrySample(_ sample: MemoryTelemetrySample) {
        telemetryHistory.append(sample)
        
        if telemetryHistory.count > maxHistorySize {
            telemetryHistory.removeFirst()
        }
        
        updateComponents()
    }
    
    private func updateComponents() {
        guard !telemetryHistory.isEmpty else { return }
        
        let latest = telemetryHistory.last!
        
        // PC1: Unified Memory Pressure
        components[0].currentValue = calculateUnifiedMemoryPressure(from: latest)
        
        // PC2: Swap Collapse Risk
        components[1].currentValue = calculateSwapCollapseRisk(from: latest)
        
        // PC3: LLM Context Pressure
        components[2].currentValue = calculateLLMContextPressure(from: latest)
        
        // PC4: Model Residency Pressure
        components[3].currentValue = calculateModelResidencyPressure(from: latest)
        
        // PC5: Repo Agent Expansion
        components[4].currentValue = calculateRepoAgentExpansion(from: latest)
        
        // PC6: Leak or Retention Risk
        components[5].currentValue = calculateLeakOrRetentionRisk(from: latest)
    }
    
    private func calculateUnifiedMemoryPressure(from sample: MemoryTelemetrySample) -> Double {
        // Normalize and combine memory metrics
        let normalizedUsed = min(sample.usedGB / 64.0, 1.0) // Assume 64GB max
        let normalizedApp = min(sample.appGB / 32.0, 1.0) // Assume 32GB max
        let normalizedWired = min(sample.wiredGB / 16.0, 1.0) // Assume 16GB max
        let normalizedCached = min(sample.cachedGB / 32.0, 1.0) // Assume 32GB max
        let normalizedCompressed = min(sample.compressedGB / 16.0, 1.0) // Assume 16GB max
        
        let weights = components[0].weights
        return weights[0] * normalizedUsed +
               weights[1] * normalizedApp +
               weights[2] * normalizedWired +
               weights[3] * normalizedCached +
               weights[4] * normalizedCompressed
    }
    
    private func calculateSwapCollapseRisk(from sample: MemoryTelemetrySample) -> Double {
        let normalizedSwap = min(sample.swapUsedGB / 32.0, 1.0) // Assume 32GB max
        let normalizedPageouts = min(sample.pageoutsPerSec / 1000.0, 1.0) // Assume 1000/sec max
        let normalizedPageins = min(sample.pageinsPerSec / 1000.0, 1.0) // Assume 1000/sec max
        
        let weights = components[1].weights
        return weights[0] * normalizedSwap +
               weights[1] * normalizedPageouts +
               weights[2] * normalizedPageins
    }
    
    private func calculateLLMContextPressure(from sample: MemoryTelemetrySample) -> Double {
        let normalizedContext = min(Double(sample.contextTokens) / 131072.0, 1.0) // Assume 128k max
        let normalizedModels = min(Double(sample.ollamaLoadedModels) / 5.0, 1.0) // Assume 5 models max
        let normalizedTPS = min(sample.tokensPerSecond / 100.0, 1.0) // Assume 100 TPS max
        
        let weights = components[2].weights
        return weights[0] * normalizedContext +
               weights[1] * normalizedModels +
               weights[2] * normalizedTPS
    }
    
    private func calculateModelResidencyPressure(from sample: MemoryTelemetrySample) -> Double {
        let normalizedRSS = min(sample.topProcessRSS / 32.0, 1.0) // Assume 32GB max
        let normalizedSlope = min(abs(sample.rssSlope) / 1.0, 1.0) // Assume 1GB/sec max
        let normalizedModels = min(Double(sample.ollamaLoadedModels) / 5.0, 1.0)
        
        let weights = components[3].weights
        return weights[0] * normalizedRSS +
               weights[1] * normalizedSlope +
               weights[2] * normalizedModels
    }
    
    private func calculateRepoAgentExpansion(from sample: MemoryTelemetrySample) -> Double {
        let normalizedApp = min(sample.appGB / 32.0, 1.0)
        let normalizedContext = min(Double(sample.contextTokens) / 131072.0, 1.0)
        let normalizedTPS = min(sample.tokensPerSecond / 100.0, 1.0)
        
        let weights = components[4].weights
        return weights[0] * normalizedApp +
               weights[1] * normalizedContext +
               weights[2] * normalizedTPS
    }
    
    private func calculateLeakOrRetentionRisk(from sample: MemoryTelemetrySample) -> Double {
        let normalizedSlope = min(abs(sample.rssSlope) / 1.0, 1.0)
        let normalizedCompressed = min(sample.compressedGB / 16.0, 1.0)
        let normalizedSwap = min(sample.swapUsedGB / 32.0, 1.0)
        
        let weights = components[5].weights
        return weights[0] * normalizedSlope +
               weights[1] * normalizedCompressed +
               weights[2] * normalizedSwap
    }
    
    func getCompressedMemoryState() -> CompressedMemoryState {
        return CompressedMemoryState(
            timestamp: Date(),
            components: components,
            overallPressure: calculateOverallPressure(),
            riskLevel: assessRiskLevel()
        )
    }
    
    private func calculateOverallPressure() -> Double {
        return components.reduce(0.0) { $0 + $1.currentValue } / Double(components.count)
    }
    
    private func assessRiskLevel() -> RiskLevel {
        let overall = calculateOverallPressure()
        
        if overall < 0.3 {
            return .low
        } else if overall < 0.6 {
            return .medium
        } else if overall < 0.8 {
            return .high
        } else {
            return .critical
        }
    }
    
    func detectAnomalies() -> [Anomaly] {
        var anomalies: [Anomaly] = []
        
        guard telemetryHistory.count >= 10 else { return anomalies }
        
        let recent = Array(telemetryHistory.suffix(10))
        let avgRSS = recent.map { $0.topProcessRSS }.reduce(0, +) / Double(recent.count)
        let latestRSS = recent.last!.topProcessRSS
        
        // Detect RSS growth anomaly
        if latestRSS > avgRSS * 1.5 {
            anomalies.append(Anomaly(
                type: .rssGrowth,
                severity: .high,
                description: "RSS grew 50% above recent average",
                value: latestRSS - avgRSS
            ))
        }
        
        // Detect swap spike
        let avgSwap = recent.map { $0.swapUsedGB }.reduce(0, +) / Double(recent.count)
        let latestSwap = recent.last!.swapUsedGB
        
        if latestSwap > avgSwap * 2.0 {
            anomalies.append(Anomaly(
                type: .swapSpike,
                severity: .critical,
                description: "Swap usage doubled",
                value: latestSwap - avgSwap
            ))
        }
        
        // Detect pageout spike
        let avgPageouts = recent.map { $0.pageoutsPerSec }.reduce(0, +) / Double(recent.count)
        let latestPageouts = recent.last!.pageoutsPerSec
        
        if latestPageouts > avgPageouts * 3.0 {
            anomalies.append(Anomaly(
                type: .pageoutSpike,
                severity: .high,
                description: "Pageout rate tripled",
                value: latestPageouts - avgPageouts
            ))
        }
        
        return anomalies
    }
    
    func fitRealPCA() async throws {
        // Placeholder for actual MLX PCA fitting
        // This would use MLX to perform real PCA on telemetry history
        // For now, we use engineered indices as specified in the audit correction
        print("Real PCA fitting not yet implemented - using engineered indices")
    }
}

struct CompressedMemoryState {
    let timestamp: Date
    let components: [MLXPCAWorker.PCAComponent]
    let overallPressure: Double
    let riskLevel: RiskLevel
}

enum RiskLevel {
    case low
    case medium
    case high
    case critical
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
