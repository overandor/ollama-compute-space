import Foundation
import SwiftUI

class MemoryManager: ObservableObject {
    @Published var totalMemoryGB: Double = 0
    @Published var usedMemoryGB: Double = 0
    @Published var availableMemoryGB: Double = 0
    @Published var appMemoryGB: Double = 0
    @Published var agents: [AgentMemory] = []
    @Published var chats: [ChatMemory] = []
    
    private var memoryUpdateTimer: Timer?
    
    init() {
        updateMemoryInfo()
        startMemoryMonitoring()
    }
    
    private func startMemoryMonitoring() {
        memoryUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMemoryInfo()
        }
    }
    
    private func updateMemoryInfo() {
        var size = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &size) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            appMemoryGB = Double(size.resident_size) / 1024.0 / 1024.0 / 1024.0
        }
        
        // Get system memory info
        var stats = vm_statistics64()
        var count2 = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let hostResult: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count2)
            }
        }
        
        if hostResult == KERN_SUCCESS {
            let pageSize = vm_page_size
            let freeMemory = Double(stats.free_count) * Double(pageSize)
            let activeMemory = Double(stats.active_count) * Double(pageSize)
            let inactiveMemory = Double(stats.inactive_count) * Double(pageSize)
            let wiredMemory = Double(stats.wire_count) * Double(pageSize)
            
            totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0
            usedMemoryGB = (activeMemory + inactiveMemory + wiredMemory) / 1024.0 / 1024.0 / 1024.0
            availableMemoryGB = freeMemory / 1024.0 / 1024.0 / 1024.0
        }
    }
    
    func createAgent(name: String, allocatedMemoryGB: Double) -> AgentMemory {
        let agent = AgentMemory(id: UUID(), name: name, allocatedMemoryGB: allocatedMemoryGB)
        agents.append(agent)
        return agent
    }
    
    func createChat(agentId: UUID, name: String, allocatedMemoryGB: Double) -> ChatMemory {
        let chat = ChatMemory(id: UUID(), agentId: agentId, name: name, allocatedMemoryGB: allocatedMemoryGB)
        chats.append(chat)
        return chat
    }
    
    func getAgentMemoryUsage(agentId: UUID) -> Double {
        // Simulated memory usage tracking
        return agents.first { $0.id == agentId }?.currentMemoryGB ?? 0
    }
    
    func getChatMemoryUsage(chatId: UUID) -> Double {
        return chats.first { $0.id == chatId }?.currentMemoryGB ?? 0
    }
    
    func getAvailableMemoryForAllocation() -> Double {
        return max(0, availableMemoryGB - appMemoryGB - agents.reduce(0) { $0 + $1.allocatedMemoryGB })
    }
    
    deinit {
        memoryUpdateTimer?.invalidate()
    }
}

struct AgentMemory: Identifiable, Hashable {
    let id: UUID
    let name: String
    let allocatedMemoryGB: Double
    var currentMemoryGB: Double = 0
    var createdAt: Date = Date()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: AgentMemory, rhs: AgentMemory) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatMemory: Identifiable {
    let id: UUID
    let agentId: UUID
    let name: String
    let allocatedMemoryGB: Double
    var currentMemoryGB: Double = 0
    var createdAt: Date = Date()
}
