import Foundation

class QualityVerifier {
    
    func verifyCompression(
        originalContent: String,
        compressedContent: String,
        compressionResult: CompressionResult
    ) -> VerificationResult {
        var preservedElements: [String] = []
        var lostElements: [String] = []
        var warnings: [String] = []
        
        // Check for evidence preservation
        let evidenceCheck = verifyEvidencePreservation(
            original: originalContent,
            compressed: compressedContent
        )
        
        if evidenceCheck.preserved {
            preservedElements.append("evidence")
        } else {
            lostElements.append("evidence")
            warnings.append("Critical evidence may have been lost during compression")
        }
        
        // Check for claim preservation
        let claimCheck = verifyClaimPreservation(
            original: originalContent,
            compressed: compressedContent
        )
        
        if claimCheck.preserved {
            preservedElements.append("claims")
        } else {
            lostElements.append("claims")
            warnings.append("Some claims may have been lost or altered")
        }
        
        // Check for file reference preservation
        let fileCheck = verifyFileReferencePreservation(
            original: originalContent,
            compressed: compressedContent
        )
        
        if fileCheck.preserved {
            preservedElements.append("file_references")
        } else {
            lostElements.append("file_references")
            warnings.append("File references may have been lost")
        }
        
        // Check for command preservation
        let commandCheck = verifyCommandPreservation(
            original: originalContent,
            compressed: compressedContent
        )
        
        if commandCheck.preserved {
            preservedElements.append("commands")
        } else {
            lostElements.append("commands")
            warnings.append("Command history may have been lost")
        }
        
        // Check for decision preservation
        let decisionCheck = verifyDecisionPreservation(
            original: originalContent,
            compressed: compressedContent
        )
        
        if decisionCheck.preserved {
            preservedElements.append("decisions")
        } else {
            lostElements.append("decisions")
            warnings.append("Decision history may have been lost")
        }
        
        // Calculate overall quality score
        let qualityScore = calculateQualityScore(
            preservedCount: preservedElements.count,
            totalChecks: 5,
            compressionRatio: compressionResult.compressionRatio
        )
        
        return VerificationResult(
            timestamp: Date(),
            qualityScore: qualityScore,
            preservedElements: preservedElements,
            lostElements: lostElements,
            warnings: warnings,
            evidenceLoss: !evidenceCheck.preserved,
            claimLabelingPresent: claimCheck.preserved,
            hallucinationRisk: assessHallucinationRisk(compressionResult: compressionResult)
        )
    }
    
    private func verifyEvidencePreservation(original: String, compressed: String) -> PreservationCheck {
        // Look for evidence markers like "evidence:", "proof:", "data:"
        let evidencePatterns = ["evidence:", "proof:", "data:", "result:", "output:"]
        
        var originalEvidenceCount = 0
        var compressedEvidenceCount = 0
        
        for pattern in evidencePatterns {
            originalEvidenceCount += original.components(separatedBy: pattern).count - 1
            compressedEvidenceCount += compressed.components(separatedBy: pattern).count - 1
        }
        
        // Allow some loss if compression ratio is high
        let tolerance = 0.3 // 30% tolerance
        let preserved = Double(compressedEvidenceCount) >= Double(originalEvidenceCount) * (1.0 - tolerance)
        
        return PreservationCheck(
            preserved: preserved,
            originalCount: originalEvidenceCount,
            compressedCount: compressedEvidenceCount
        )
    }
    
    private func verifyClaimPreservation(original: String, compressed: String) -> PreservationCheck {
        // Look for claim markers
        let claimPatterns = ["claim:", "assert:", "state:", "believe:", "conclude:"]
        
        var originalClaimCount = 0
        var compressedClaimCount = 0
        
        for pattern in claimPatterns {
            originalClaimCount += original.components(separatedBy: pattern).count - 1
            compressedClaimCount += compressed.components(separatedBy: pattern).count - 1
        }
        
        let preserved = compressedClaimCount >= originalClaimCount
        
        return PreservationCheck(
            preserved: preserved,
            originalCount: originalClaimCount,
            compressedCount: compressedClaimCount
        )
    }
    
    private func verifyFileReferencePreservation(original: String, compressed: String) -> PreservationCheck {
        // Look for file paths
        let filePatterns = ["/", "~", ".swift", ".py", ".js", ".ts", ".txt", ".md"]
        
        var originalFileCount = 0
        var compressedFileCount = 0
        
        let originalWords = original.components(separatedBy: " ")
        let compressedWords = compressed.components(separatedBy: " ")
        
        for word in originalWords {
            for pattern in filePatterns {
                if word.contains(pattern) && word.count > 3 {
                    originalFileCount += 1
                    break
                }
            }
        }
        
        for word in compressedWords {
            for pattern in filePatterns {
                if word.contains(pattern) && word.count > 3 {
                    compressedFileCount += 1
                    break
                }
            }
        }
        
        let preserved = compressedFileCount >= originalFileCount
        
        return PreservationCheck(
            preserved: preserved,
            originalCount: originalFileCount,
            compressedCount: compressedFileCount
        )
    }
    
    private func verifyCommandPreservation(original: String, compressed: String) -> PreservationCheck {
        // Look for command markers
        let commandPatterns = ["$", ">", "sudo", "npm", "pip", "git", "cargo"]
        
        var originalCommandCount = 0
        var compressedCommandCount = 0
        
        let originalLines = original.components(separatedBy: "\n")
        let compressedLines = compressed.components(separatedBy: "\n")
        
        for line in originalLines {
            for pattern in commandPatterns {
                if line.contains(pattern) {
                    originalCommandCount += 1
                    break
                }
            }
        }
        
        for line in compressedLines {
            for pattern in commandPatterns {
                if line.contains(pattern) {
                    compressedCommandCount += 1
                    break
                }
            }
        }
        
        let preserved = compressedCommandCount >= originalCommandCount
        
        return PreservationCheck(
            preserved: preserved,
            originalCount: originalCommandCount,
            compressedCount: compressedCommandCount
        )
    }
    
    private func verifyDecisionPreservation(original: String, compressed: String) -> PreservationCheck {
        // Look for decision markers
        let decisionPatterns = ["decide:", "choose:", "select:", "opt:", "prefer:"]
        
        var originalDecisionCount = 0
        var compressedDecisionCount = 0
        
        for pattern in decisionPatterns {
            originalDecisionCount += original.components(separatedBy: pattern).count - 1
            compressedDecisionCount += compressed.components(separatedBy: pattern).count - 1
        }
        
        let preserved = compressedDecisionCount >= originalDecisionCount
        
        return PreservationCheck(
            preserved: preserved,
            originalCount: originalDecisionCount,
            compressedCount: compressedDecisionCount
        )
    }
    
    private func calculateQualityScore(
        preservedCount: Int,
        totalChecks: Int,
        compressionRatio: Double
    ) -> Double {
        let preservationScore = Double(preservedCount) / Double(totalChecks)
        
        // Factor in compression ratio - higher compression is good but shouldn't sacrifice quality
        let compressionScore = min(compressionRatio / 5.0, 1.0) // Normalize to 0-1
        
        // Weight preservation more heavily (70%) than compression (30%)
        return (preservationScore * 0.7) + (compressionScore * 0.3)
    }
    
    private func assessHallucinationRisk(compressionResult: CompressionResult) -> HallucinationRisk {
        // Higher compression levels increase hallucination risk
        switch compressionResult.level {
        case .L0_raw_recent_context:
            return .low
        case .L1_structured_summary:
            return .low
        case .L2_embedding_memory:
            return .medium
        case .L3_PCA_topic_state:
            return .medium
        case .L4_receipt_ledger:
            return .low // Structured data is safe
        case .L5_cold_archive:
            return .low // Full content preserved
        }
    }
    
    func verifyAgainstRetrievedEvidence(
        answer: String,
        evidence: [MemoryPacket]
    ) -> EvidenceVerification {
        var supportedClaims: [String] = []
        var unsupportedClaims: [String] = []
        var contradictions: [String] = []
        
        // Extract claims from answer
        let answerClaims = extractClaims(from: answer)
        
        // Check each claim against evidence
        for claim in answerClaims {
            var found = false
            for packet in evidence {
                if packet.claimLedger.verified.contains(where: { $0.statement == claim }) {
                    supportedClaims.append(claim)
                    found = true
                    break
                }
            }
            
            if !found {
                unsupportedClaims.append(claim)
            }
        }
        
        // Check for contradictions
        for packet in evidence {
            for verifiedClaim in packet.claimLedger.verified {
                if answerClaims.contains(where: { isContradiction($0, verifiedClaim.statement) }) {
                    contradictions.append(verifiedClaim.statement)
                }
            }
        }
        
        return EvidenceVerification(
            timestamp: Date(),
            supportedClaims: supportedClaims,
            unsupportedClaims: unsupportedClaims,
            contradictions: contradictions,
            verificationScore: calculateVerificationScore(
                supported: supportedClaims.count,
                unsupported: unsupportedClaims.count,
                contradictions: contradictions.count
            )
        )
    }
    
    private func extractClaims(from text: String) -> [String] {
        // Simple claim extraction
        let sentences = text.components(separatedBy: ". ")
        return sentences.filter { $0.count > 10 }
    }
    
    private func isContradiction(_ claim1: String, _ claim2: String) -> Bool {
        // Simple contradiction detection
        let negationWords = ["not", "never", "no", "none", "false"]
        
        for word in negationWords {
            if claim1.lowercased().contains(word) && claim2.lowercased().contains(word) {
                return false
            }
            if claim1.lowercased().contains(word) && !claim2.lowercased().contains(word) {
                return true
            }
        }
        
        return false
    }
    
    private func calculateVerificationScore(
        supported: Int,
        unsupported: Int,
        contradictions: Int
    ) -> Double {
        let total = supported + unsupported + contradictions
        guard total > 0 else { return 1.0 }
        
        let supportedWeight = 1.0
        let unsupportedWeight = -0.5
        let contradictionWeight = -1.0
        
        let score = (Double(supported) * supportedWeight +
                    Double(unsupported) * unsupportedWeight +
                    Double(contradictions) * contradictionWeight) / Double(total)
        
        return max(0.0, min(1.0, score))
    }
}

struct VerificationResult {
    let timestamp: Date
    let qualityScore: Double
    let preservedElements: [String]
    let lostElements: [String]
    let warnings: [String]
    let evidenceLoss: Bool
    let claimLabelingPresent: Bool
    let hallucinationRisk: HallucinationRisk
}

struct PreservationCheck {
    let preserved: Bool
    let originalCount: Int
    let compressedCount: Int
}

enum HallucinationRisk {
    case low
    case medium
    case high
}

struct EvidenceVerification {
    let timestamp: Date
    let supportedClaims: [String]
    let unsupportedClaims: [String]
    let contradictions: [String]
    let verificationScore: Double
}
