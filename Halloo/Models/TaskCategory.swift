import Foundation
import SwiftUI

// MARK: - Task Category
enum TaskCategory: String, CaseIterable, Codable {
    case medication = "medication"
    case exercise = "exercise"
    case social = "social"
    case health = "health"
    case meal = "meal"
    case hygiene = "hygiene"
    case safety = "safety"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .medication:
            return "Medication"
        case .exercise:
            return "Exercise"
        case .social:
            return "Social"
        case .health:
            return "Health Check"
        case .meal:
            return "Meals"
        case .hygiene:
            return "Personal Care"
        case .safety:
            return "Safety"
        case .other:
            return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .medication:
            return "pills.fill"
        case .exercise:
            return "figure.walk"
        case .social:
            return "person.2.fill"
        case .health:
            return "heart.fill"
        case .meal:
            return "fork.knife"
        case .hygiene:
            return "drop.fill"
        case .safety:
            return "shield.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .medication:
            return .red
        case .exercise:
            return .green
        case .social:
            return .blue
        case .health:
            return .pink
        case .meal:
            return .orange
        case .hygiene:
            return .cyan
        case .safety:
            return .yellow
        case .other:
            return .gray
        }
    }
    
    var defaultDeadlineMinutes: Int {
        switch self {
        case .medication:
            return 15 // More urgent
        case .health, .safety:
            return 30 // Important but not as time-sensitive
        case .exercise, .hygiene:
            return 60 // Can be done within an hour
        case .meal:
            return 30 // Food timing matters
        case .social:
            return 120 // Social activities are flexible
        case .other:
            return 60 // Default
        }
    }
    
    var suggestedReminders: [String] {
        switch self {
        case .medication:
            return [
                "Take morning medication",
                "Take evening medication",
                "Check blood pressure",
                "Apply prescription cream"
            ]
        case .exercise:
            return [
                "Take a 10-minute walk",
                "Do stretching exercises",
                "Physical therapy exercises",
                "Chair exercises"
            ]
        case .social:
            return [
                "Call family member",
                "Video chat with grandchildren",
                "Attend community activity",
                "Check in with neighbor"
            ]
        case .health:
            return [
                "Check blood glucose",
                "Weigh yourself",
                "Take temperature",
                "Record symptoms"
            ]
        case .meal:
            return [
                "Eat breakfast",
                "Drink water",
                "Take vitamins with lunch",
                "Prepare dinner"
            ]
        case .hygiene:
            return [
                "Brush teeth",
                "Take shower",
                "Apply moisturizer",
                "Trim nails"
            ]
        case .safety:
            return [
                "Check door locks",
                "Turn off stove",
                "Charge medical alert device",
                "Clear walkways"
            ]
        case .other:
            return [
                "Custom reminder",
                "Daily check-in",
                "Complete task"
            ]
        }
    }
}

// MARK: - Quiet Hours Validation (TCPA Compliance)
extension TaskCategory {
    /// Allowed hour range for SMS (TCPA quiet hours compliance)
    /// Hard limit: 6 AM - 9 PM per TCPA regulations
    /// Category-specific start times vary based on typical schedules
    var allowedHourRange: ClosedRange<Int> {
        switch self {
        case .medication:
            return 6...21  // 6 AM - 9 PM (critical reminders, earliest start)
        case .health, .safety:
            return 7...21  // 7 AM - 9 PM (important but not as urgent as meds)
        case .meal:
            return 6...21  // 6 AM - 9 PM (breakfast starts early, dinner ends by 9 PM)
        case .exercise:
            return 8...20  // 8 AM - 8 PM (avoid early morning/late evening)
        case .hygiene:
            return 7...21  // 7 AM - 9 PM (morning routine to evening routine)
        case .social:
            return 9...21  // 9 AM - 9 PM (respectful hours for social contact)
        case .other:
            return 8...20  // 8 AM - 8 PM (conservative default)
        }
    }

    /// Check if a given time is allowed for SMS based on category and timezone
    /// - Parameters:
    ///   - date: The date/time to check
    ///   - timezone: The timezone to evaluate (typically profile's timezone)
    /// - Returns: True if SMS can be sent at this time
    func isTimeAllowed(_ date: Date, in timezone: TimeZone) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let hour = calendar.component(.hour, from: date)
        return allowedHourRange.contains(hour)
    }

    /// Get next allowed send time if current time is in quiet hours
    /// - Parameters:
    ///   - date: Current date/time
    ///   - timezone: Profile's timezone
    /// - Returns: Next allowed Date, or nil if already in allowed window
    func nextAllowedTime(after date: Date, in timezone: TimeZone) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let hour = calendar.component(.hour, from: date)

        // Already in allowed window
        if allowedHourRange.contains(hour) {
            return nil
        }

        // Before allowed window starts
        if hour < allowedHourRange.lowerBound {
            // Set to start of allowed window today
            return calendar.date(bySettingHour: allowedHourRange.lowerBound, minute: 0, second: 0, of: date)
        }

        // After allowed window ends
        // Set to start of allowed window tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            return calendar.date(bySettingHour: allowedHourRange.lowerBound, minute: 0, second: 0, of: tomorrow)
        }

        return nil
    }

    /// Human-readable quiet hours description
    var quietHoursDescription: String {
        let startHour = allowedHourRange.lowerBound
        let endHour = allowedHourRange.upperBound

        let formatter = DateFormatter()
        formatter.dateFormat = "h a"

        let startDate = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: Date()) ?? Date()
        let endDate = Calendar.current.date(bySettingHour: endHour, minute: 0, second: 0, of: Date()) ?? Date()

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}