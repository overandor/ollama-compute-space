import Foundation
import CryptoKit

struct MemoryPacket: Identifiable, Codable {
    let id: UUID
    let packetId: String // SHA256 hash
    let source: PacketSource
    var claimLedger: ClaimLedger
    var taskState: TaskState
    var retrievalKeys: RetrievalKeys
    var compression: CompressionMetrics
    
    init(from content: String, sourceType: SourceType, path: String) {
        self.id = UUID()
        self.packetId = Self.computeSHA256(content)
        self.source = PacketSource(
            type: sourceType,
            path: path,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        self.claimLedger = ClaimLedger()
        self.taskState = TaskState()
        self.retrievalKeys = RetrievalKeys()
        self.compression = CompressionMetrics(
            rawTokens: content.estimatedTokenCount(),
            compressedTokens: 0,
            ratio: 1.0,
            lossPolicy: .noEvidenceLoss
        )
    }
    
    private static func computeSHA256(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

struct PacketSource: Codable {
    let type: SourceType
    let path: String
    let timestamp: String
}

enum SourceType: String, Codable {
    case chat
    case file
    case repo
    case run
}

struct ClaimLedger: Codable {
    var verified: [Claim] = []
    var userClaimed: [Claim] = []
    var inferred: [Claim] = []
    var unknown: [Claim] = []
    var blocked: [Claim] = []
    
    mutating func addClaim(_ claim: Claim, category: ClaimCategory) {
        switch category {
        case .verified:
            verified.append(claim)
        case .userClaimed:
            userClaimed.append(claim)
        case .inferred:
            inferred.append(claim)
        case .unknown:
            unknown.append(claim)
        case .blocked:
            blocked.append(claim)
        }
    }
}

struct Claim: Identifiable, Codable {
    let id = UUID()
    let statement: String
    let evidence: [String]
    let confidence: Double
    let timestamp: String
}

enum ClaimCategory: String, Codable {
    case verified
    case userClaimed
    case inferred
    case unknown
    case blocked
}

struct TaskState: Codable {
    var activeGoal: String = ""
    var constraints: [String] = []
    var decisions: [Decision] = []
    var openQuestions: [String] = []
    var artifacts: [Artifact] = []
}

struct Decision: Identifiable, Codable {
    let id = UUID()
    let description: String
    let rationale: String
    let timestamp: String
}

struct Artifact: Identifiable, Codable {
    let id = UUID()
    let type: String
    let path: String
    let hash: String
    let timestamp: String
}

struct RetrievalKeys: Codable {
    var entities: [String] = []
    var codeSymbols: [String] = []
    var filePaths: [String] = []
    var projectNames: [String] = []
    
    mutating func addEntity(_ entity: String) {
        if !entities.contains(entity) {
            entities.append(entity)
        }
    }
    
    mutating func addCodeSymbol(_ symbol: String) {
        if !codeSymbols.contains(symbol) {
            codeSymbols.append(symbol)
        }
    }
    
    mutating func addFilePath(_ path: String) {
        if !filePaths.contains(path) {
            filePaths.append(path)
        }
    }
}

struct CompressionMetrics: Codable {
    var rawTokens: Int
    var compressedTokens: Int
    var ratio: Double
    let lossPolicy: LossPolicy
    
    mutating func updateCompression(compressedTokens: Int) {
        self.compressedTokens = compressedTokens
        self.ratio = rawTokens > 0 ? Double(rawTokens) / Double(compressedTokens) : 1.0
    }
}

enum LossPolicy: String, Codable {
    case noEvidenceLoss
    case allowProseLoss
    case aggressive
}

extension String {
    func estimatedTokenCount() -> Int {
        // Rough estimation: ~4 characters per token
        return self.count / 4
    }
}
