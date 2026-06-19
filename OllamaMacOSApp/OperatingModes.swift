import Foundation
import SwiftUI

class OperatingModeManager: ObservableObject {
    @Published var currentMode: OperatingMode = .balanced
    @Published var autoSwitchEnabled = true
    
    enum OperatingMode: String, CaseIterable {
        case fast_low_ram = "Fast Low RAM"
        case balanced = "Balanced"
        case deep_research_local = "Deep Research"
        case emergency_swap_control = "Emergency"
        
        var contextRange: ClosedRange<Int> {
            switch self {
            case .fast_low_ram:
                return 4096...8192
            case .balanced:
                return 8192...32768
            case .deep_research_local:
                return 32768...262144
            case .emergency_swap_control:
                return 2048...4096
            }
        }
        
        var kvCacheType: KVContextGovernor.KVCacheType {
            switch self {
            case .fast_low_ram:
                return .q4_0
            case .balanced:
                return .q8_0
            case .deep_research_local:
                return .f16
            case .emergency_swap_control:
                return .q4_0
            }
        }
        
        var memoryRetrievalCount: Int {
            switch self {
            case .fast_low_ram:
                return 3
            case .balanced:
                return 8
            case .deep_research_local:
                return 16
            case .emergency_swap_control:
                return 2
            }
        }
        
        var useCase: String {
            switch self {
            case .fast_low_ram:
                return "Quick command, code edit, small question"
            case .balanced:
                return "Normal artifact work"
            case .deep_research_local:
                return "Large repo/chat synthesis"
            case .emergency_swap_control:
                return "Memory pressure emergency"
            }
        }
    }
    
    func evaluateModeSwitch(
        memoryPressure: RAMObserver.MemoryPressure,
        swapUsedGB: Double,
        ollamaRSSGrowthSlope: Double
    ) -> OperatingMode? {
        guard autoSwitchEnabled else { return nil }
        
        // Emergency mode triggers
        if memoryPressure == .red ||
           swapUsedGB > 8.0 ||
           ollamaRSSGrowthSlope > 0.5 {
            return .emergency_swap_control
        }
        
        // Return to balanced when pressure normalizes
        if memoryPressure == .normal && swapUsedGB < 2.0 {
            return .balanced
        }
        
        // Yellow pressure -> fast low ram
        if memoryPressure == .yellow {
            return .fast_low_ram
        }
        
        return nil
    }
    
    func applyMode(_ mode: OperatingMode, to governor: KVContextGovernor) {
        governor.currentContextLength = mode.contextRange.upperBound
        governor.kvCacheType = mode.kvCacheType
        governor.contextPolicy = mode == .emergency_swap_control ? .emergencyShrink : .smallestContextThatPassesTask
    }
    
    func getModeConfiguration(_ mode: OperatingMode) -> ModeConfiguration {
        return ModeConfiguration(
            mode: mode,
            contextLength: mode.contextRange.upperBound,
            kvCacheType: mode.kvCacheType,
            memoryRetrievalCount: mode.memoryRetrievalCount,
            useCase: mode.useCase
        )
    }
}

struct ModeConfiguration {
    let mode: OperatingModeManager.OperatingMode
    let contextLength: Int
    let kvCacheType: KVContextGovernor.KVCacheType
    let memoryRetrievalCount: Int
    let useCase: String
}
