import Foundation
import SwiftUI

class RAMObserver: ObservableObject {
    @Published var ollamaRSSGB: Double = 0
    @Published var systemSwapUsedGB: Double = 0
    @Published var compressedMemoryGB: Double = 0
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var pageoutsPerSec: Double = 0
    @Published var pageinsPerSec: Double = 0
    @Published var compressionRatio: Double = 0
    @Published var topProcesses: [ProcessInfo] = []
    @Published var promptTokens: Int = 0
    @Published var contextTokens: Int = 0
    @Published var responseLatencyMs: Double = 0
    
    private var updateTimer: Timer?
    private var previousPageouts: UInt64 = 0
    private var previousPageins: UInt64 = 0
    private var lastUpdateTime: Date = Date()
    
    enum MemoryPressure {
        case normal
        case yellow
        case red
    }
    
    struct ProcessInfo: Identifiable {
        let id = UUID()
        let pid: Int
        let name: String
        let rssGB: Double
        let cpuPercent: Double
    }
    
    init() {
        startObserving()
    }
    
    private func startObserving() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func updateMetrics() {
        updateOllamaRSS()
        updateSystemMemory()
        updateMemoryPressure()
        updatePageRates()
        updateTopProcesses()
    }
    
    private func updateOllamaRSS() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "ollama"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let pidString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = Int(pidString) {
                ollamaRSSGB = getProcessRSS(pid: pid)
            } else {
                ollamaRSSGB = 0
            }
        } catch {
            ollamaRSSGB = 0
        }
    }
    
    private func getProcessRSS(pid: Int) -> Double {
        var size = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &size) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(size.resident_size) / 1024.0 / 1024.0 / 1024.0
        }
        return 0
    }
    
    private func updateSystemMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let hostResult: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if hostResult == KERN_SUCCESS {
            let pageSize = vm_page_size
            let compressCount = Double(stats.compressor_page_count)
            compressedMemoryGB = compressCount * Double(pageSize) / 1024.0 / 1024.0 / 1024.0
            
            let swapins = Double(stats.swapins)
            let swapouts = Double(stats.swapouts)
            systemSwapUsedGB = (swapins - swapouts) * Double(pageSize) / 1024.0 / 1024.0 / 1024.0
        }
    }
    
    private func updateMemoryPressure() {
        // Use memory pressure notifications
        // memorystatus_get_level is not available in public SDK, use alternative approach
        var status: UInt32 = 0
        // let result = memorystatus_get_level(&status)
        
        // Alternative: use swap usage as proxy for memory pressure
        if systemSwapUsedGB > 1.0 {
            memoryPressure = .red
        } else if systemSwapUsedGB > 0.1 {
            memoryPressure = .yellow
        } else {
            memoryPressure = .normal
        }
    }
    
    private func updatePageRates() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let hostResult: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if hostResult == KERN_SUCCESS {
            let currentPageouts = stats.pageouts
            let currentPageins = stats.pageins
            
            let now = Date()
            let timeInterval = now.timeIntervalSince(lastUpdateTime)
            
            if timeInterval > 0 {
                pageoutsPerSec = Double(currentPageouts - previousPageouts) / timeInterval
                pageinsPerSec = Double(currentPageins - previousPageins) / timeInterval
            }
            
            previousPageouts = currentPageouts
            previousPageins = currentPageins
            lastUpdateTime = now
        }
    }
    
    private func updateTopProcesses() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid,comm,rss,%cpu", "-r"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let lines = output.components(separatedBy: "\n").dropFirst()
            var processes: [ProcessInfo] = []
            
            for line in lines.prefix(10) {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 4 {
                    if let pid = Int(parts[0]) {
                        let rssKB = Double(parts[2]) ?? 0
                        let cpu = Double(parts[3]) ?? 0
                        processes.append(ProcessInfo(
                            pid: pid,
                            name: parts[1],
                            rssGB: rssKB / 1024.0 / 1024.0,
                            cpuPercent: cpu
                        ))
                    }
                }
            }
            
            topProcesses = processes
        } catch {
            topProcesses = []
        }
    }
    
    func recordTokenCount(promptTokens: Int, contextTokens: Int) {
        self.promptTokens = promptTokens
        self.contextTokens = contextTokens
    }
    
    func recordResponseLatency(latencyMs: Double) {
        self.responseLatencyMs = latencyMs
    }
    
    func getCompressionReceipt() -> CompressionReceipt {
        return CompressionReceipt(
            timestamp: Date(),
            ollamaRSSGB: ollamaRSSGB,
            swapUsedGB: systemSwapUsedGB,
            compressedMemoryGB: compressedMemoryGB,
            memoryPressure: memoryPressure,
            pageoutsPerSec: pageoutsPerSec,
            promptTokens: promptTokens,
            contextTokens: contextTokens,
            responseLatencyMs: responseLatencyMs
        )
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}

struct CompressionReceipt {
    let timestamp: Date
    let ollamaRSSGB: Double
    let swapUsedGB: Double
    let compressedMemoryGB: Double
    let memoryPressure: RAMObserver.MemoryPressure
    let pageoutsPerSec: Double
    let promptTokens: Int
    let contextTokens: Int
    let responseLatencyMs: Double
}
