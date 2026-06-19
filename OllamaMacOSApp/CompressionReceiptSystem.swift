import Foundation

class CompressionReceiptSystem {
    private var receipts: [CognitionCompressionReceipt] = []
    private let receiptStoreURL: URL
    
    init() {
        let documentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ollamacomputespace")
            .appendingPathComponent("receipts")
        
        try? FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
        
        receiptStoreURL = documentsDir.appendingPathComponent("compression_receipts.json")
        loadReceipts()
    }
    
    func generateReceipt(
        model: String,
        task: String,
        rawContextTokens: Int,
        hydratedContextTokens: Int,
        ramBefore: CompressionReceipt,
        ramAfter: CompressionReceipt,
        verification: VerificationResult,
        preserved: [String],
        dropped: [String]
    ) -> CognitionCompressionReceipt {
        let receipt = CognitionCompressionReceipt(
            timestamp: Date(),
            model: model,
            task: task,
            rawContextTokens: rawContextTokens,
            hydratedContextTokens: hydratedContextTokens,
            compressionRatio: Double(rawContextTokens) / Double(hydratedContextTokens),
            preserved: preserved,
            dropped: dropped,
            ramBefore: ReceiptRAMMetrics(
                ollamaRSSGB: ramBefore.ollamaRSSGB,
                swapUsedGB: ramBefore.swapUsedGB
            ),
            ramAfter: ReceiptRAMMetrics(
                ollamaRSSGB: ramAfter.ollamaRSSGB,
                swapUsedGB: ramAfter.swapUsedGB
            ),
            qualityGate: QualityGate(
                evidenceLoss: verification.evidenceLoss,
                claimLabelingPresent: verification.claimLabelingPresent,
                hallucinationRisk: verification.hallucinationRisk
            )
        )
        
        receipts.append(receipt)
        saveReceipts()
        
        return receipt
    }
    
    func getReceipt(id: UUID) -> CognitionCompressionReceipt? {
        return receipts.first { $0.id == id }
    }
    
    func getRecentReceipts(limit: Int = 10) -> [CognitionCompressionReceipt] {
        return Array(receipts.suffix(limit).reversed())
    }
    
    func getReceiptsByTask(task: String) -> [CognitionCompressionReceipt] {
        return receipts.filter { $0.task == task }
    }
    
    func getCompressionStatistics() -> CompressionStatistics {
        guard !receipts.isEmpty else {
            return CompressionStatistics(
                totalReceipts: 0,
                averageCompressionRatio: 0,
                averageRAMReductionGB: 0,
                averageQualityScore: 0,
                evidenceLossCount: 0
            )
        }
        
        let avgRatio = receipts.reduce(0.0) { $0 + $1.compressionRatio } / Double(receipts.count)
        
        let avgRAMReduction = receipts.reduce(0.0) { result, receipt in
            result + (receipt.ramBefore.swapUsedGB - receipt.ramAfter.swapUsedGB)
        } / Double(receipts.count)
        
        let avgQuality = receipts.reduce(0.0) { result, receipt in
            let quality = receipt.qualityGate.evidenceLoss ? 0.0 : 1.0
            return result + quality
        } / Double(receipts.count)
        
        let evidenceLossCount = receipts.filter { $0.qualityGate.evidenceLoss }.count
        
        return CompressionStatistics(
            totalReceipts: receipts.count,
            averageCompressionRatio: avgRatio,
            averageRAMReductionGB: avgRAMReduction,
            averageQualityScore: avgQuality,
            evidenceLossCount: evidenceLossCount
        )
    }
    
    func exportReceiptAsYAML(_ receipt: CognitionCompressionReceipt) -> String {
        let formatter = ISO8601DateFormatter()
        
        var yaml = """
        COGNITION_COMPRESSION_RECEIPT_V1:
          ts: \(formatter.string(from: receipt.timestamp))
          model: \(receipt.model)
          task: \(receipt.task)
          raw_context_tokens: \(receipt.rawContextTokens)
          hydrated_context_tokens: \(receipt.hydratedContextTokens)
          compression_ratio: \(String(format: "%.2f", receipt.compressionRatio))
          preserved:
        """
        
        for item in receipt.preserved {
            yaml += "  - \(item)\n"
        }
        
        yaml += "  dropped:\n"
        for item in receipt.dropped {
            yaml += "  - \(item)\n"
        }
        
        yaml += """
          ram_before:
            ollama_rss_gb: \(String(format: "%.2f", receipt.ramBefore.ollamaRSSGB))
            swap_used_gb: \(String(format: "%.2f", receipt.ramBefore.swapUsedGB))
          ram_after:
            ollama_rss_gb: \(String(format: "%.2f", receipt.ramAfter.ollamaRSSGB))
            swap_used_gb: \(String(format: "%.2f", receipt.ramAfter.swapUsedGB))
          quality_gate:
            evidence_loss: \(receipt.qualityGate.evidenceLoss)
            claim_labeling_present: \(receipt.qualityGate.claimLabelingPresent)
            hallucination_risk: \(hallucinationRiskToString(receipt.qualityGate.hallucinationRisk))
        """
        
        return yaml
    }
    
    private func hallucinationRiskToString(_ risk: HallucinationRisk) -> String {
        switch risk {
        case .low: return "reduced_by_retrieval"
        case .medium: return "moderate"
        case .high: return "elevated"
        }
    }
    
    private func loadReceipts() {
        guard let data = try? Data(contentsOf: receiptStoreURL) else { return }
        
        do {
            receipts = try JSONDecoder().decode([CognitionCompressionReceipt].self, from: data)
        } catch {
            receipts = []
        }
    }
    
    private func saveReceipts() {
        do {
            let data = try JSONEncoder().encode(receipts)
            try data.write(to: receiptStoreURL)
        } catch {
            print("Failed to save receipts: \(error)")
        }
    }
}

struct CognitionCompressionReceipt: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let model: String
    let task: String
    let rawContextTokens: Int
    let hydratedContextTokens: Int
    let compressionRatio: Double
    let preserved: [String]
    let dropped: [String]
    let ramBefore: ReceiptRAMMetrics
    let ramAfter: ReceiptRAMMetrics
    let qualityGate: QualityGate
}

struct ReceiptRAMMetrics: Codable {
    let ollamaRSSGB: Double
    let swapUsedGB: Double
}

struct QualityGate: Codable {
    let evidenceLoss: Bool
    let claimLabelingPresent: Bool
    let hallucinationRisk: HallucinationRisk
}

struct CompressionStatistics {
    let totalReceipts: Int
    let averageCompressionRatio: Double
    let averageRAMReductionGB: Double
    let averageQualityScore: Double
    let evidenceLossCount: Int
}
