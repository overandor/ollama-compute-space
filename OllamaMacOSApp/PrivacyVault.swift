import Foundation

class PrivacyVault {
    func exportTwinData(
        profile: BehavioralProfile,
        preferences: UserPreferences,
        skills: [Skill],
        history: [DecisionRecord]
    ) -> TwinDataExport {
        // Anonymize data before export
        let anonymizedHistory = history.map { record in
            var anonymized = record
            // Remove sensitive context information
            anonymized.context = anonymizeContext(record.context)
            return anonymized
        }
        
        return TwinDataExport(
            profile: profile,
            preferences: preferences,
            skills: skills,
            history: anonymizedHistory
        )
    }
    
    private func anonymizeContext(_ context: String) -> String {
        // Simple anonymization - replace specific terms with generic ones
        var anonymized = context
        anonymized = anonymized.replacingOccurrences(of: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", with: "[email]", options: .regularExpression)
        anonymized = anonymized.replacingOccurrences(of: "\\d{3}-?\\d{3}-?\\d{4}", with: "[phone]", options: .regularExpression)
        return anonymized
    }
    
    func shouldRetainRecord(_ record: DecisionRecord, retentionDays: Int) -> Bool {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        return record.timestamp > cutoffDate
    }
}

struct TwinDataExport {
    let profile: BehavioralProfile
    let preferences: UserPreferences
    let skills: [Skill]
    let history: [DecisionRecord]
}
