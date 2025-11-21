import Foundation
import FirebaseFirestore

// MARK: - User Model
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let fullName: String
    let phoneNumber: String
    let createdAt: Date
    let subscriptionStatus: SubscriptionStatus
    let trialEndDate: Date?
    let quizAnswers: [String: String]? // Optional - kept for analytics/personalization

    // Auto-calculated fields (updated by DatabaseService)
    var profileCount: Int
    var taskCount: Int
    var updatedAt: Date
    var lastSyncTimestamp: Date?

    // MARK: - SMS Quota Management (Billing & Usage Tracking)
    /// Maximum SMS allowed per month (based on subscription tier)
    var smsQuotaLimit: Int

    /// SMS used in current billing period
    var smsQuotaUsed: Int

    /// Start of current SMS quota period
    var smsQuotaPeriodStart: Date

    /// End of current SMS quota period (quota resets after this date)
    var smsQuotaPeriodEnd: Date

    /// ✅ ARCHITECTURE: Subscription managed by RevenueCat (not app-side)
    /// - subscriptionStatus: Deprecated (kept for backward compatibility only)
    /// - trialEndDate: Deprecated (RevenueCat handles trials via product config)
    /// New users should check subscription via RevenueCat SDK, not these fields
    init(
        id: String,
        email: String,
        fullName: String,
        phoneNumber: String,
        createdAt: Date,
        subscriptionStatus: SubscriptionStatus = .active, // Default to active (RevenueCat controls access)
        trialEndDate: Date? = nil, // Deprecated - don't use for new users
        quizAnswers: [String: String]? = nil,
        profileCount: Int = 0,
        taskCount: Int = 0,
        updatedAt: Date = Date(),
        lastSyncTimestamp: Date? = nil,
        smsQuotaLimit: Int = 50,
        smsQuotaUsed: Int = 0,
        smsQuotaPeriodStart: Date = Date(),
        smsQuotaPeriodEnd: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.subscriptionStatus = subscriptionStatus
        self.trialEndDate = trialEndDate
        self.quizAnswers = quizAnswers
        self.profileCount = profileCount
        self.taskCount = taskCount
        self.updatedAt = updatedAt
        self.lastSyncTimestamp = lastSyncTimestamp
        self.smsQuotaLimit = smsQuotaLimit
        self.smsQuotaUsed = smsQuotaUsed
        self.smsQuotaPeriodStart = smsQuotaPeriodStart
        self.smsQuotaPeriodEnd = smsQuotaPeriodEnd
    }

    // MARK: - Custom Codable Implementation with Diagnostic Logging

    enum CodingKeys: String, CodingKey {
        case id, email, fullName, phoneNumber, createdAt
        case subscriptionStatus, trialEndDate, quizAnswers
        case profileCount, taskCount, updatedAt, lastSyncTimestamp
        case smsQuotaLimit, smsQuotaUsed, smsQuotaPeriodStart, smsQuotaPeriodEnd
    }

    init(from decoder: Decoder) throws {
        print("🔵 Decoding User from Firestore")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        fullName = try container.decode(String.self, forKey: .fullName)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        subscriptionStatus = try container.decode(SubscriptionStatus.self, forKey: .subscriptionStatus)

        // Optional fields
        trialEndDate = try? container.decodeIfPresent(Date.self, forKey: .trialEndDate)
        quizAnswers = try? container.decodeIfPresent([String: String].self, forKey: .quizAnswers)

        // Date fields (handle Firestore Timestamp)
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            print("⚠️ [User] createdAt missing for user \(id), using current date")
            createdAt = Date()
        }

        // Auto-calculated fields with fallback
        profileCount = (try? container.decodeIfPresent(Int.self, forKey: .profileCount)) ?? 0
        taskCount = (try? container.decodeIfPresent(Int.self, forKey: .taskCount)) ?? 0

        // updatedAt field (handle Firestore Timestamp or Date)
        if let timestamp = try? container.decode(Timestamp.self, forKey: .updatedAt) {
            updatedAt = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .updatedAt) {
            updatedAt = date
        } else {
            print("⚠️ [User] updatedAt missing for user \(id), using current date")
            updatedAt = Date()
        }

        // lastSyncTimestamp (optional)
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: .lastSyncTimestamp) {
            lastSyncTimestamp = timestamp.dateValue()
        } else {
            lastSyncTimestamp = try? container.decodeIfPresent(Date.self, forKey: .lastSyncTimestamp)
        }

        // SMS Quota fields with defaults (for backward compatibility)
        smsQuotaLimit = (try? container.decodeIfPresent(Int.self, forKey: .smsQuotaLimit)) ?? 50
        smsQuotaUsed = (try? container.decodeIfPresent(Int.self, forKey: .smsQuotaUsed)) ?? 0

        // Quota period dates
        if let timestamp = try? container.decode(Timestamp.self, forKey: .smsQuotaPeriodStart) {
            smsQuotaPeriodStart = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .smsQuotaPeriodStart) {
            smsQuotaPeriodStart = date
        } else {
            smsQuotaPeriodStart = Date()
        }

        if let timestamp = try? container.decode(Timestamp.self, forKey: .smsQuotaPeriodEnd) {
            smsQuotaPeriodEnd = timestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .smsQuotaPeriodEnd) {
            smsQuotaPeriodEnd = date
        } else {
            smsQuotaPeriodEnd = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        }

        print("✅ [User] User decoded successfully - ID: \(id), Email: \(email), Profiles: \(profileCount), Tasks: \(taskCount), SMS Quota: \(smsQuotaUsed)/\(smsQuotaLimit)")
    }

    func encode(to encoder: Encoder) throws {
        print("🔵 [User] Encoding User to Firestore - ID: \(id)")

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(subscriptionStatus, forKey: .subscriptionStatus)
        try container.encodeIfPresent(trialEndDate, forKey: .trialEndDate)
        try container.encodeIfPresent(quizAnswers, forKey: .quizAnswers)
        try container.encode(profileCount, forKey: .profileCount)
        try container.encode(taskCount, forKey: .taskCount)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastSyncTimestamp, forKey: .lastSyncTimestamp)
        try container.encode(smsQuotaLimit, forKey: .smsQuotaLimit)
        try container.encode(smsQuotaUsed, forKey: .smsQuotaUsed)
        try container.encode(smsQuotaPeriodStart, forKey: .smsQuotaPeriodStart)
        try container.encode(smsQuotaPeriodEnd, forKey: .smsQuotaPeriodEnd)

        print("✅ [User] User encoded - ID: \(id), Profiles: \(profileCount), Tasks: \(taskCount), SMS Quota: \(smsQuotaUsed)/\(smsQuotaLimit)")
    }
}

// MARK: - User Extensions
extension User {
    var isTrialActive: Bool {
        guard subscriptionStatus == .trial else { return false }
        guard let trialEnd = trialEndDate else { return false }
        return Date() < trialEnd
    }

    var isSubscriptionActive: Bool {
        switch subscriptionStatus {
        case .active:
            return true
        case .trial:
            return isTrialActive
        case .expired, .cancelled:
            return false
        }
    }

    var subscriptionDisplayText: String {
        switch subscriptionStatus {
        case .trial:
            if isTrialActive {
                return "Free Trial"
            } else {
                return "Trial Expired"
            }
        case .active:
            return "Active Subscription"
        case .expired:
            return "Subscription Expired"
        case .cancelled:
            return "Subscription Cancelled"
        }
    }

    // MARK: - SMS Quota Helpers

    /// Remaining SMS in current quota period
    var smsQuotaRemaining: Int {
        return max(0, smsQuotaLimit - smsQuotaUsed)
    }

    /// Percentage of quota used (0.0 to 1.0)
    var smsQuotaPercentUsed: Double {
        guard smsQuotaLimit > 0 else { return 0 }
        return min(1.0, Double(smsQuotaUsed) / Double(smsQuotaLimit))
    }

    /// Is quota near limit? (80%+ used)
    var isSMSQuotaNearLimit: Bool {
        return smsQuotaPercentUsed >= 0.8
    }

    /// Is quota exceeded?
    var isSMSQuotaExceeded: Bool {
        return smsQuotaUsed >= smsQuotaLimit
    }

    /// Days until quota resets
    var daysUntilQuotaReset: Int {
        return Calendar.current.dateComponents([.day], from: Date(), to: smsQuotaPeriodEnd).day ?? 0
    }

    /// Has quota period expired? (needs reset)
    var needsQuotaReset: Bool {
        return Date() > smsQuotaPeriodEnd
    }

    /// Get quota limit based on subscription status
    static func quotaForSubscription(_ status: SubscriptionStatus) -> Int {
        switch status {
        case .trial:
            return 50 // Free trial: 50 SMS/month
        case .active:
            return 500 // Paid starter: 500 SMS/month (can be tiered later)
        case .expired, .cancelled:
            return 0 // No SMS for expired accounts
        }
    }

    /// Increment SMS usage (call after sending each SMS)
    mutating func incrementSMSUsage() {
        smsQuotaUsed += 1
    }

    /// Reset quota for new period
    mutating func resetSMSQuota() {
        smsQuotaUsed = 0
        smsQuotaPeriodStart = Date()
        smsQuotaPeriodEnd = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }
}