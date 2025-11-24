import Foundation

// MARK: - Elderly Profile Model
struct ElderlyProfile: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let phoneNumber: String
    let relationship: String
    let isEmergencyContact: Bool
    let timeZone: String
    let notes: String
    var photoURL: String?
    var status: ProfileStatus
    let createdAt: Date
    var lastActiveAt: Date
    var confirmedAt: Date?

    // MARK: - SMS Opt-Out Tracking (TCPA Compliance)
    /// Whether the elderly person has opted out of SMS (via STOP keyword or other method)
    var smsOptedOut: Bool

    /// Date when the elderly person opted out of SMS
    var optOutDate: Date?

    /// Method used to opt out (e.g., "STOP_KEYWORD", "MANUAL_REQUEST", "FAMILY_REQUEST")
    var optOutMethod: String?

    // MARK: - Rate Limiting (Safety Protection)
    /// Maximum SMS allowed per day for this profile (default: 10)
    var dailySMSLimit: Int

    /// Last date an SMS was sent to this profile
    var lastSMSDate: Date?

    /// Count of SMS sent today (resets at midnight in profile's timezone)
    var dailySMSCount: Int
    
    
    init(
        id: String,
        userId: String,
        name: String,
        phoneNumber: String,
        relationship: String,
        isEmergencyContact: Bool = false,
        timeZone: String = TimeZone.current.identifier,
        notes: String = "",
        photoURL: String? = nil,
        status: ProfileStatus = .pendingConfirmation,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        confirmedAt: Date? = nil,
        smsOptedOut: Bool = false,
        optOutDate: Date? = nil,
        optOutMethod: String? = nil,
        dailySMSLimit: Int = 10,
        lastSMSDate: Date? = nil,
        dailySMSCount: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.isEmergencyContact = isEmergencyContact
        self.timeZone = timeZone
        self.notes = notes
        self.photoURL = photoURL
        self.status = status
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.confirmedAt = confirmedAt
        self.smsOptedOut = smsOptedOut
        self.optOutDate = optOutDate
        self.optOutMethod = optOutMethod
        self.dailySMSLimit = dailySMSLimit
        self.lastSMSDate = lastSMSDate
        self.dailySMSCount = dailySMSCount
    }

    // MARK: - Custom Codable for Backward Compatibility

    enum CodingKeys: String, CodingKey {
        case id, userId, name, phoneNumber, relationship
        case isEmergencyContact, timeZone, notes, photoURL, status
        case createdAt, lastActiveAt, confirmedAt
        case smsOptedOut, optOutDate, optOutMethod
        case dailySMSLimit, lastSMSDate, dailySMSCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        relationship = try container.decode(String.self, forKey: .relationship)
        isEmergencyContact = try container.decode(Bool.self, forKey: .isEmergencyContact)
        timeZone = (try? container.decode(String.self, forKey: .timeZone))
            ?? TimeZone.current.identifier
        notes = try container.decode(String.self, forKey: .notes)
        status = try container.decode(ProfileStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastActiveAt = try container.decode(Date.self, forKey: .lastActiveAt)

        // Optional fields
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        confirmedAt = try container.decodeIfPresent(Date.self, forKey: .confirmedAt)

        // SMS opt-out fields (backward compatibility - default to false/nil/0)
        smsOptedOut = (try? container.decodeIfPresent(Bool.self, forKey: .smsOptedOut)) ?? false
        optOutDate = try? container.decodeIfPresent(Date.self, forKey: .optOutDate)
        optOutMethod = try? container.decodeIfPresent(String.self, forKey: .optOutMethod)

        // Rate limiting fields (backward compatibility - default to 10/nil/0)
        dailySMSLimit = (try? container.decodeIfPresent(Int.self, forKey: .dailySMSLimit)) ?? 10
        lastSMSDate = try? container.decodeIfPresent(Date.self, forKey: .lastSMSDate)
        dailySMSCount = (try? container.decodeIfPresent(Int.self, forKey: .dailySMSCount)) ?? 0
    }
}

// MARK: - Elderly Profile Extensions
extension ElderlyProfile {
    var isConfirmed: Bool {
        return status == .confirmed && confirmedAt != nil
    }

    var canReceiveTasks: Bool {
        return status == .confirmed
    }

    /// Can this profile receive SMS? (confirmed AND not opted out)
    var canReceiveSMS: Bool {
        return status == .confirmed && !smsOptedOut
    }

    var displayTimeZone: TimeZone {
        return TimeZone(identifier: timeZone) ?? TimeZone.current
    }

    var daysSinceCreated: Int {
        return Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }

    mutating func markAsActive() {
        self.lastActiveAt = Date()
    }

    mutating func confirmProfile() {
        self.status = .confirmed
        self.confirmedAt = Date()
        self.lastActiveAt = Date()
    }

    mutating func deactivateProfile() {
        self.status = .inactive
    }

    // MARK: - SMS Opt-Out Management

    /// Opt out of SMS (called when STOP keyword received)
    mutating func optOutOfSMS(method: String = "STOP_KEYWORD") {
        self.smsOptedOut = true
        self.optOutDate = Date()
        self.optOutMethod = method
        self.lastActiveAt = Date()
    }

    /// Re-subscribe to SMS (called when user re-confirms)
    mutating func optInToSMS() {
        self.smsOptedOut = false
        self.optOutDate = nil
        self.optOutMethod = nil
        self.lastActiveAt = Date()
    }

    // MARK: - Rate Limiting Helpers

    /// Check if we can send another SMS today (based on daily limit)
    func canSendSMSToday() -> Bool {
        guard !smsOptedOut else { return false }

        // Check if it's a new day (reset counter)
        let calendar = Calendar.current
        if let lastSMS = lastSMSDate,
           !calendar.isDate(lastSMS, inSameDayAs: Date()) {
            // New day - counter will be reset by incrementSMSCount()
            return true
        }

        // Same day - check against limit
        return dailySMSCount < dailySMSLimit
    }

    /// Increment SMS count (called after sending SMS)
    mutating func incrementSMSCount() {
        let calendar = Calendar.current
        let now = Date()

        // If new day, reset counter
        if let lastSMS = lastSMSDate,
           !calendar.isDate(lastSMS, inSameDayAs: now) {
            self.dailySMSCount = 0
        }

        // Increment counter
        self.dailySMSCount += 1
        self.lastSMSDate = now
        self.lastActiveAt = now
    }

    /// Get SMS usage status for display
    var smsUsageStatus: String {
        if smsOptedOut {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let dateStr = optOutDate.map { formatter.string(from: $0) } ?? "Unknown"
            return "Opted out on \(dateStr) via \(optOutMethod ?? "unknown method")"
        } else if let lastSMS = lastSMSDate,
                  Calendar.current.isDateInToday(lastSMS) {
            return "Sent \(dailySMSCount)/\(dailySMSLimit) SMS today"
        } else {
            return "Ready to receive SMS"
        }
    }
}