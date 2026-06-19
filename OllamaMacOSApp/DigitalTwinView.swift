import SwiftUI

struct DigitalTwinView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @StateObject private var digitalTwin = DigitalTwin()
    @State private var selectedTab: TwinTab = .overview
    
    enum TwinTab: String, CaseIterable {
        case overview = "Overview"
        case profile = "Profile"
        case skills = "Skills"
        case patterns = "Patterns"
        case decisions = "Decisions"
        case privacy = "Privacy"
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Twin Avatar
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(digitalTwin.isActive ? Color.blue : Color.gray)
                            .frame(width: 80, height: 80)
                            .shadow(radius: 5)
                        
                        Text("🤖")
                            .font(.system(size: 40))
                    }
                    
                    Text(digitalTwin.twinAvatar.name)
                        .font(.headline)
                    
                    Text(digitalTwin.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Control Buttons
                VStack(spacing: 8) {
                    if !digitalTwin.isActive {
                        Button("Activate Twin") {
                            digitalTwin.isActive = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Deactivate Twin") {
                            digitalTwin.isActive = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 250)
            
            // Main Content
            VStack(spacing: 0) {
                // Tab Bar
                Picker("Tab", selection: $selectedTab) {
                    ForEach(TwinTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Tab Content
                ScrollView {
                    switch selectedTab {
                    case .overview:
                        overviewView
                    case .profile:
                        profileView
                    case .skills:
                        skillsView
                    case .patterns:
                        patternsView
                    case .decisions:
                        decisionsView
                    case .privacy:
                        privacyView
                    }
                }
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    var overviewView: some View {
        VStack(spacing: 20) {
            // Stats Cards
            HStack(spacing: 20) {
                StatCard(title: "Skills", value: "\(digitalTwin.skillSet.count)", color: .blue)
                StatCard(title: "Decisions", value: "\(digitalTwin.decisionHistory.count)", color: .green)
                StatCard(title: "Patterns", value: "\(digitalTwin.dailyPatterns.count)", color: .orange)
                StatCard(title: "Learning", value: "\(Int(digitalTwin.learningProgress * 100))%", color: .purple)
            }
            
            // Learning Progress
            VStack(alignment: .leading, spacing: 12) {
                Text("Learning Progress")
                    .font(.headline)
                
                ProgressView(value: digitalTwin.learningProgress)
                    .progressViewStyle(.linear)
                
                Text("Digital twin is learning from your behavior patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Personality Traits
            VStack(alignment: .leading, spacing: 12) {
                Text("Personality Traits")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    TraitBar(name: "Openness", value: digitalTwin.personalityTraits.openness)
                    TraitBar(name: "Conscientiousness", value: digitalTwin.personalityTraits.conscientiousness)
                    TraitBar(name: "Extraversion", value: digitalTwin.personalityTraits.extraversion)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding()
    }
    
    var profileView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Behavioral Profile")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Communication Style: \(digitalTwin.behavioralProfile.communicationStyle.rawValue)")
                Text("Decision Making: \(digitalTwin.behavioralProfile.decisionStyle.rawValue)")
                Text("Work Preferences: \(digitalTwin.behavioralProfile.workStyle.rawValue)")
                Text("Social Patterns: \(digitalTwin.behavioralProfile.socialPatterns.collaborationStyle.rawValue)")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding()
    }
    
    var skillsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skill Set")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(digitalTwin.skillSet) { skill in
                    SkillRow(skill: skill)
                }
            }
        }
        .padding()
    }
    
    var patternsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Patterns")
                .font(.headline)
            
            if digitalTwin.dailyPatterns.isEmpty {
                Text("No patterns detected yet")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(digitalTwin.dailyPatterns) { pattern in
                        PatternRow(pattern: pattern)
                    }
                }
            }
        }
        .padding()
    }
    
    var decisionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Decision History")
                .font(.headline)
            
            if digitalTwin.decisionHistory.isEmpty {
                Text("No decisions recorded yet")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(digitalTwin.decisionHistory) { decision in
                        DecisionRow(decision: decision)
                    }
                }
            }
        }
        .padding()
    }
    
    var privacyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Share anonymized data", isOn: .constant(digitalTwin.privacySettings.shareAnonymizedData))
                Toggle("Local storage only", isOn: .constant(digitalTwin.privacySettings.localOnly))
                Toggle("Encryption enabled", isOn: .constant(digitalTwin.privacySettings.encryptionEnabled))
                Toggle("Allow proxy decisions", isOn: .constant(digitalTwin.privacySettings.allowProxyDecisions))
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding()
    }
}

struct TraitBar: View {
    let name: String
    let value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
            
            ProgressView(value: value)
                .progressViewStyle(.linear)
                .frame(width: 100)
        }
    }
}

struct SkillRow: View {
    let skill: Skill
    
    var body: some View {
        HStack {
            Text(skill.name)
                .font(.subheadline)
            
            Spacer()
            
            Text(String(format: "%.0f%%", skill.proficiency * 100))
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: skill.proficiency)
                .progressViewStyle(.linear)
                .frame(width: 80)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct PatternRow: View {
    let pattern: DailyPattern
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.type)
                    .font(.subheadline)
                Text(pattern.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.0f%%", pattern.confidence * 100))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DecisionRow: View {
    let decision: DecisionRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(decision.context)
                    .font(.subheadline)
                Text(decision.choice)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(decision.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
