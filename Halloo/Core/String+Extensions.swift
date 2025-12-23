import Foundation

// =====================================================
// String+Extensions.swift - SYSTEMATIC RESTORATION  
// =====================================================
// PURPOSE: String validation and formatting utilities
// STATUS: ✅ FIXED - Removed UIKit dependency  
// CHANGE: Updated URL validation to not require UIApplication
// VARIABLES TO REMEMBER: email validation, phone formatting, URL checking
// =====================================================

// MARK: - String Extensions for Validation and Formatting
extension String {
    
    // MARK: - Email Validation
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    // MARK: - Phone Number Validation and Formatting
    var isValidPhoneNumber: Bool {
        let cleanedPhone = self.phoneNumberDigitsOnly
        
        // Check if it has at least 10 digits (US/Canada minimum)
        guard cleanedPhone.count >= 10 else { return false }
        
        // Check if it has at most 15 digits (international maximum)
        guard cleanedPhone.count <= 15 else { return false }
        
        // Ensure all characters are digits
        return cleanedPhone.allSatisfy { $0.isNumber }
    }
    
    var phoneNumberDigitsOnly: String {
        return self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    var formattedPhoneNumber: String {
        let cleaned = phoneNumberDigitsOnly

        // Handle different phone number lengths
        switch cleaned.count {
        case 10:
            // US/Canada format: (555) 123-4567
            let areaCode = String(cleaned.prefix(3))
            let exchange = String(cleaned.dropFirst(3).prefix(3))
            let number = String(cleaned.dropFirst(6))
            return "(\(areaCode)) \(exchange)-\(number)"

        case 11 where cleaned.hasPrefix("1"):
            // US/Canada with country code: +1 (555) 123-4567
            let withoutCountryCode = String(cleaned.dropFirst())
            return "+1 " + withoutCountryCode.formattedPhoneNumber

        default:
            // International format: +XX XXX XXX XXXX
            if cleaned.count > 10 {
                return "+\(cleaned)"
            } else {
                return cleaned
            }
        }
    }

    /// Validates if phone number is in E.164 format (+[country code][number])
    /// Required format for Twilio SMS API
    var isValidE164PhoneNumber: Bool {
        let phoneRegex = "^\\+[1-9]\\d{1,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }

    /// E.164 format phone number for Twilio SMS (e.g., +17788143739)
    ///
    /// Converts any phone number format to E.164 standard required by Twilio.
    /// This format has no spaces, dashes, or parentheses - just + and digits.
    var e164PhoneNumber: String {
        let cleaned = phoneNumberDigitsOnly

        // Handle different phone number lengths
        switch cleaned.count {
        case 10:
            // US/Canada 10-digit number → add +1 country code
            return "+1\(cleaned)"

        case 11 where cleaned.hasPrefix("1"):
            // Already has country code 1 → just add +
            return "+\(cleaned)"

        default:
            // International or other format → just add + if needed
            if cleaned.count > 10 {
                return "+\(cleaned)"
            } else if cleaned.count == 10 {
                // Assume US/Canada if exactly 10 digits
                return "+1\(cleaned)"
            } else {
                // Invalid or too short
                return "+\(cleaned)"
            }
        }
    }
    
    // MARK: - Password Validation
    var hasUppercaseLetter: Bool {
        return self.rangeOfCharacter(from: .uppercaseLetters) != nil
    }
    
    var hasLowercaseLetter: Bool {
        return self.rangeOfCharacter(from: .lowercaseLetters) != nil
    }
    
    var hasNumber: Bool {
        return self.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    var hasSpecialCharacter: Bool {
        let specialCharacterSet = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        return self.rangeOfCharacter(from: specialCharacterSet) != nil
    }
    
    var passwordStrength: PasswordStrength {
        var score = 0
        
        // Length check
        if count >= 8 { score += 1 }
        if count >= 12 { score += 1 }
        
        // Character variety checks
        if hasUppercaseLetter { score += 1 }
        if hasLowercaseLetter { score += 1 }
        if hasNumber { score += 1 }
        if hasSpecialCharacter { score += 1 }
        
        switch score {
        case 0...2:
            return .weak
        case 3...4:
            return .medium
        case 5...6:
            return .strong
        default:
            return .weak
        }
    }
    
    // MARK: - SMS Response Analysis
    var isPositiveSMSResponse: Bool {
        let positiveKeywords = [
            "yes", "y", "done", "complete", "completed", "finished", "ok", "okay",
            "good", "took", "did", "✓", "check", "✅", "👍", "taken"
        ]
        
        let cleanedResponse = self.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        
        return positiveKeywords.contains { keyword in
            cleanedResponse.contains(keyword.lowercased())
        }
    }
    
    var isNegativeSMSResponse: Bool {
        let negativeKeywords = [
            "no", "n", "can't", "cannot", "didn't", "not", "stop", "skip",
            "later", "forgot", "unable", "won't", "❌", "👎"
        ]
        
        let cleanedResponse = self.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        
        return negativeKeywords.contains { keyword in
            cleanedResponse.contains(keyword.lowercased())
        }
    }
    
    var smsResponseConfidence: Double {
        if isPositiveSMSResponse {
            return 0.8
        } else if isNegativeSMSResponse {
            return 0.2
        } else {
            return 0.5 // Neutral/uncertain
        }
    }
    
    // MARK: - Text Formatting
    var capitalizedFirstLetter: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
    
    var trimmedAndCapitalized: String {
        return trimmingCharacters(in: .whitespacesAndNewlines).capitalizedFirstLetter
    }
    
    func truncated(to length: Int, suffix: String = "...") -> String {
        guard count > length else { return self }
        return String(prefix(length)) + suffix
    }
    
    // MARK: - Validation Helpers
    var isNotEmpty: Bool {
        return !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func isLengthBetween(_ min: Int, _ max: Int) -> Bool {
        let length = count
        return length >= min && length <= max
    }
    
    var containsOnlyLettersAndSpaces: Bool {
        let allowedCharacterSet = CharacterSet.letters.union(.whitespaces)
        return self.unicodeScalars.allSatisfy { allowedCharacterSet.contains($0) }
    }
    
    var containsOnlyAlphanumeric: Bool {
        return self.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    // MARK: - URL and Link Validation
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        // Basic URL validation without UIKit dependency
        return url.scheme != nil && url.host != nil
    }
    
    // MARK: - Safe Text Processing
    var safeName: String {
        return self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
            .capitalizedFirstLetter
    }
    
    var safeNotes: String {
        return self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[<>\"'&]", with: "", options: .regularExpression)
    }
}

// MARK: - Password Strength Enum
enum PasswordStrength: String, CaseIterable {
    case weak = "weak"
    case medium = "medium"
    case strong = "strong"
    
    var displayName: String {
        switch self {
        case .weak:
            return "Weak"
        case .medium:
            return "Medium"
        case .strong:
            return "Strong"
        }
    }
    
    var color: String {
        switch self {
        case .weak:
            return "red"
        case .medium:
            return "orange"
        case .strong:
            return "green"
        }
    }
    
    var requirements: [String] {
        switch self {
        case .weak:
            return ["At least 8 characters", "Mix of letters and numbers"]
        case .medium:
            return ["At least 8 characters", "Upper and lowercase letters", "At least one number"]
        case .strong:
            return ["At least 12 characters", "Upper and lowercase letters", "Numbers and special characters"]
        }
    }
}