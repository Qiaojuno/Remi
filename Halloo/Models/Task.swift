import Foundation

// MARK: - Task Model
struct Task: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let profileId: String
    let title: String
    let description: String
    let category: TaskCategory
    let frequency: TaskFrequency
    let scheduledTime: Date
    let deadlineMinutes: Int
    let requiresPhoto: Bool
    let requiresText: Bool
    let customDays: [Weekday]
    let startDate: Date
    let endDate: Date?
    var status: TaskStatus
    let createdAt: Date
    var lastModifiedAt: Date
    var completionCount: Int
    var lastCompletedAt: Date?
    var nextScheduledDate: Date
    var lastSMSSentAt: Date?  // Track when SMS reminder was last sent
    let timeZone: String  // Profile's timezone for scheduling (e.g., "America/New_York")

    // Custom decoder to handle old documents missing new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        profileId = try container.decode(String.self, forKey: .profileId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        category = try container.decodeIfPresent(TaskCategory.self, forKey: .category) ?? .other
        frequency = try container.decode(TaskFrequency.self, forKey: .frequency)
        scheduledTime = try container.decode(Date.self, forKey: .scheduledTime)
        deadlineMinutes = try container.decodeIfPresent(Int.self, forKey: .deadlineMinutes) ?? 10
        requiresPhoto = try container.decodeIfPresent(Bool.self, forKey: .requiresPhoto) ?? false
        requiresText = try container.decodeIfPresent(Bool.self, forKey: .requiresText) ?? true
        customDays = try container.decodeIfPresent([Weekday].self, forKey: .customDays) ?? []
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .active
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? Date()
        completionCount = try container.decodeIfPresent(Int.self, forKey: .completionCount) ?? 0
        lastCompletedAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedAt)
        lastSMSSentAt = try container.decodeIfPresent(Date.self, forKey: .lastSMSSentAt)

        // nextScheduledDate: use stored value or fall back to scheduledTime
        nextScheduledDate = try container.decodeIfPresent(Date.self, forKey: .nextScheduledDate) ?? scheduledTime

        // Backward compatibility: old tasks without timezone fall back to device timezone
        timeZone = (try? container.decode(String.self, forKey: .timeZone)) ?? TimeZone.current.identifier
    }

    init(
        id: String,
        userId: String,
        profileId: String,
        title: String,
        description: String = "",
        category: TaskCategory = .other,
        frequency: TaskFrequency = .daily,
        scheduledTime: Date = Date(),
        deadlineMinutes: Int = 10,
        requiresPhoto: Bool = false,
        requiresText: Bool = true,
        customDays: [Weekday] = [],
        startDate: Date = Date(),
        endDate: Date? = nil,
        status: TaskStatus = .active,
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        completionCount: Int = 0,
        lastCompletedAt: Date? = nil,
        nextScheduledDate: Date? = nil,
        lastSMSSentAt: Date? = nil,
        timeZone: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.userId = userId
        self.profileId = profileId
        self.title = title
        self.description = description
        self.category = category
        self.frequency = frequency
        self.scheduledTime = scheduledTime
        self.deadlineMinutes = deadlineMinutes
        self.requiresPhoto = requiresPhoto
        self.requiresText = requiresText
        self.customDays = customDays
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.completionCount = completionCount
        self.lastCompletedAt = lastCompletedAt
        self.nextScheduledDate = nextScheduledDate ?? scheduledTime
        self.lastSMSSentAt = lastSMSSentAt
        self.timeZone = timeZone
    }
}

// MARK: - Task Extensions
extension Task {
    var isActive: Bool {
        return status == .active
    }
    
    var isExpired: Bool {
        guard let endDate = endDate else { return false }
        return Date() > endDate
    }
    
    var shouldExecute: Bool {
        return isActive && !isExpired
    }
    
    var responseRequirements: String {
        if requiresPhoto && requiresText {
            return "Photo and text response required"
        } else if requiresPhoto {
            return "Photo response required"
        } else if requiresText {
            return "Text response required"
        } else {
            return "Any response accepted"
        }
    }
    
    var deadlineDate: Date {
        return scheduledTime.addingTimeInterval(TimeInterval(deadlineMinutes * 60))
    }
    
    var isOverdue: Bool {
        guard shouldExecute else { return false }
        return Date() > deadlineDate
    }
    
    var formattedScheduledTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
    
    var daysSinceLastCompleted: Int? {
        guard let lastCompleted = lastCompletedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: lastCompleted, to: Date()).day
    }
    
    var completionRate: Double {
        guard frequency.isRepeating else { return completionCount > 0 ? 1.0 : 0.0 }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        guard daysSinceStart > 0 else { return 0.0 }
        
        let expectedCompletions: Int
        switch frequency {
        case .daily:
            expectedCompletions = daysSinceStart
        case .weekdays:
            expectedCompletions = calculateWeekdaysSince(startDate)
        case .weekly:
            expectedCompletions = daysSinceStart / 7
        case .custom:
            expectedCompletions = calculateCustomDaysSince(startDate)
        case .once:
            expectedCompletions = 1
        }
        
        guard expectedCompletions > 0 else { return 0.0 }
        return min(Double(completionCount) / Double(expectedCompletions), 1.0)
    }
    
    // MARK: - Scheduling Methods
    
    func isScheduledFor(date: Date) -> Bool {
        let calendar = Calendar.current
        
        // Check if date is within task's active period
        guard date >= calendar.startOfDay(for: startDate) else { return false }
        if let endDate = endDate, date > calendar.startOfDay(for: endDate) {
            return false
        }
        
        // For one-time tasks, check exact date
        if frequency == .once {
            return calendar.isDate(date, inSameDayAs: scheduledTime)
        }
        
        // For recurring tasks, check frequency pattern
        return frequency.isScheduledFor(date: date, customDays: customDays)
    }
    
    func getScheduledTimeFor(date: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: scheduledTime)
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        
        return calendar.date(from: dateComponents) ?? date
    }
    
    func getNextScheduledTime() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        // For one-time tasks, return the scheduled time if it's in the future
        if frequency == .once {
            return scheduledTime > now ? scheduledTime : scheduledTime
        }
        
        // Check if today is a scheduled day and the time hasn't passed
        let todayScheduledTime = getScheduledTimeFor(date: today)
        if isScheduledFor(date: today) && todayScheduledTime > now {
            return todayScheduledTime
        }
        
        // Find next scheduled date
        for daysAhead in 1...14 { // Look ahead up to 2 weeks
            let futureDate = calendar.date(byAdding: .day, value: daysAhead, to: today)!
            if isScheduledFor(date: futureDate) {
                return getScheduledTimeFor(date: futureDate)
            }
        }
        
        // If no future date found, return tomorrow at scheduled time (fallback)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return getScheduledTimeFor(date: tomorrow)
    }
    
    func getNextScheduledTimes(count: Int) -> [Date] {
        var scheduledTimes: [Date] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var searchDate = today
        var daysSearched = 0
        let maxDaysToSearch = count * 2 // Reasonable limit to prevent infinite loops
        
        while scheduledTimes.count < count && daysSearched < maxDaysToSearch {
            if isScheduledFor(date: searchDate) {
                let scheduledTime = getScheduledTimeFor(date: searchDate)
                scheduledTimes.append(scheduledTime)
            }
            
            searchDate = calendar.date(byAdding: .day, value: 1, to: searchDate)!
            daysSearched += 1
        }
        
        return scheduledTimes
    }
    
    // MARK: - Helper Methods
    
    private func calculateWeekdaysSince(_ startDate: Date) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        var weekdayCount = 0
        var currentDate = calendar.startOfDay(for: startDate)
        let endDate = calendar.startOfDay(for: today)
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday >= 2 && weekday <= 6 { // Monday to Friday
                weekdayCount += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return weekdayCount
    }
    
    private func calculateCustomDaysSince(_ startDate: Date) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        var customDayCount = 0
        var currentDate = calendar.startOfDay(for: startDate)
        let endDate = calendar.startOfDay(for: today)
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            let dayOfWeek = Weekday.from(weekday: weekday)
            
            if customDays.contains(dayOfWeek) {
                customDayCount += 1
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return customDayCount
    }
    
    // MARK: - Mutating Methods
    
    mutating func markCompleted() {
        completionCount += 1
        lastCompletedAt = Date()
        lastModifiedAt = Date()
    }
    
    mutating func pause() {
        status = .paused
        lastModifiedAt = Date()
    }
    
    mutating func resume() {
        status = .active
        lastModifiedAt = Date()
    }
    
    mutating func archive() {
        status = .archived
        lastModifiedAt = Date()
    }
    
    mutating func updateStatus() {
        if isExpired && status == .active {
            status = .expired
            lastModifiedAt = Date()
        }
    }
}