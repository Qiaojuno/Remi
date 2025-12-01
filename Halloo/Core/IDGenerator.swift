import Foundation

// MARK: - ID Generation Strategy
/**
 Centralized ID generation for all Firestore entities.

 RULES:
 1. Users: Firebase Auth UID (passed through, never generated)
 2. Profiles: Normalized phone number in E.164 format (+1XXXXXXXXXX)
 3. Habits: UUID (unique per creation)
 4. Messages: Twilio SID or UUID fallback

 WHY:
 - Predictable IDs (phone) allow upsert logic and prevent duplicates
 - Unique IDs (UUID) prevent conflicts for transient entities
 - Firebase UIDs match authentication system

 USAGE:
 ```swift
 // Creating a user (use Firebase Auth UID directly)
 let userId = firebaseAuth.currentUser.uid

 // Creating a profile (use phone number)
 let profileId = IDGenerator.profileID(phoneNumber: "+1-555-123-4567")
 // Result: "+15551234567"

 // Creating a habit
 let habitId = IDGenerator.habitID()
 // Result: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"

 // Creating a message (with Twilio SID)
 let messageId = IDGenerator.messageID(twilioSID: "SM1234...")
 // Result: "SM1234..." or UUID if nil
 ```
 */
enum IDGenerator {

    // MARK: - User IDs

    /// User IDs must ALWAYS be Firebase Auth UIDs
    /// This method is a pass-through for clarity
    static func userID(firebaseUID: String) -> String {
        assert(!firebaseUID.isEmpty, "Firebase UID cannot be empty")
        return firebaseUID
    }

    // MARK: - Profile IDs

    /// Profile IDs use normalized phone numbers for predictability
    /// This allows upsert logic: same phone = same ID = update instead of duplicate
    ///
    /// - Parameter phoneNumber: Phone number in any format (e.g., "555-123-4567", "+1 (555) 123-4567")
    /// - Returns: E.164 normalized phone number (e.g., "+15551234567")
    static func profileID(phoneNumber: String) -> String {
        let normalized = phoneNumber.normalizedE164()

        assert(normalized.hasPrefix("+"), "Profile ID must be E.164 format: \(normalized)")
        assert(normalized.count >= 11, "Profile ID too short: \(normalized)")

        if !normalized.isE164Format {
            print("⚠️ [ProfileId] Generated ID not in E.164 format - input: \(phoneNumber), output: \(normalized)")
        }

        return normalized
    }

    /// Alternative: Create profile ID from ElderlyProfile object
    static func profileID(from profile: ElderlyProfile) -> String {
        return profileID(phoneNumber: profile.phoneNumber)
    }

    // MARK: - Habit IDs

    /// Habit IDs are always UUIDs (unique per creation)
    /// Habits are transient and unique - no predictable ID needed
    static func habitID() -> String {
        return UUID().uuidString
    }

    // MARK: - Message IDs

    /// Message IDs prefer Twilio SID for traceability, fall back to UUID
    ///
    /// - Parameter twilioSID: Optional Twilio message SID (e.g., "SM1234abcd...")
    /// - Returns: Twilio SID if provided, otherwise UUID
    static func messageID(twilioSID: String? = nil) -> String {
        if let sid = twilioSID, !sid.isEmpty {
            assert(sid.hasPrefix("SM") || sid.hasPrefix("MM"), "Invalid Twilio SID format: \(sid)")
            return sid
        }
        return UUID().uuidString
    }

    // MARK: - Gallery Event IDs

    /// Gallery events are ephemeral and unique
    static func galleryEventID() -> String {
        return UUID().uuidString
    }

    // MARK: - Validation

    /// Validate that an ID matches expected format for entity type
    static func validate(userId: String) -> Bool {
        // Firebase UIDs are typically 28 characters, alphanumeric
        return userId.count > 0 && userId.count <= 128
    }

    static func validate(profileId: String) -> Bool {
        // Profile IDs are E.164 phone numbers: +1234567890 (11-15 chars)
        return profileId.hasPrefix("+") && profileId.count >= 11 && profileId.count <= 15
    }

    static func validate(habitId: String) -> Bool {
        // Habit IDs are UUIDs: 36 characters with hyphens
        return UUID(uuidString: habitId) != nil
    }

    static func validate(messageId: String) -> Bool {
        // Message IDs are either Twilio SIDs or UUIDs
        if messageId.hasPrefix("SM") || messageId.hasPrefix("MM") {
            return messageId.count == 34 // Twilio SID length
        }
        return UUID(uuidString: messageId) != nil
    }
}

// MARK: - String Extensions

extension String {
    /// Normalize phone number to E.164 format: +[country code][area code][number]
    ///
    /// Examples:
    /// - "555-123-4567" → "+15551234567"
    /// - "+1 (555) 123-4567" → "+15551234567"
    /// - "15551234567" → "+15551234567"
    /// - "+15551234567" → "+15551234567" (already normalized)
    ///
    /// - Returns: E.164 formatted phone number with +1 country code (US)
    func normalizedE164() -> String {
        // Remove all non-digit characters except leading +
        var cleaned = self
        if cleaned.hasPrefix("+") {
            cleaned.removeFirst() // Remove + temporarily
            cleaned = cleaned.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            cleaned = "+" + cleaned // Add back +
        } else {
            cleaned = cleaned.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        }

        // Handle different formats
        if cleaned.hasPrefix("+1") && cleaned.count == 12 {
            // Already E.164 with +1
            return cleaned
        } else if cleaned.hasPrefix("+") && cleaned.count == 11 {
            // E.164 without country code, assume US
            return "+1" + String(cleaned.dropFirst())
        } else if cleaned.count == 11 && cleaned.hasPrefix("1") {
            // 11 digits starting with 1 (US country code without +)
            return "+" + cleaned
        } else if cleaned.count == 10 {
            // 10 digits (US number without country code)
            return "+1" + cleaned
        } else {
            // Unknown format - return as-is with warning
            print("⚠️ Could not normalize phone number to E.164: \(self)")
            return cleaned.hasPrefix("+") ? cleaned : "+" + cleaned
        }
    }

    /// Validate if string is E.164 format
    var isE164Format: Bool {
        let pattern = "^\\+[1-9]\\d{1,14}$"
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Usage Examples (for documentation)

#if DEBUG
extension IDGenerator {
    static func runExamples() {
        // Example code removed - use unit tests instead
        _ = userID(firebaseUID: "abc123xyz")
        _ = profileID(phoneNumber: "555-123-4567")
        _ = habitID()
        _ = messageID(twilioSID: "SM1234567890abcdef1234567890abcd")
    }
}
#endif
