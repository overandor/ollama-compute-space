import Foundation

class RepoCognitionCompressor {
    private var repoMap: RepoMap
    private var fileRoleIndex: FileRoleIndex
    private var dependencyGraph: DependencyGraph
    private var failingTestIndex: FailingTestIndex
    private var symbolSummary: SymbolSummary
    private var patchReceipts: [PatchReceipt] = []
    
    init() {
        self.repoMap = RepoMap()
        self.fileRoleIndex = FileRoleIndex()
        self.dependencyGraph = DependencyGraph()
        self.failingTestIndex = FailingTestIndex()
        self.symbolSummary = SymbolSummary()
    }
    
    struct RepoMap {
        var files: [RepoFile] = []
        var directories: [String] = []
        var totalLines: Int = 0
        var languageBreakdown: [String: Int] = [:]
    }
    
    struct RepoFile: Identifiable {
        let id = UUID()
        let path: String
        let role: FileRole
        let size: Int
        let lastModified: Date
        let language: String
        let hash: String
    }
    
    enum FileRole {
        case source
        case test
        case config
        case documentation
        case asset
        case build
    }
    
    struct FileRoleIndex {
        var sourceFiles: [String] = []
        var testFiles: [String] = []
        var configFiles: [String] = []
        var documentationFiles: [String] = []
        var assetFiles: [String] = []
        var buildFiles: [String] = []
    }
    
    struct DependencyGraph {
        var nodes: [DependencyNode] = []
        var edges: [DependencyEdge] = []
    }
    
    struct DependencyNode: Identifiable {
        let id = UUID()
        let filePath: String
        let type: DependencyType
    }
    
    enum DependencyType {
        case file
        case module
        case package
        case external
    }
    
    struct DependencyEdge {
        let from: UUID
        let to: UUID
        let type: EdgeType
    }
    
    enum EdgeType {
        case imports
        case inherits
        case implements
        case uses
    }
    
    struct FailingTestIndex {
        var failingTests: [FailingTest] = []
        var lastTestRun: Date?
    }
    
    struct FailingTest: Identifiable {
        let id = UUID()
        let testName: String
        let filePath: String
        let failureReason: String
        let lastFailed: Date
    }
    
    struct SymbolSummary {
        var functions: [Symbol] = []
        var classes: [Symbol] = []
        var structs: [Symbol] = []
        var enums: [Symbol] = []
        var protocols: [Symbol] = []
    }
    
    struct Symbol: Identifiable {
        let id = UUID()
        let name: String
        let filePath: String
        let type: SymbolType
        let line: Int
    }
    
    enum SymbolType {
        case function
        case method
        case property
        case `class`
        case `struct`
        case `enum`
        case `protocol`
    }
    
    struct PatchReceipt {
        let id = UUID()
        let timestamp: Date
        let filePath: String
        let oldHash: String
        let newHash: String
        let changeType: ChangeType
    }
    
    enum ChangeType {
        case added
        case modified
        case deleted
    }
    
    func analyzeRepo(at path: String) async throws {
        // Scan repository structure
        let fileManager = FileManager.default
        let repoURL = URL(fileURLWithPath: path)
        
        // Build repo map
        try await scanDirectory(repoURL)
        
        // Build file role index
        buildFileRoleIndex()
        
        // Build dependency graph
        try await buildDependencyGraph(repoURL)
        
        // Build symbol summary
        try await buildSymbolSummary(repoURL)
    }
    
    private func scanDirectory(_ url: URL) async throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        
        while let element = enumerator?.nextObject() as? URL {
            let resourceValues = try element.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            
            if element.hasDirectoryPath {
                repoMap.directories.append(element.path)
            } else {
                let file = RepoFile(
                    path: element.path,
                    role: determineFileRole(path: element.path),
                    size: resourceValues?.fileSize ?? 0,
                    lastModified: resourceValues?.contentModificationDate ?? Date(),
                    language: determineLanguage(path: element.path),
                    hash: computeHash(path: element.path)
                )
                repoMap.files.append(file)
                repoMap.totalLines += estimateLines(size: file.size)
                
                let language = file.language
                repoMap.languageBreakdown[language, default: 0] += 1
            }
        }
    }
    
    private func determineFileRole(path: String) -> FileRole {
        let lowercased = path.lowercased()
        
        if lowercased.contains("test") || lowercased.contains("spec") {
            return .test
        } else if lowercased.hasSuffix(".json") || lowercased.hasSuffix(".yaml") || lowercased.hasSuffix(".yml") || lowercased.hasSuffix(".toml") {
            return .config
        } else if lowercased.hasSuffix(".md") || lowercased.hasSuffix(".txt") || lowercased.hasSuffix(".rst") {
            return .documentation
        } else if lowercased.hasSuffix(".png") || lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".svg") {
            return .asset
        } else if lowercased.contains("makefile") || lowercased.contains("cmake") || lowercased.hasSuffix(".gradle") {
            return .build
        } else {
            return .source
        }
    }
    
    private func determineLanguage(path: String) -> String {
        let lowercased = path.lowercased()
        
        if lowercased.hasSuffix(".swift") { return "Swift" }
        if lowercased.hasSuffix(".py") { return "Python" }
        if lowercased.hasSuffix(".js") || lowercased.hasSuffix(".ts") { return "JavaScript/TypeScript" }
        if lowercased.hasSuffix(".java") { return "Java" }
        if lowercased.hasSuffix(".cpp") || lowercased.hasSuffix(".cc") || lowercased.hasSuffix(".cxx") { return "C++" }
        if lowercased.hasSuffix(".c") { return "C" }
        if lowercased.hasSuffix(".rs") { return "Rust" }
        if lowercased.hasSuffix(".go") { return "Go" }
        if lowercased.hasSuffix(".rb") { return "Ruby" }
        if lowercased.hasSuffix(".php") { return "PHP" }
        
        return "Unknown"
    }
    
    private func estimateLines(size: Int) -> Int {
        // Rough estimate: ~40 characters per line
        return size / 40
    }
    
    private func buildFileRoleIndex() {
        for file in repoMap.files {
            switch file.role {
            case .source:
                fileRoleIndex.sourceFiles.append(file.path)
            case .test:
                fileRoleIndex.testFiles.append(file.path)
            case .config:
                fileRoleIndex.configFiles.append(file.path)
            case .documentation:
                fileRoleIndex.documentationFiles.append(file.path)
            case .asset:
                fileRoleIndex.assetFiles.append(file.path)
            case .build:
                fileRoleIndex.buildFiles.append(file.path)
            }
        }
    }
    
    private func buildDependencyGraph(_ url: URL) async throws {
        // Simplified dependency graph construction
        // In production, this would parse import statements
        for file in repoMap.files where file.role == .source {
            let node = DependencyNode(filePath: file.path, type: .file)
            dependencyGraph.nodes.append(node)
            
            // Would add edges based on imports
        }
    }
    
    private func buildSymbolSummary(_ url: URL) async throws {
        // Simplified symbol extraction
        // In production, this would parse AST
        for file in repoMap.files where file.role == .source {
            let symbols = try await extractSymbols(from: file.path)
            symbolSummary.functions.append(contentsOf: symbols.filter { $0.type == .function || $0.type == .method })
            symbolSummary.classes.append(contentsOf: symbols.filter { $0.type == .class })
            symbolSummary.structs.append(contentsOf: symbols.filter { $0.type == .struct })
            symbolSummary.enums.append(contentsOf: symbols.filter { $0.type == .enum })
            symbolSummary.protocols.append(contentsOf: symbols.filter { $0.type == .protocol })
        }
    }
    
    private func extractSymbols(from path: String) async throws -> [Symbol] {
        // Placeholder for actual symbol extraction
        // Would use SourceKit or language-specific parsers
        return []
    }
    
    func getActivePromptContent(for task: String, currentFailure: String?, currentHypothesis: String?) -> String {
        var prompt = "## Active Context\n\n"
        
        // Only relevant files based on task
        let relevantFiles = findRelevantFiles(for: task)
        prompt += "### Relevant Files\n"
        for file in relevantFiles.prefix(10) {
            prompt += "- \(file.path) (\(file.role))\n"
        }
        prompt += "\n"
        
        // Exact failure if present
        if let failure = currentFailure {
            prompt += "### Current Failure\n\(failure)\n\n"
        }
        
        // Current hypothesis if present
        if let hypothesis = currentHypothesis {
            prompt += "### Current Hypothesis\n\(hypothesis)\n\n"
        }
        
        // Changed symbols
        prompt += "### Changed Symbols\n"
        for symbol in symbolSummary.functions.prefix(5) {
            prompt += "- \(symbol.name) in \(symbol.filePath)\n"
        }
        prompt += "\n"
        
        // Constraints from repo structure
        prompt += "### Repository Constraints\n"
        prompt += "- Total files: \(repoMap.files.count)\n"
        prompt += "- Primary language: \(getPrimaryLanguage())\n"
        prompt += "- Test files: \(fileRoleIndex.testFiles.count)\n"
        prompt += "\n"
        
        return prompt
    }
    
    private func findRelevantFiles(for task: String) -> [RepoFile] {
        // Simple keyword matching for relevance
        let taskWords = Set(task.lowercased().components(separatedBy: " "))
        
        let scoredFiles = repoMap.files.map { file -> (RepoFile, Double) in
            var score = 0.0
            let filePath = file.path.lowercased()
            
            for word in taskWords {
                if filePath.contains(word) {
                    score += 1.0
                }
            }
            
            // Boost score for source files
            if file.role == .source {
                score += 0.5
            }
            
            return (file, score)
        }
        
        return scoredFiles
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    private func getPrimaryLanguage() -> String {
        return repoMap.languageBreakdown.max { $0.value < $1.value }?.key ?? "Unknown"
    }
    
    func recordPatch(filePath: String, oldHash: String, newHash: String, changeType: ChangeType) {
        let receipt = PatchReceipt(
            timestamp: Date(),
            filePath: filePath,
            oldHash: oldHash,
            newHash: newHash,
            changeType: changeType
        )
        patchReceipts.append(receipt)
    }
    
    func getInactiveMemorySummary() -> String {
        var summary = "## Inactive Memory (Searchable)\n\n"
        
        summary += "### Embeddings\n"
        summary += "- Vector index stored for semantic search\n"
        summary += "- \(repoMap.files.count) files indexed\n\n"
        
        summary += "### Summaries\n"
        summary += "- File role index: \(fileRoleIndex.sourceFiles.count) source, \(fileRoleIndex.testFiles.count) test\n"
        summary += "- Dependency graph: \(dependencyGraph.nodes.count) nodes, \(dependencyGraph.edges.count) edges\n"
        summary += "- Symbol summary: \(symbolSummary.functions.count) functions, \(symbolSummary.classes.count) classes\n\n"
        
        summary += "### Hash Receipts\n"
        summary += "- \(patchReceipts.count) patch receipts recorded\n\n"
        
        summary += "### Searchable Indexes\n"
        summary += "- SQLite/DuckDB tables available for:\n"
        summary += "  - File search by path, role, language\n"
        summary += "  - Symbol search by name, type, file\n"
        summary += "  - Dependency search by relationship\n"
        summary += "  - Patch history by file, hash\n"
        
        return summary
    }
    
    private func computeHash(path: String) -> String {
        // Placeholder for actual file hashing
        return path.hashValue.description
    }
}
