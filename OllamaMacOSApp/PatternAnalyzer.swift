import Foundation

class PatternAnalyzer {
    private var metricsHistory: [SystemMetrics] = []
    private let maxHistorySize = 100
    
    func analyze(metrics: SystemMetrics) -> [Pattern] {
        metricsHistory.append(metrics)
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
        
        var patterns: [Pattern] = []
        
        // Detect CPU patterns
        if metricsHistory.count >= 10 {
            let recentCPU = metricsHistory.suffix(10).map { $0.cpuUsage }
            let avgCPU = recentCPU.reduce(0, +) / Double(recentCPU.count)
            
            if avgCPU > 70 {
                patterns.append(Pattern(
                    type: "CPU Intensive",
                    description: "Consistently high CPU usage detected",
                    confidence: 0.85
                ))
            }
        }
        
        // Detect memory patterns
        if metricsHistory.count >= 10 {
            let recentMemory = metricsHistory.suffix(10).map { $0.memoryUsage }
            let avgMemory = recentMemory.reduce(0, +) / Double(recentMemory.count)
            
            if avgMemory > 70 {
                patterns.append(Pattern(
                    type: "Memory Intensive",
                    description: "Consistently high memory usage detected",
                    confidence: 0.85
                ))
            }
        }
        
        // Detect patterns in network activity
        if metricsHistory.count >= 5 {
            let recentNetwork = metricsHistory.suffix(5).map { $0.networkActivity }
            let avgNetwork = recentNetwork.reduce(0, +) / Double(recentNetwork.count)
            
            if avgNetwork > 50 {
                patterns.append(Pattern(
                    type: "Network Intensive",
                    description: "High network activity detected",
                    confidence: 0.75
                ))
            }
        }
        
        return patterns
    }
    
    func analyzePatterns(_ patterns: [DailyPattern]) -> WeeklyPattern {
        let calendar = Calendar.current
        var dayOfWeekPatterns: [Int: [DailyPattern]] = [:]
        
        for pattern in patterns {
            let dayOfWeek = calendar.component(.weekday, from: pattern.date)
            dayOfWeekPatterns[dayOfWeek, default: []].append(pattern)
        }
        
        var weeklyPattern = WeeklyPattern()
        
        for (dayOfWeek, dayPatterns) in dayOfWeekPatterns {
            let avgProductivity = dayPatterns.map { $0.productivity }.reduce(0, +) / Double(dayPatterns.count)
            let avgDecisions = Double(dayPatterns.map { $0.decisions }.reduce(0, +)) / Double(dayPatterns.count)
            
            weeklyPattern.dayProductivity[dayOfWeek] = avgProductivity
            weeklyPattern.dayDecisionCount[dayOfWeek] = Int(avgDecisions)
        }
        
        return weeklyPattern
    }
}

struct WeeklyPattern {
    var dayProductivity: [Int: Double] = [:]
    var dayDecisionCount: [Int: Int] = [:]
}

struct DailyPattern {
    var date: Date
    var productivity: Double
    var decisions: Int
}
