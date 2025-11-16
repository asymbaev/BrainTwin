import Foundation

// MARK: - Onboarding Data (Local Storage)

struct OnboardingData: Codable {
    let name: String
    let age: Int
    let goal: String
    let struggle: String
    let preferredTime: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case age
        case goal
        case struggle
        case preferredTime = "preferred_time"
    }
}

// MARK: - Meter Response (for Dashboard)

struct MeterResponse: Codable {
    let progress: Double
    let skillLevel: String
    let streak: Int
    let nextLevelAt: Double
    let completedProtocols: Int
    let levelUpMessage: String?
    
    
    enum CodingKeys: String, CodingKey {
        case progress
        case skillLevel
        case streak
        case nextLevelAt
        case completedProtocols
        case levelUpMessage
    }
}

// MARK: - Protocol Models (keep for now, we'll phase out later)

struct Protocol: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let steps: [ProtocolStep]
    let durationSeconds: Int
    let neuroscienceExplanation: String?
    let completedAt: String?
    let assignedForDate: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case steps
        case durationSeconds = "duration_seconds"
        case neuroscienceExplanation = "neuroscience_explanation"
        case completedAt = "completed_at"
        case assignedForDate = "assigned_for_date"
        case createdAt = "created_at"
    }
}

struct ProtocolStep: Codable, Identifiable {
    let id = UUID()
    let instruction: String
    let durationSeconds: Int
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case instruction
        case durationSeconds
        case type
    }
}

// MARK: - Task-Based Models (NEW)

struct DailyTask: Codable, Identifiable {
    let id: String
    let userId: String
    let taskDescription: String
    let date: String
    let brainHackApplied: String?
    let hackExplanation: String?
    let hackNeuroscience: String?
    let appliedAt: String?
    let completedAt: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case taskDescription = "task_description"
        case date
        case brainHackApplied = "brain_hack_applied"
        case hackExplanation = "hack_explanation"
        case hackNeuroscience = "hack_neuroscience"
        case appliedAt = "applied_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }
}

struct BrainHack: Codable {
    let hackName: String
    let quote: String
    let explanation: String
    let neuroscience: String
    let personalization: String?
    let barrier: String
    let isCompleted: Bool?
    let audioUrls: [String]?
}
struct Reflection: Codable, Identifiable {
    let id: String
    let userId: String
    let taskId: String
    let reflectionText: String
    let effectivenessRating: Int?
    let twinFeedback: String?
    let behavioralPattern: String?
    let nextSuggestion: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case taskId = "task_id"
        case reflectionText = "reflection_text"
        case effectivenessRating = "effectiveness_rating"
        case twinFeedback = "twin_feedback"
        case behavioralPattern = "behavioral_pattern"
        case nextSuggestion = "next_suggestion"
        case createdAt = "created_at"
    }
}
