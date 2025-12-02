//
//  SubscriptionManager.swift
//  Hallo
//
//  Purpose: High-level subscription utilities for premium feature access
//  Key Features:
//    • Convenient entitlement checking for "Remi Unlimited"
//    • Superwall paywall presentation helpers
//    • Customer Center presentation for subscription management
//  Dependencies: Foundation, SwiftUI, SuperwallKit, RevenueCat
//
//  Business Context: Simplifies subscription checks and paywall presentation throughout the app
//  Critical Paths: Feature access → Entitlement check → Paywall presentation (if needed)
//
//  Created by Claude Code on 2025-11-15
//

import Foundation
import SwiftUI
import SuperwallKit
import RevenueCat

/// High-level subscription utilities for the Hallo app
///
/// This class provides convenient methods for:
/// - Checking "Remi Unlimited" entitlement
/// - Presenting Superwall paywalls
/// - Opening Customer Center for subscription management
/// - Checking subscription status
///
/// ## Usage:
/// ```swift
/// // Check premium access
/// if await SubscriptionManager.shared.hasUnlimitedAccess() {
///     // Show premium feature
/// } else {
///     // Show paywall
///     SubscriptionManager.shared.presentPaywall(event: "premium_feature")
/// }
/// ```
@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    /// Entitlement identifier for premium features
    static let unlimitedEntitlementID = "Remi Unlimited"

    // MARK: - Initialization

    private init() {}

    // MARK: - Entitlement Checking

    /// Check if user has "Remi Unlimited" premium access
    /// - Returns: True if user has active unlimited entitlement
    func hasUnlimitedAccess() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let hasAccess = customerInfo.entitlements[Self.unlimitedEntitlementID]?.isActive == true
            return hasAccess

        } catch {
            print("❌ [SubscriptionManager] Failed to check unlimited access: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if user has any active subscription
    /// - Returns: True if user has at least one active subscription
    func hasActiveSubscription() async -> Bool {
        #if DEBUG
        // ⚠️ DEBUG BYPASS: Set to true to bypass subscription check in debug builds
        // Set to false when testing actual purchases/paywall
        let debugBypass = false

        if debugBypass {
            print("⚠️ [SubscriptionManager] DEBUG MODE: Bypassing subscription check (always granting access)")
            return true
        }
        #endif

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let hasActive = !customerInfo.entitlements.active.isEmpty
            return hasActive

        } catch {
            print("❌ [SubscriptionManager] Failed to check active subscription: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Paywall Presentation (Superwall)

    /// Present Superwall paywall for a specific placement
    /// - Parameters:
    ///   - event: Placement name configured in Superwall dashboard
    ///   - params: Optional placement parameters for targeting
    ///   - paywallOverrides: Optional paywall customization
    func presentPaywall(
        event: String,
        params: [String: Any]? = nil,
        paywallOverrides: PaywallOverrides? = nil
    ) {
        Superwall.shared.register(placement: event, params: params, handler: nil, feature: {})
    }

    /// Present Superwall paywall with custom identifier (placement)
    /// - Parameter placement: Placement identifier from Superwall dashboard
    func presentPaywallByPlacement(_ placement: String) {
        Superwall.shared.register(placement: placement) {}
    }

    // MARK: - Customer Center (RevenueCat)

    /// Check if Customer Center should be displayed
    /// - Returns: True if customer has active subscription and Customer Center is configured
    func shouldDisplayCustomerCenter() async -> Bool {
        // Customer Center should only show for users with active subscriptions
        return await hasActiveSubscription()
    }

    // MARK: - Subscription Info

    /// Get current subscription expiration date
    /// - Returns: Expiration date if user has active subscription, nil otherwise
    func getSubscriptionExpirationDate() async -> Date? {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()

            // Get the latest expiration date from active subscriptions
            let expirationDates = customerInfo.entitlements.active.values.compactMap { $0.expirationDate }
            return expirationDates.max()

        } catch {
            print("❌ [SubscriptionManager] Failed to get expiration date: \(error.localizedDescription)")
            return nil
        }
    }

    /// Get active product identifier (e.g., "monthly" or "yearly")
    /// - Returns: Product identifier if user has active subscription
    func getActiveProductIdentifier() async -> String? {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()

            // Return the first active subscription product ID
            return customerInfo.activeSubscriptions.first

        } catch {
            print("❌ [SubscriptionManager] Failed to get active product: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    /// - Returns: True if restoration was successful
    func restorePurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            return !customerInfo.entitlements.active.isEmpty

        } catch {
            print("❌ [SubscriptionManager] Restore failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Present paywall when condition is not met
    /// - Parameters:
    ///   - event: Superwall event name
    ///   - condition: Condition that must be true to access feature
    /// - Returns: View with paywall presentation logic
    func requiresSubscription(event: String, condition: Bool) -> some View {
        self.onAppear {
            if !condition {
                SubscriptionManager.shared.presentPaywall(event: event)
            }
        }
    }
}
