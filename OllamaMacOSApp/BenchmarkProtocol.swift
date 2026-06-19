import Foundation

class BenchmarkProtocol {
    private let ramObserver: RAMObserver
    private let ollamaObserver: OllamaObserver
    private let contextCompressor: ContextCompressor
    private let kvContextGovernor: KVContextGovernor
    private let qualityVerifier: QualityVerifier
    private let receiptSystem: CompressionReceiptSystem
    
    init(
        ramObserver: RAMObserver,
        ollamaObserver: OllamaObserver,
        contextCompressor: ContextCompressor,
        kvContextGovernor: KVContextGovernor,
        qualityVerifier: QualityVerifier,
        receiptSystem: CompressionReceiptSystem
    ) {
        self.ramObserver = ramObserver
        self.ollamaObserver = ollamaObserver
        self.contextCompressor = contextCompressor
        self.kvContextGovernor = kvContextGovernor
        self.qualityVerifier = qualityVerifier
        self.receiptSystem = receiptSystem
    }
    
    enum BenchmarkTask {
        case longChatResume
        case repoQuestionAnswering
        case codingAgentPatch
        case multiFileDebug
        case documentSummarization
    }
    
    struct BenchmarkConfiguration {
        let task: BenchmarkTask
        let model: String
        let baselineContext: String
        let expectedAnswer: String
        let taskType: KVContextGovernor.TaskType
    }
    
    struct BenchmarkResult {
        let timestamp: Date
        let task: BenchmarkTask
        let model: String
        
        // Baseline metrics (no compression)
        let baselineMetrics: TaskMetrics
        
        // Treatment metrics (with cognition compression)
        let treatmentMetrics: TaskMetrics
        
        // Comparison
        let comparison: ComparisonMetrics
        
        // Pass/fail
        let passed: Bool
        let failureReasons: [String]
    }
    
    struct TaskMetrics {
        let promptTokens: Int
        let peakRAMGB: Double
        let swapUsedGB: Double
        let compressedMemoryGB: Double
        let timeToFirstToken: TimeInterval
        let tokensPerSecond: Double
        let answerAccuracy: Double
        let patchSuccessRate: Double
        let hallucinationRate: Double
    }
    
    struct ComparisonMetrics {
        let promptTokenReduction: Double
        let peakRAMReductionGB: Double
        let swapReductionGB: Double
        let compressedMemoryReductionGB: Double
        let latencyChange: TimeInterval
        let tpsChange: Double
        let accuracyChange: Double
        let patchSuccessChange: Double
        let hallucinationChange: Double
    }
    
    func runBenchmark(_ configuration: BenchmarkConfiguration) async throws -> BenchmarkResult {
        let timestamp = Date()
        
        // Run baseline (no compression)
        let baselineMetrics = try await runBaseline(configuration: configuration)
        
        // Run treatment (with cognition compression)
        let treatmentMetrics = try await runTreatment(configuration: configuration)
        
        // Compare
        let comparison = compareMetrics(baseline: baselineMetrics, treatment: treatmentMetrics)
        
        // Evaluate pass/fail
        let (passed, failureReasons) = evaluatePassConditions(comparison: comparison)
        
        return BenchmarkResult(
            timestamp: timestamp,
            task: configuration.task,
            model: configuration.model,
            baselineMetrics: baselineMetrics,
            treatmentMetrics: treatmentMetrics,
            comparison: comparison,
            passed: passed,
            failureReasons: failureReasons
        )
    }
    
    private func runBaseline(configuration: BenchmarkConfiguration) async throws -> TaskMetrics {
        // Measure before
        let ramBefore = measureRAM()
        
        // Run without compression
        let (response, timeToFirstToken, totalTime) = try await runOllama(
            model: configuration.model,
            context: configuration.baselineContext,
            useCompression: false
        )
        
        // Measure after
        let ramAfter = measureRAM()
        
        // Calculate metrics
        let promptTokens = configuration.baselineContext.estimatedTokenCount()
        let peakRAMGB = max(ramBefore.usedGB, ramAfter.usedGB)
        let swapUsedGB = max(ramBefore.swapUsedGB, ramAfter.swapUsedGB)
        let compressedMemoryGB = max(ramBefore.compressedGB, ramAfter.compressedGB)
        let tokensPerSecond = Double(response.estimatedTokenCount()) / (totalTime - timeToFirstToken)
        
        // Evaluate answer quality
        let answerAccuracy = evaluateAnswerAccuracy(
            response: response,
            expected: configuration.expectedAnswer
        )
        
        return TaskMetrics(
            promptTokens: promptTokens,
            peakRAMGB: peakRAMGB,
            swapUsedGB: swapUsedGB,
            compressedMemoryGB: compressedMemoryGB,
            timeToFirstToken: timeToFirstToken,
            tokensPerSecond: tokensPerSecond,
            answerAccuracy: answerAccuracy,
            patchSuccessRate: 0.0, // Would be measured for coding tasks
            hallucinationRate: 0.0 // Would be measured
        )
    }
    
    private func runTreatment(configuration: BenchmarkConfiguration) async throws -> TaskMetrics {
        // Measure before
        let ramBefore = measureRAM()
        
        // Compress context
        let compressionResult = contextCompressor.compressContext(
            rawContext: configuration.baselineContext,
            targetLevel: .L1_structured_summary
        )
        
        // Run with compression
        let (response, timeToFirstToken, totalTime) = try await runOllama(
            model: configuration.model,
            context: compressionResult.compressedContent,
            useCompression: true
        )
        
        // Measure after
        let ramAfter = measureRAM()
        
        // Calculate metrics
        let promptTokens = compressionResult.compressedContent.estimatedTokenCount()
        let peakRAMGB = max(ramBefore.usedGB, ramAfter.usedGB)
        let swapUsedGB = max(ramBefore.swapUsedGB, ramAfter.swapUsedGB)
        let compressedMemoryGB = max(ramBefore.compressedGB, ramAfter.compressedGB)
        let tokensPerSecond = Double(response.estimatedTokenCount()) / (totalTime - timeToFirstToken)
        
        // Evaluate answer quality
        let answerAccuracy = evaluateAnswerAccuracy(
            response: response,
            expected: configuration.expectedAnswer
        )
        
        return TaskMetrics(
            promptTokens: promptTokens,
            peakRAMGB: peakRAMGB,
            swapUsedGB: swapUsedGB,
            compressedMemoryGB: compressedMemoryGB,
            timeToFirstToken: timeToFirstToken,
            tokensPerSecond: tokensPerSecond,
            answerAccuracy: answerAccuracy,
            patchSuccessRate: 0.0,
            hallucinationRate: 0.0
        )
    }
    
    private func runOllama(
        model: String,
        context: String,
        useCompression: Bool
    ) async throws -> (String, TimeInterval, TimeInterval) {
        // This would call OllamaManager
        // For now, simulate
        let response = "Simulated response"
        let timeToFirstToken = 0.5
        let totalTime = 2.0
        
        return (response, timeToFirstToken, totalTime)
    }
    
    private func measureRAM() -> (usedGB: Double, swapUsedGB: Double, compressedGB: Double) {
        return (
            usedGB: ramObserver.systemUsedGB,
            swapUsedGB: ramObserver.systemSwapUsedGB,
            compressedGB: ramObserver.systemCompressedGB
        )
    }
    
    private func compareMetrics(baseline: TaskMetrics, treatment: TaskMetrics) -> ComparisonMetrics {
        return ComparisonMetrics(
            promptTokenReduction: Double(baseline.promptTokens - treatment.promptTokens) / Double(baseline.promptTokens),
            peakRAMReductionGB: baseline.peakRAMGB - treatment.peakRAMGB,
            swapReductionGB: baseline.swapUsedGB - treatment.swapUsedGB,
            compressedMemoryReductionGB: baseline.compressedMemoryGB - treatment.compressedMemoryGB,
            latencyChange: treatment.timeToFirstToken - baseline.timeToFirstToken,
            tpsChange: treatment.tokensPerSecond - baseline.tokensPerSecond,
            accuracyChange: treatment.answerAccuracy - baseline.answerAccuracy,
            patchSuccessChange: treatment.patchSuccessRate - baseline.patchSuccessRate,
            hallucinationChange: treatment.hallucinationRate - baseline.hallucinationRate
        )
    }
    
    private func evaluatePassConditions(comparison: ComparisonMetrics) -> (Bool, [String]) {
        var failureReasons: [String] = []
        
        // Pass condition: lower peak memory
        if comparison.peakRAMReductionGB < 0 {
            failureReasons.append("Peak memory increased instead of decreased")
        }
        
        // Pass condition: lower or equal swap
        if comparison.swapReductionGB < -0.1 {
            failureReasons.append("Swap usage increased significantly")
        }
        
        // Pass condition: faster or equal latency
        if comparison.latencyChange > 0.5 {
            failureReasons.append("Latency degraded significantly")
        }
        
        // Pass condition: no material quality loss
        if comparison.accuracyChange < -0.1 {
            failureReasons.append("Answer accuracy degraded significantly")
        }
        
        return (failureReasons.isEmpty, failureReasons)
    }
    
    private func evaluateAnswerAccuracy(response: String, expected: String) -> Double {
        // Simple similarity check
        let responseWords = Set(response.lowercased().components(separatedBy: " "))
        let expectedWords = Set(expected.lowercased().components(separatedBy: " "))
        
        let intersection = responseWords.intersection(expectedWords)
        let union = responseWords.union(expectedWords)
        
        if union.isEmpty {
            return 0.0
        }
        
        return Double(intersection.count) / Double(union.count)
    }
    
    func runBenchmarkSuite() async throws -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []
        
        // Define benchmark configurations
        let configurations: [BenchmarkConfiguration] = [
            // Long chat resume
            BenchmarkConfiguration(
                task: .longChatResume,
                model: "llama3.2",
                baselineContext: generateLongChatContext(),
                expectedAnswer: "Expected answer for long chat",
                taskType: .chatTask
            ),
            
            // Repo question answering
            BenchmarkConfiguration(
                task: .repoQuestionAnswering,
                model: "llama3.2",
                baselineContext: generateRepoContext(),
                expectedAnswer: "Expected answer for repo question",
                taskType: .repoAgentTask
            ),
            
            // Coding agent patch
            BenchmarkConfiguration(
                task: .codingAgentPatch,
                model: "codellama",
                baselineContext: generateCodingContext(),
                expectedAnswer: "Expected patch",
                taskType: .codingTask
            ),
            
            // Multi-file debug
            BenchmarkConfiguration(
                task: .multiFileDebug,
                model: "codellama",
                baselineContext: generateDebugContext(),
                expectedAnswer: "Expected debug solution",
                taskType: .codingTask
            ),
            
            // Document summarization
            BenchmarkConfiguration(
                task: .documentSummarization,
                model: "llama3.2",
                baselineContext: generateDocumentContext(),
                expectedAnswer: "Expected summary",
                taskType: .summarizationTask
            )
        ]
        
        // Run each benchmark
        for config in configurations {
            let result = try await runBenchmark(config)
            results.append(result)
        }
        
        return results
    }
    
    func generateBenchmarkReport(_ results: [BenchmarkResult]) -> String {
        var report = "# Cognition Compression Benchmark Report\n\n"
        report += "Generated: \(Date())\n\n"
        
        report += "## Summary\n\n"
        let passedCount = results.filter { $0.passed }.count
        report += "- Total benchmarks: \(results.count)\n"
        report += "- Passed: \(passedCount)\n"
        report += "- Failed: \(results.count - passedCount)\n\n"
        
        report += "## Detailed Results\n\n"
        
        for result in results {
            report += "### \(result.task)\n"
            report += "- Model: \(result.model)\n"
            report += "- Passed: \(result.passed)\n"
            
            if !result.passed {
                report += "- Failure reasons:\n"
                for reason in result.failureReasons {
                    report += "  - \(reason)\n"
                }
            }
            
            report += "\n#### Comparison\n"
            report += "- Prompt token reduction: \(String(format: "%.2f%%", result.comparison.promptTokenReduction * 100))\n"
            report += "- Peak RAM reduction: \(String(format: "%.2f GB", result.comparison.peakRAMReductionGB))\n"
            report += "- Swap reduction: \(String(format: "%.2f GB", result.comparison.swapReductionGB))\n"
            report += "- Latency change: \(String(format: "%.3f s", result.comparison.latencyChange))\n"
            report += "- TPS change: \(String(format: "%.2f", result.comparison.tpsChange))\n"
            report += "- Accuracy change: \(String(format: "%.2f%%", result.comparison.accuracyChange * 100))\n"
            report += "\n"
        }
        
        return report
    }
    
    // MARK: - Context Generators
    
    private func generateLongChatContext() -> String {
        return """
        This is a simulated long chat context with multiple turns of conversation.
        User: What is the capital of France?
        Assistant: The capital of France is Paris.
        User: Tell me more about Paris.
        Assistant: Paris is the capital and largest city of France...
        [Repeat for many turns to simulate long context]
        """
    }
    
    private func generateRepoContext() -> String {
        return """
        Repository structure:
        - src/main.swift
        - src/utils.swift
        - tests/test_main.swift
        
        Question: How do I add a new function to main.swift?
        """
    }
    
    private func generateCodingContext() -> String {
        return """
        File: src/main.swift
        func calculateSum(a: Int, b: Int) -> Int {
            return a + b
        }
        
        Task: Add error handling to calculateSum.
        """
    }
    
    private func generateDebugContext() -> String {
        return """
        Error in src/main.swift line 15: nil pointer dereference
        Related files:
        - src/main.swift
        - src/utils.swift
        - tests/test_main.swift
        """
    }
    
    private func generateDocumentContext() -> String {
        return """
        [Long document text that needs summarization]
        This document contains information about...
        [Multiple paragraphs of text]
        """
    }
}
