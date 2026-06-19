import Foundation

class ContextCompressor {
    private var memoryPackets: [MemoryPacket] = []
    private var activeContext: [String] = []
    
    enum CompressionLevel {
        case L0_raw_recent_context    // Keep last N high-salience turns verbatim
        case L1_structured_summary    // Convert old turns into claims, constraints, decisions
        case L2_embedding_memory      // Store chunks in vector index
        case L3_PCA_topic_state       // Compress recurring topics into low-dimensional vectors
        case L4_receipt_ledger        // Keep hashes, citations, file paths, commands
        case L5_cold_archive          // Store full raw text outside active prompt
    }
    
    func compressContext(
        rawContext: String,
        targetLevel: CompressionLevel,
        maxRecentTurns: Int = 3
    ) -> CompressionResult {
        let rawTokens = rawContext.estimatedTokenCount()
        
        switch targetLevel {
        case .L0_raw_recent_context:
            return compressToL0(rawContext: rawContext, maxTurns: maxRecentTurns)
            
        case .L1_structured_summary:
            return compressToL1(rawContext: rawContext)
            
        case .L2_embedding_memory:
            return compressToL2(rawContext: rawContext)
            
        case .L3_PCA_topic_state:
            return compressToL3(rawContext: rawContext)
            
        case .L4_receipt_ledger:
            return compressToL4(rawContext: rawContext)
            
        case .L5_cold_archive:
            return compressToL5(rawContext: rawContext)
        }
    }
    
    // L0: Keep last N high-salience turns verbatim
    private func compressToL0(rawContext: String, maxTurns: Int) -> CompressionResult {
        let turns = extractTurns(from: rawContext)
        let recentTurns = Array(turns.suffix(maxTurns))
        let compressed = recentTurns.joined(separator: "\n")
        
        return CompressionResult(
            compressedContent: compressed,
            originalTokens: rawContext.estimatedTokenCount(),
            compressedTokens: compressed.estimatedTokenCount(),
            level: .L0_raw_recent_context,
            preservedElements: ["recent_conversation", "high_salience_turns"],
            droppedElements: ["older_turns"]
        )
    }
    
    // L1: Convert old turns into claims, constraints, decisions, artifacts
    private func compressToL1(rawContext: String) -> CompressionResult {
        var packet = MemoryPacket(from: rawContext, sourceType: .chat, path: "current_session")
        
        // Extract structured information
        let claims = extractClaims(from: rawContext)
        let constraints = extractConstraints(from: rawContext)
        let decisions = extractDecisions(from: rawContext)
        let artifacts = extractArtifacts(from: rawContext)
        
        // Build structured summary
        var summary = "## Structured Summary\n\n"
        
        if !claims.isEmpty {
            summary += "### Claims\n"
            for claim in claims {
                summary += "- \(claim)\n"
                packet.claimLedger.addClaim(
                    Claim(statement: claim, evidence: [], confidence: 0.8, timestamp: ISO8601DateFormatter().string(from: Date())),
                    category: .inferred
                )
            }
            summary += "\n"
        }
        
        if !constraints.isEmpty {
            summary += "### Constraints\n"
            for constraint in constraints {
                summary += "- \(constraint)\n"
                packet.taskState.constraints.append(constraint)
            }
            summary += "\n"
        }
        
        if !decisions.isEmpty {
            summary += "### Decisions\n"
            for decision in decisions {
                summary += "- \(decision)\n"
                packet.taskState.decisions.append(
                    Decision(description: decision, rationale: "Extracted from context", timestamp: ISO8601DateFormatter().string(from: Date()))
                )
            }
            summary += "\n"
        }
        
        if !artifacts.isEmpty {
            summary += "### Artifacts\n"
            for artifact in artifacts {
                summary += "- \(artifact)\n"
            }
            summary += "\n"
        }
        
        memoryPackets.append(packet)
        
        return CompressionResult(
            compressedContent: summary,
            originalTokens: rawContext.estimatedTokenCount(),
            compressedTokens: summary.estimatedTokenCount(),
            level: .L1_structured_summary,
            preservedElements: ["claims", "constraints", "decisions", "artifacts"],
            droppedElements: ["conversational_prose", "redundant_explanations"]
        )
    }
    
    // L2: Store chunks in vector index (simulated)
    private func compressToL2(rawContext: String) -> CompressionResult {
        var packet = MemoryPacket(from: rawContext, sourceType: .chat, path: "current_session")
        
        // Extract chunks for embedding
        let chunks = chunkText(rawContext, chunkSize: 500)
        
        // Simulate embedding storage
        var compressed = "## Embedded Memory Chunks\n\n"
        compressed += "Total chunks: \(chunks.count)\n"
        compressed += "Stored in vector index for semantic retrieval\n\n"
        
        // Add retrieval keys
        let entities = extractEntities(from: rawContext)
        let codeSymbols = extractCodeSymbols(from: rawContext)
        
        for entity in entities {
            packet.retrievalKeys.addEntity(entity)
        }
        
        for symbol in codeSymbols {
            packet.retrievalKeys.addCodeSymbol(symbol)
        }
        
        compressed += "Entities: \(entities.joined(separator: ", "))\n"
        compressed += "Code symbols: \(codeSymbols.joined(separator: ", "))\n"
        
        memoryPackets.append(packet)
        
        return CompressionResult(
            compressedContent: compressed,
            originalTokens: rawContext.estimatedTokenCount(),
            compressedTokens: compressed.estimatedTokenCount(),
            level: .L2_embedding_memory,
            preservedElements: ["semantic_chunks", "retrieval_keys"],
            droppedElements: ["full_text", "word_order"]
        )
    }
    
    // L3: Compress recurring topics into low-dimensional project vectors
    private func compressToL3(rawContext: String) -> CompressionResult {
        let topics = extractTopics(from: rawContext)
        
        var compressed = "## Topic State Compression\n\n"
        compressed += "Active topics: \(topics.count)\n\n"
        
        for (index, topic) in topics.enumerated() {
            compressed += "Topic \(index + 1): \(topic.name) (weight: \(String(format: "%.2f", topic.weight)))\n"
            compressed += "  Keywords: \(topic.keywords.joined(separator: ", "))\n\n"
        }
        
        return CompressionResult(
            compressedContent: compressed,
            originalTokens: rawContext.estimatedTokenCount(),
            compressedTokens: compressed.estimatedTokenCount(),
            level: .L3_PCA_topic_state,
            preservedElements: ["topic_vectors", "semantic_clusters"],
            droppedElements: ["detailed_discussions", "topic_evolution"]
        )
    }
    
    // L4: Keep hashes, citations, file paths, commands, outputs
    private func compressToL4(rawContext: String) -> CompressionResult {
        var packet = MemoryPacket(from: rawContext, sourceType: .chat, path: "current_session")
        
        let fileReferences = extractFileReferences(from: rawContext)
        let commands = extractCommands(from: rawContext)
        let citations = extractCitations(from: rawContext)
        
        var compressed = "## Receipt Ledger\n\n"
        
        if !fileReferences.isEmpty {
            compressed += "### File References\n"
            for file in fileReferences {
                compressed += "- \(file.path) (hash: \(file.hash))\n"
                packet.retrievalKeys.addFilePath(file.path)
                packet.taskState.artifacts.append(
                    Artifact(type: "file", path: file.path, hash: file.hash, timestamp: ISO8601DateFormatter().string(from: Date()))
                )
            }
            compressed += "\n"
        }
        
        if !commands.isEmpty {
            compressed += "### Commands Executed\n"
            for command in commands {
                compressed += "- \(command.command)\n"
                compressed += "  Output: \(command.output.prefix(100))...\n"
            }
            compressed += "\n"
        }
        
        if !citations.isEmpty {
            compressed += "### Citations\n"
            for citation in citations {
                compressed += "- \(citation)\n"
            }
            compressed += "\n"
        }
        
        memoryPackets.append(packet)
        
        return CompressionResult(
            compressedContent: compressed,
            originalTokens: rawContext.estimatedTokenCount(),
            compressedTokens: compressed.estimatedTokenCount(),
            level: .L4_receipt_ledger,
            preservedElements: ["file_hashes", "commands", "citations"],
            droppedElements: ["explanatory_text", "context"]
        )
    }
    
    // L5: Store full raw text outside active prompt
    private func compressToL5(rawContext: String) -> CompressionResult {
        var packet = MemoryPacket(from: rawContext, sourceType: .chat, path: "archive")
        
        // Store full content in archive (simulated)
        let archivePath = archiveContent(rawContext, packetId: packet.packetId)
        
        let compressed = "## Cold Archive Reference\n\n"
        compressed += "Full content archived at: \(archivePath)\n"
        compressed += "Packet ID: \(packet.packetId)\n"
        compressed += "Use retrieval to access specific sections\n"
        
        memoryPackets.append(packet)
        
        return CompressionResult(
            compressedContent: compressed,
            originalTokens: rawContext.estimatedTokenCount(),
            compressedTokens: compressed.estimatedTokenCount(),
            level: .L5_cold_archive,
            preservedElements: ["full_content", "packet_reference"],
            droppedElements: ["active_prompt_content"]
        )
    }
    
    // Helper functions for extraction
    private func extractTurns(from text: String) -> [String] {
        // Simple turn extraction by newlines
        return text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }
    
    private func extractClaims(from text: String) -> [String] {
        // Extract sentences that look like claims
        let sentences = text.components(separatedBy: ". ")
        return sentences.filter { $0.lowercased().contains("claim") || $0.lowercased().contains("assert") }
    }
    
    private func extractConstraints(from text: String) -> [String] {
        // Extract constraint-like phrases
        let lines = text.components(separatedBy: "\n")
        return lines.filter { $0.lowercased().contains("constraint") || $0.lowercased().contains("requirement") }
    }
    
    private func extractDecisions(from text: String) -> [String] {
        // Extract decision-like phrases
        let lines = text.components(separatedBy: "\n")
        return lines.filter { $0.lowercased().contains("decide") || $0.lowercased().contains("choose") }
    }
    
    private func extractArtifacts(from text: String) -> [String] {
        // Extract file/code references
        let lines = text.components(separatedBy: "\n")
        return lines.filter { $0.contains("file:") || $0.contains("function:") || $0.contains("class:") }
    }
    
    private func chunkText(_ text: String, chunkSize: Int) -> [String] {
        var chunks: [String] = []
        let words = text.components(separatedBy: " ")
        var currentChunk: [String] = []
        
        for word in words {
            currentChunk.append(word)
            if currentChunk.count >= chunkSize {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = []
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }
        
        return chunks
    }
    
    private func extractEntities(from text: String) -> [String] {
        // Simple entity extraction (capitalized words)
        let words = text.components(separatedBy: " ")
        return words.filter { $0.first?.isUppercase == true && $0.count > 2 }
    }
    
    private func extractCodeSymbols(from text: String) -> [String] {
        // Extract code-like patterns
        let patterns = ["func ", "class ", "var ", "let ", "def ", "import "]
        let lines = text.components(separatedBy: "\n")
        var symbols: [String] = []
        
        for line in lines {
            for pattern in patterns {
                if line.contains(pattern) {
                    symbols.append(line.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        return symbols
    }
    
    private func extractTopics(from text: String) -> [Topic] {
        // Simple topic extraction based on word frequency
        let words = text.lowercased().components(separatedBy: " ")
        let wordCounts = Dictionary(grouping: words, by: { $0 }).mapValues { $0.count }
        
        let topWords = wordCounts.sorted { $0.value > $1.value }.prefix(5)
        
        return topWords.map { Topic(name: $0.key, weight: Double($0.value) / Double(words.count), keywords: []) }
    }
    
    private func extractFileReferences(from text: String) -> [FileReference] {
        // Extract file paths
        let patterns = ["/", "~", ".swift", ".py", ".js", ".ts"]
        let words = text.components(separatedBy: " ")
        var files: [FileReference] = []
        
        for word in words {
            for pattern in patterns {
                if word.contains(pattern) && word.count > 3 {
                    files.append(FileReference(path: word, hash: computeHash(word)))
                    break
                }
            }
        }
        
        return files
    }
    
    private func extractCommands(from text: String) -> [CommandExecution] {
        // Extract shell commands
        let lines = text.components(separatedBy: "\n")
        var commands: [CommandExecution] = []
        
        for line in lines {
            if line.hasPrefix("$") || line.hasPrefix(">") {
                let parts = line.components(separatedBy: " ")
                let command = parts.dropFirst().joined(separator: " ")
                commands.append(CommandExecution(command: command, output: ""))
            }
        }
        
        return commands
    }
    
    private func extractCitations(from text: String) -> [String] {
        // Extract citation-like patterns
        let patterns = ["[", "(", "ref:", "cite:"]
        let lines = text.components(separatedBy: "\n")
        var citations: [String] = []
        
        for line in lines {
            for pattern in patterns {
                if line.contains(pattern) {
                    citations.append(line.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }
        
        return citations
    }
    
    private func archiveContent(_ content: String, packetId: String) -> String {
        // Simulate archiving to disk
        let archiveDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ollamacomputespace")
            .appendingPathComponent("archive")
        
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        
        let archivePath = archiveDir.appendingPathComponent("\(packetId).txt")
        try? content.write(to: archivePath, atomically: true, encoding: .utf8)
        
        return archivePath.path
    }
    
    private func computeHash(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
    
    func retrieveRelevantPackets(query: String, maxPackets: Int = 3) -> [MemoryPacket] {
        // Simple relevance retrieval based on keyword matching
        let queryWords = Set(query.lowercased().components(separatedBy: " "))
        
        let scoredPackets = memoryPackets.map { packet -> (MemoryPacket, Double) in
            var score = 0.0
            
            // Check retrieval keys
            for key in packet.retrievalKeys.entities {
                if queryWords.contains(key.lowercased()) {
                    score += 1.0
                }
            }
            
            for key in packet.retrievalKeys.codeSymbols {
                if queryWords.contains(key.lowercased()) {
                    score += 0.5
                }
            }
            
            for key in packet.retrievalKeys.filePaths {
                if query.lowercased().contains(key.lowercased()) {
                    score += 0.8
                }
            }
            
            return (packet, score)
        }
        
        return scoredPackets
            .sorted { $0.1 > $1.1 }
            .prefix(maxPackets)
            .map { $0.0 }
    }
}

struct CompressionResult {
    let compressedContent: String
    let originalTokens: Int
    let compressedTokens: Int
    let level: ContextCompressor.CompressionLevel
    let preservedElements: [String]
    let droppedElements: [String]
    
    var compressionRatio: Double {
        guard compressedTokens > 0 else { return 1.0 }
        return Double(originalTokens) / Double(compressedTokens)
    }
}

struct Topic {
    let name: String
    let weight: Double
    var keywords: [String]
}

struct FileReference {
    let path: String
    let hash: String
}

struct CommandExecution {
    let command: String
    let output: String
}
