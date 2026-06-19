#!/usr/bin/env swift
import Foundation

class OllamaDaemon {
    private var ollamaProcess: Process?
    private let ollamaPath: String
    private let modelsPath: String
    private let host: String
    
    init() {
        let bundlePath = Bundle.main.bundlePath
        self.ollamaPath = "\(bundlePath)/Contents/Resources/ollama"
        self.modelsPath = "\(bundlePath)/Contents/Resources/models"
        self.host = ProcessInfo.processInfo.environment["OLLAMA_HOST"] ?? "127.0.0.1:11434"
        
        // Create models directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: modelsPath, withIntermediateDirectories: true)
    }
    
    func start() {
        guard ollamaProcess == nil else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ollamaPath)
        process.arguments = ["serve"]
        process.currentDirectoryPath = modelsPath
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set environment variables
        process.environment = [
            "OLLAMA_HOST": host,
            "OLLAMA_MODELS": modelsPath,
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? ""
        ]
        
        process.terminationHandler = { [weak self] _ in
            self?.ollamaProcess = nil
            self?.log("Ollama daemon terminated")
        }
        
        do {
            try process.run()
            ollamaProcess = process
            log("Ollama daemon started on \(host)")
        } catch {
            log("Failed to start Ollama daemon: \(error)")
        }
    }
    
    func stop() {
        ollamaProcess?.terminate()
        ollamaProcess = nil
        log("Ollama daemon stopped")
    }
    
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] \(message)")
    }
}

// Main daemon loop
let daemon = OllamaDaemon()
daemon.start()

// Keep daemon running
RunLoop.main.run()
