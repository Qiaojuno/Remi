//
//  PhoneRegistryStatus.swift
//  Halloo
//
//  Purpose: Response model for phone number registry status check
//  Security: Used to check opt-out status before profile creation
//  Created: 2025-01-14
//

import Foundation

/// Response from checkPhoneOptOutStatus Cloud Function
///
/// Used to determine if a phone number has previously opted out (STOP keyword)
/// or was recently confirmed, even if the old profile was deleted.
///
/// This enables TCPA compliance by respecting opt-outs across profile deletions.
struct PhoneRegistryStatus {
    /// Whether the phone number has an active opt-out (replied STOP)
    let optedOut: Bool

    /// Whether the phone number was confirmed within the last 30 days
    let recentlyConfirmed: Bool

    /// Whether the profile can be auto-confirmed (skip SMS confirmation)
    /// True if recentlyConfirmed AND NOT optedOut
    let canAutoConfirm: Bool

    /// Initialize from Cloud Function response
    init(from data: [String: Any]) {
        self.optedOut = data["optedOut"] as? Bool ?? false
        self.recentlyConfirmed = data["recentlyConfirmed"] as? Bool ?? false
        self.canAutoConfirm = data["canAutoConfirm"] as? Bool ?? false
    }

    /// Default status for new phone numbers (not in registry)
    static var newNumber: PhoneRegistryStatus {
        PhoneRegistryStatus(optedOut: false, recentlyConfirmed: false, canAutoConfirm: false)
    }

    /// Direct initializer for testing/previews
    init(optedOut: Bool, recentlyConfirmed: Bool, canAutoConfirm: Bool) {
        self.optedOut = optedOut
        self.recentlyConfirmed = recentlyConfirmed
        self.canAutoConfirm = canAutoConfirm
    }
}
