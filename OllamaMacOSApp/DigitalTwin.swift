import Foundation
import SwiftUI
import Combine

class DigitalTwin: ObservableObject {
    @Published var isActive = false
    @Published var learningProgress: Double = 0.0
    @Published var behavioralProfile: BehavioralProfile
    @Published var decisionHistory: [DecisionRecord] = []
    @Published var preferences: UserPreferences
    @Published var skillSet: [Skill] = []
    @Published var dailyPatterns: [DailyPattern] = []
    @Published var personalityTraits: PersonalityTraits
    @Published var twinAvatar: TwinAvatar
    @Published var privacySettings: PrivacySettings
    @Published var integrationStatus: IntegrationStatus
    
    private let learningEngine: BehavioralLearningEngine
    private let decisionEngine: DecisionEngine
    private let privacyVault: PrivacyVault
    private let patternAnalyzer: PatternAnalyzer
    
    init() {
        self.behavioralProfile = BehavioralProfile()
        self.preferences = UserPreferences()
        self.personalityTraits = PersonalityTraits()
        self.twinAvatar = TwinAvatar()
        self.privacySettings = PrivacySettings()
        self.integrationStatus = IntegrationStatus()
        
        self.learningEngine = BehavioralLearningEngine()
        self.decisionEngine = DecisionEngine()
        self.privacyVault = PrivacyVault()
        self.patternAnalyzer = PatternAnalyzer()
        
        self.skillSet = Self.defaultSkills()
    }
    
    static func defaultSkills() -> [Skill] {
        return [
            Skill(name: "Communication", proficiency: 0.5, category: .social, lastUsed: Date()),
            Skill(name: "Decision Making", proficiency: 0.5, category: .cognitive, lastUsed: Date()),
            Skill(name: "Problem Solving", proficiency: 0.5, category: .cognitive, lastUsed: Date()),
            Skill(name: "Creativity", proficiency: 0.5, category: .creative, lastUsed: Date()),
            Skill(name: "Technical", proficiency: 0.5, category: .technical, lastUsed: Date()),
            Skill(name: "Leadership", proficiency: 0.5, category: .social, lastUsed: Date()),
            Skill(name: "Organization", proficiency: 0.5, category: .productivity, lastUsed: Date()),
            Skill(name: "Time Management", proficiency: 0.5, category: .productivity, lastUsed: Date())
        ]
    }
    
    func startLearning() {
        isActive = true
        learningEngine.startLearning { [weak self] progress in
            DispatchQueue.main.async {
                self?.learningProgress = progress
            }
        }
    }
    
    func recordDecision(_ decision: DecisionRecord) {
        decisionHistory.append(decision)
        learningEngine.processDecision(decision)
        updateBehavioralProfile()
    }
    
    func updateBehavioralProfile() {
        behavioralProfile = learningEngine.generateProfile()
    }
    
    func makeProxyDecision(context: DecisionContext) -> ProxyDecision {
        guard privacySettings.allowProxyDecisions else {
            return ProxyDecision(action: .requireUserApproval, confidence: 0.0, reasoning: "Proxy decisions disabled by privacy settings", alternativeOptions: [])
        }
        
        return decisionEngine.makeDecision(
            context: context,
            profile: behavioralProfile,
            preferences: preferences,
            personality: personalityTraits
        )
    }
}

struct BehavioralProfile: Codable {
    var decisionStyle: DecisionStyle
    var riskTolerance: Double
    var communicationStyle: CommunicationStyle
    var workStyle: WorkStyle
    var socialPatterns: SocialPatterns
    var learningStyle: LearningStyle
    
    enum DecisionStyle: String, Codable {
        case analytical
        case intuitive
        case collaborative
        case decisive
    }
    
    enum CommunicationStyle: String, Codable {
        case direct
        case diplomatic
        case expressive
        case reserved
    }
    
    enum WorkStyle: String, Codable {
        case focused
        case multitasking
        case collaborative
        case independent
    }
    
    enum LearningStyle: String, Codable {
        case visual
        case auditory
        case kinesthetic
        case reading
    }
    
    init() {
        self.decisionStyle = .analytical
        self.riskTolerance = 0.5
        self.communicationStyle = .diplomatic
        self.workStyle = .focused
        self.socialPatterns = SocialPatterns()
        self.learningStyle = .reading
    }
}

struct SocialPatterns: Codable {
    var meetingPreferences: MeetingPreferences
    var collaborationStyle: CollaborationStyle
    var responseTime: ResponseTime
    
    enum MeetingPreferences: String, Codable {
        case morning
        case afternoon
        case evening
        case flexible
    }
    
    enum CollaborationStyle: String, Codable {
        case leader
        case contributor
        case observer
        case facilitator
    }
    
    enum ResponseTime: String, Codable {
        case immediate
        case sameDay
        case nextDay
        case flexible
    }
    
    init() {
        self.meetingPreferences = .flexible
        self.collaborationStyle = .contributor
        self.responseTime = .sameDay
    }
}

struct UserPreferences: Codable {
    var workHours: WorkHours
    var notificationPreferences: NotificationPreferences
    var toolPreferences: ToolPreferences
    var contentPreferences: ContentPreferences
    
    struct WorkHours: Codable {
        var startHour: Int
        var endHour: Int
        var breakDuration: Int
        
        init() {
            self.startHour = 9
            self.endHour = 17
            self.breakDuration = 60
        }
    }
    
    struct NotificationPreferences: Codable {
        var emailEnabled: Bool
        var pushEnabled: Bool
        var summaryEnabled: Bool
        var quietHours: QuietHours
        
        struct QuietHours: Codable {
            var enabled: Bool
            var startHour: Int
            var endHour: Int
            
            init() {
                self.enabled = true
                self.startHour = 22
                self.endHour = 8
            }
        }
        
        init() {
            self.emailEnabled = true
            self.pushEnabled = true
            self.summaryEnabled = true
            self.quietHours = QuietHours()
        }
    }
    
    struct ToolPreferences: Codable {
        var preferredEditor: String
        var terminalPreference: String
        var browserPreference: String
        
        init() {
            self.preferredEditor = "VS Code"
            self.terminalPreference = "iTerm2"
            self.browserPreference = "Safari"
        }
    }
    
    struct ContentPreferences: Codable {
        var contentPreferences: ContentPreferences
        
        init() {
            self.contentPreferences = ContentPreferences()
        }
    }
    
    init() {
        self.workHours = WorkHours()
        self.notificationPreferences = NotificationPreferences()
        self.toolPreferences = ToolPreferences()
        self.contentPreferences = ContentPreferences()
    }
}

struct PersonalityTraits: Codable {
    var openness: Double
    var conscientiousness: Double
    var extraversion: Double
    var agreeableness: Double
    var neuroticism: Double
    
    init() {
        self.openness = 0.5
        self.conscientiousness = 0.5
        self.extraversion = 0.5
        self.agreeableness = 0.5
        self.neuroticism = 0.5
    }
}

struct Skill: Identifiable, Codable {
    let id = UUID()
    var name: String
    var proficiency: Double
    var category: SkillCategory
    var lastUsed: Date
    
    enum SkillCategory: String, Codable {
        case social
        case cognitive
        case creative
        case technical
        case productivity
    }
    
    init(name: String, proficiency: Double, category: SkillCategory, lastUsed: Date) {
        self.name = name
        self.proficiency = proficiency
        self.category = category
        self.lastUsed = lastUsed
    }
}

struct DecisionRecord: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    var context: String
    let options: [String]
    let choice: String
    let reasoning: String
    let satisfaction: Double
    let outcome: DecisionOutcome
    
    enum DecisionOutcome: String, Codable {
        case successful
        case partiallySuccessful
        case unsuccessful
    }
}

struct DailyPattern: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let type: String
    let description: String
    let confidence: Double
    let productivity: Double
    let decisions: Int
}

struct TwinAvatar: Codable {
    var name: String
    var appearance: AvatarAppearance
    var expression: AvatarExpression
    var customization: AvatarCustomization
    
    struct AvatarAppearance: Codable {
        var style: AvatarStyle
        var colorScheme: ColorScheme
        
        enum AvatarStyle: String, Codable {
            case minimalist
            case realistic
            case abstract
            case cartoon
        }
        
        enum ColorScheme: String, Codable {
            case blue
            case green
            case purple
            case orange
            case custom
        }
        
        init() {
            self.style = .minimalist
            self.colorScheme = .blue
        }
    }
    
    struct AvatarExpression: Codable {
        var currentExpression: Expression
        
        enum Expression: String, Codable {
            case neutral
            case happy
            case focused
            case thinking
            case concerned
        }
        
        init() {
            self.currentExpression = .neutral
        }
    }
    
    struct AvatarCustomization: Codable {
        var accessories: [String]
        var background: String
        var animationStyle: AnimationStyle
        
        enum AnimationStyle: String, Codable {
            case subtle
            case moderate
            case expressive
            case none
        }
        
        init() {
            self.accessories = []
            self.background = "gradient"
            self.animationStyle = .subtle
        }
    }
    
    init() {
        self.name = "My Digital Twin"
        self.appearance = AvatarAppearance()
        self.expression = AvatarExpression()
        self.customization = AvatarCustomization()
    }
}

struct PrivacySettings: Codable {
    var dataRetentionDays: Int
    var allowProxyDecisions: Bool
    var shareAnonymizedData: Bool
    var encryptionEnabled: Bool
    var localOnly: Bool
    var sensitiveCategories: [String]
    
    init() {
        self.dataRetentionDays = 90
        self.allowProxyDecisions = false
        self.shareAnonymizedData = false
        self.encryptionEnabled = true
        self.localOnly = true
        self.sensitiveCategories = ["health", "finance", "personal"]
    }
}

struct IntegrationStatus: Codable {
    var connectedApps: [ConnectedApp]
    var lastSync: Date
    var syncStatus: SyncStatus
    
    struct ConnectedApp: Codable {
        var name: String
        var lastConnected: Date
        var dataShared: Bool
    }
    
    enum SyncStatus: String, Codable {
        case synced
        case pending
        case error
    }
    
    init() {
        self.connectedApps = []
        self.lastSync = Date()
        self.syncStatus = .synced
    }
}

struct ProxyDecision {
    let action: ProxyAction
    let confidence: Double
    let reasoning: String
    let alternativeOptions: [String]
    
    enum ProxyAction {
        case execute
        case requireUserApproval
        case `defer`
        case suggest
    }
}

struct DecisionContext {
    let situation: String
    let urgency: Double
    let impact: Double
}
