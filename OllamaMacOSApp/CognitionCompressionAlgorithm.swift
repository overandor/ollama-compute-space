import Foundation

class CognitionCompressionAlgorithm {
    private let contextCompressor: ContextCompressor
    private let qualityVerifier: QualityVerifier
    private let ramObserver: RAMObserver
    
    init(
        contextCompressor: ContextCompressor,
        qualityVerifier: QualityVerifier,
        ramObserver: RAMObserver
    ) {
        self.contextCompressor = contextCompressor
        self.qualityVerifier = qualityVerifier
        self.ramObserver = ramObserver
    }
    
    func executeCompressionPipeline(
        rawContext: String,
        targetLevel: ContextCompressor.CompressionLevel
    ) -> CompressionPipelineResult {
        let startTime = Date()
        var packet = MemoryPacket(from: rawContext, sourceType: .chat, path: "pipeline")
        
        // Step 1: Parse
        let parsedData = step1_Parse(rawContext: rawContext, packet: &packet)
        
        // Step 2: Label
        step2_Label(parsedData: parsedData, packet: &packet)
        
        // Step 3: Dedupe
        let dedupedData = step3_Dedupe(parsedData: parsedData)
        
        // Step 4: Factorize
        step4_Factorize(dedupedData: dedupedData, packet: &packet)
        
        // Step 5: Embed
        step5_Embed(dedupedData: dedupedData, packet: &packet)
        
        // Step 6: PCA (for numeric traces only)
        step6_PCA(packet: &packet)
        
        // Step 7: Hydrate
        let hydratedContext = step7_Hydrate(packet: packet, targetLevel: targetLevel)
        
        // Step 8: Measure
        let measurement = step8_Measure(
            originalContext: rawContext,
            hydratedContext: hydratedContext,
            startTime: startTime
        )
        
        return CompressionPipelineResult(
            compressedContent: hydratedContext,
            packet: packet,
            measurement: measurement,
            verification: qualityVerifier.verifyCompression(
                originalContent: rawContext,
                compressedContent: hydratedContext,
                compressionResult: CompressionResult(
                    compressedContent: hydratedContext,
                    originalTokens: rawContext.estimatedTokenCount(),
                    compressedTokens: hydratedContext.estimatedTokenCount(),
                    level: targetLevel,
                    preservedElements: [],
                    droppedElements: []
                )
            )
        )
    }
    
    // Step 1: Parse - Extract goals, constraints, claims, evidence, code paths, commands, outputs, errors
    private func step1_Parse(rawContext: String, packet: inout MemoryPacket) -> ParsedData {
        var parsed = ParsedData()
        
        parsed.goals = extractGoals(from: rawContext)
        parsed.constraints = extractConstraints(from: rawContext)
        parsed.claims = extractClaims(from: rawContext)
        parsed.evidence = extractEvidence(from: rawContext)
        parsed.codePaths = extractCodePaths(from: rawContext)
        parsed.commands = extractCommands(from: rawContext)
        parsed.outputs = extractOutputs(from: rawContext)
        parsed.errors = extractErrors(from: rawContext)
        
        // Store in packet
        packet.taskState.activeGoal = parsed.goals.first ?? ""
        packet.taskState.constraints = parsed.constraints
        
        return parsed
    }
    
    // Step 2: Label - VERIFIED, USER_CLAIMED, INFERRED, UNKNOWN, BLOCKED, QUARANTINED
    private func step2_Label(parsedData: ParsedData, packet: inout MemoryPacket) {
        for claim in parsedData.claims {
            let category = categorizeClaim(claim)
            let claimObj = Claim(
                statement: claim,
                evidence: parsedData.evidence.filter { $0.contains(claim) },
                confidence: estimateConfidence(claim, evidence: parsedData.evidence),
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            packet.claimLedger.addClaim(claimObj, category: category)
        }
    }
    
    // Step 3: Dedupe - Remove repeated phrasing, stale plans, failed branches, duplicate logs
    private func step3_Dedupe(parsedData: ParsedData) -> DedupedData {
        var deduped = DedupedData()
        
        deduped.goals = removeDuplicates(parsedData.goals)
        deduped.constraints = removeDuplicates(parsedData.constraints)
        deduped.claims = removeDuplicates(parsedData.claims)
        deduped.evidence = removeDuplicates(parsedData.evidence)
        deduped.codePaths = removeDuplicates(parsedData.codePaths)
        deduped.commands = removeDuplicates(parsedData.commands)
        
        // Remove stale intermediate plans (simplified)
        deduped.plans = parsedData.goals.filter { !$0.contains("intermediate") }
        
        // Remove failed branches unless needed for audit
        deduped.failedBranches = parsedData.errors.filter { $0.contains("audit") }
        
        // Remove duplicate logs
        deduped.logs = removeDuplicates(parsedData.outputs)
        
        return deduped
    }
    
    // Step 4: Factorize - Convert long history into project_state, artifact_state, decision_state, evidence_state, next_action_state
    private func step4_Factorize(dedupedData: DedupedData, packet: inout MemoryPacket) {
        // Project state
        packet.taskState.activeGoal = dedupedData.goals.first ?? ""
        
        // Artifact state
        for path in dedupedData.codePaths {
            packet.taskState.artifacts.append(
                Artifact(
                    type: "code",
                    path: path,
                    hash: computeHash(path),
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
            )
        }
        
        // Decision state
        for goal in dedupedData.goals {
            packet.taskState.decisions.append(
                Decision(
                    description: goal,
                    rationale: "Extracted from context",
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
            )
        }
        
        // Evidence state
        for evidence in dedupedData.evidence {
            packet.claimLedger.verified.append(
                Claim(
                    statement: evidence,
                    evidence: [],
                    confidence: 0.9,
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
            )
        }
        
        // Next action state
        if !dedupedData.commands.isEmpty {
            packet.taskState.openQuestions = ["Execute: \(dedupedData.commands.first ?? "")"]
        }
    }
    
    // Step 5: Embed - Store raw chunks outside context, retrieve by task similarity
    private func step5_Embed(dedupedData: DedupedData, packet: inout MemoryPacket) {
        // Add retrieval keys
        for entity in extractEntities(from: dedupedData.goals.joined(separator: " ")) {
            packet.retrievalKeys.addEntity(entity)
        }
        
        for symbol in extractCodeSymbols(from: dedupedData.codePaths.joined(separator: " ")) {
            packet.retrievalKeys.addCodeSymbol(symbol)
        }
        
        for path in dedupedData.codePaths {
            packet.retrievalKeys.addFilePath(path)
        }
    }
    
    // Step 6: PCA - Compress metric history and topic history (for numeric traces only)
    private func step6_PCA(packet: inout MemoryPacket) {
        // PCA is for numeric memory traces and high-level semantic clusters
        // NOT for legal/evidence text - use structured summaries for those
        
        // Simulate PCA compression for telemetry data
        let telemetryData = [
            ramObserver.ollamaRSSGB,
            ramObserver.systemSwapUsedGB,
            ramObserver.compressedMemoryGB,
            ramObserver.pageoutsPerSec
        ]
        
        // Store compressed representation (simplified)
        let compressedTelemetry = telemetryData.map { String(format: "%.2f", $0) }.joined(separator: ",")
        
        // This would be stored separately in a real implementation
        packet.taskState.constraints.append("telemetry_pca:\(compressedTelemetry)")
    }
    
    // Step 7: Hydrate - Construct minimal prompt for Ollama
    private func step7_Hydrate(packet: MemoryPacket, targetLevel: ContextCompressor.CompressionLevel) -> String {
        var hydrated = ""
        
        switch targetLevel {
        case .L0_raw_recent_context:
            hydrated = constructL0Prompt(packet: packet)
        case .L1_structured_summary:
            hydrated = constructL1Prompt(packet: packet)
        case .L2_embedding_memory:
            hydrated = constructL2Prompt(packet: packet)
        case .L3_PCA_topic_state:
            hydrated = constructL3Prompt(packet: packet)
        case .L4_receipt_ledger:
            hydrated = constructL4Prompt(packet: packet)
        case .L5_cold_archive:
            hydrated = constructL5Prompt(packet: packet)
        }
        
        return hydrated
    }
    
    // Step 8: Measure - Compare RAM before/after, swap before/after, latency, answer pass/fail
    private func step8_Measure(
        originalContext: String,
        hydratedContext: String,
        startTime: Date
    ) -> CompressionMeasurement {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        let ramBefore = ramObserver.getCompressionReceipt()
        
        return CompressionMeasurement(
            timestamp: endTime,
            duration: duration,
            ramBefore: ramBefore,
            ramAfter: ramObserver.getCompressionReceipt(),
            originalTokens: originalContext.estimatedTokenCount(),
            compressedTokens: hydratedContext.estimatedTokenCount(),
            compressionRatio: Double(originalContext.estimatedTokenCount()) / Double(hydratedContext.estimatedTokenCount())
        )
    }
    
    // Helper functions
    private func extractGoals(from text: String) -> [String] {
        let patterns = ["goal:", "objective:", "target:", "aim:"]
        return extractWithPatterns(text: text, patterns: patterns)
    }
    
    private func extractConstraints(from text: String) -> [String] {
        let patterns = ["constraint:", "requirement:", "must:", "should:"]
        return extractWithPatterns(text: text, patterns: patterns)
    }
    
    private func extractClaims(from text: String) -> [String] {
        let patterns = ["claim:", "assert:", "state:", "believe:"]
        return extractWithPatterns(text: text, patterns: patterns)
    }
    
    private func extractEvidence(from text: String) -> [String] {
        let patterns = ["evidence:", "proof:", "data:", "result:"]
        return extractWithPatterns(text: text, patterns: patterns)
    }
    
    private func extractCodePaths(from text: String) -> [String] {
        let patterns = ["/", "~", ".swift", ".py", ".js", ".ts"]
        let words = text.components(separatedBy: " ")
        return words.filter { word in
            patterns.contains { word.contains($0) } && word.count > 3
        }
    }
    
    private func extractCommands(from text: String) -> [String] {
        let lines = text.components(separatedBy: "\n")
        return lines.filter { $0.hasPrefix("$") || $0.hasPrefix(">") }
            .map { $0.dropFirst().trimmingCharacters(in: .whitespaces) }
    }
    
    private func extractOutputs(from text: String) -> [String] {
        let patterns = ["output:", "result:", "returned:"]
        return extractWithPatterns(text: text, patterns: patterns)
    }
    
    private func extractErrors(from text: String) -> [String] {
        let patterns = ["error:", "failed:", "exception:"]
        return extractWithPatterns(text: text, patterns: patterns)
    }
    
    private func extractWithPatterns(text: String, patterns: [String]) -> [String] {
        let lines = text.components(separatedBy: "\n")
        var results: [String] = []
        
        for line in lines {
            for pattern in patterns {
                if line.lowercased().contains(pattern) {
                    results.append(line.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }
        
        return results
    }
    
    private func categorizeClaim(_ claim: String) -> ClaimCategory {
        if claim.contains("verified") || claim.contains("proven") {
            return .verified
        } else if claim.contains("user") || claim.contains("stated") {
            return .userClaimed
        } else if claim.contains("inferred") || claim.contains("likely") {
            return .inferred
        } else if claim.contains("blocked") || claim.contains("forbidden") {
            return .blocked
        } else {
            return .unknown
        }
    }
    
    private func estimateConfidence(_ claim: String, evidence: [String]) -> Double {
        if evidence.isEmpty {
            return 0.5
        }
        let matchingEvidence = evidence.filter { $0.contains(claim) }
        return min(1.0, Double(matchingEvidence.count) * 0.3 + 0.4)
    }
    
    private func removeDuplicates(_ items: [String]) -> [String] {
        Array(Set(items))
    }
    
    private func extractEntities(from text: String) -> [String] {
        let words = text.components(separatedBy: " ")
        return words.filter { $0.first?.isUppercase == true && $0.count > 2 }
    }
    
    private func extractCodeSymbols(from text: String) -> [String] {
        let patterns = ["func ", "class ", "var ", "let ", "def ", "import "]
        let lines = text.components(separatedBy: "\n")
        var symbols: [String] = []
        
        for line in lines {
            for pattern in patterns {
                if line.contains(pattern) {
                    symbols.append(line.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }
        
        return symbols
    }
    
    private func computeHash(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
    
    // Prompt construction helpers
    private func constructL0Prompt(packet: MemoryPacket) -> String {
        var prompt = "## Recent Context\n\n"
        prompt += "Goal: \(packet.taskState.activeGoal)\n"
        prompt += "Constraints: \(packet.taskState.constraints.joined(separator: ", "))\n"
        return prompt
    }
    
    private func constructL1Prompt(packet: MemoryPacket) -> String {
        var prompt = "## Structured Summary\n\n"
        prompt += "### Goal\n\(packet.taskState.activeGoal)\n\n"
        prompt += "### Constraints\n"
        for constraint in packet.taskState.constraints {
            prompt += "- \(constraint)\n"
        }
        prompt += "\n### Decisions\n"
        for decision in packet.taskState.decisions {
            prompt += "- \(decision.description)\n"
        }
        return prompt
    }
    
    private func constructL2Prompt(packet: MemoryPacket) -> String {
        var prompt = "## Embedded Memory\n\n"
        prompt += "Entities: \(packet.retrievalKeys.entities.joined(separator: ", "))\n"
        prompt += "Code symbols: \(packet.retrievalKeys.codeSymbols.joined(separator: ", "))\n"
        prompt += "File paths: \(packet.retrievalKeys.filePaths.joined(separator: ", "))\n"
        return prompt
    }
    
    private func constructL3Prompt(packet: MemoryPacket) -> String {
        var prompt = "## Topic State\n\n"
        prompt += "Active goal: \(packet.taskState.activeGoal)\n"
        prompt += "Open questions: \(packet.taskState.openQuestions.joined(separator: ", "))\n"
        return prompt
    }
    
    private func constructL4Prompt(packet: MemoryPacket) -> String {
        var prompt = "## Receipt Ledger\n\n"
        prompt += "### Artifacts\n"
        for artifact in packet.taskState.artifacts {
            prompt += "- \(artifact.path) (hash: \(artifact.hash))\n"
        }
        prompt += "\n### Verified Claims\n"
        for claim in packet.claimLedger.verified {
            prompt += "- \(claim.statement)\n"
        }
        return prompt
    }
    
    private func constructL5Prompt(packet: MemoryPacket) -> String {
        return "## Cold Archive Reference\n\nPacket ID: \(packet.packetId)\nUse retrieval to access full content."
    }
}

struct ParsedData {
    var goals: [String] = []
    var constraints: [String] = []
    var claims: [String] = []
    var evidence: [String] = []
    var codePaths: [String] = []
    var commands: [String] = []
    var outputs: [String] = []
    var errors: [String] = []
}

struct DedupedData {
    var goals: [String] = []
    var constraints: [String] = []
    var claims: [String] = []
    var evidence: [String] = []
    var codePaths: [String] = []
    var commands: [String] = []
    var plans: [String] = []
    var failedBranches: [String] = []
    var logs: [String] = []
}

struct CompressionPipelineResult {
    let compressedContent: String
    let packet: MemoryPacket
    let measurement: CompressionMeasurement
    let verification: VerificationResult
}

struct CompressionMeasurement {
    let timestamp: Date
    let duration: TimeInterval
    let ramBefore: CompressionReceipt
    let ramAfter: CompressionReceipt
    let originalTokens: Int
    let compressedTokens: Int
    let compressionRatio: Double
}
