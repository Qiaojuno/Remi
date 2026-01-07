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
import FirebaseFirestore
import FirebaseAuth

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

    // MARK: - Change Detection

    /// Tracks last synced status to prevent redundant Firestore writes
    private var lastSyncedSubscriptionStatus: Bool?

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
    ///
    /// - Important: This method checks RevenueCat entitlements.
    ///   Server-side validation also occurs in Cloud Functions for SMS operations.
    ///
    /// - Note: Prefer `hasActiveSubscriptionCached()` for UI checks to avoid API calls.
    ///   Use this method only when fresh data from RevenueCat is required.
    func hasActiveSubscription() async -> Bool {
        // SECURITY: No client-side bypass allowed
        // All subscription checks must go through RevenueCat
        // Server-side validation is the authoritative source for SMS operations

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let hasActive = !customerInfo.entitlements.active.isEmpty
            return hasActive

        } catch {
            print("❌ [SubscriptionManager] Failed to check active subscription: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Cached Subscription Checks (No API Calls)

    /// Check subscription using cached customer info (no API call)
    ///
    /// Use this for UI checks where instant response is needed and freshness isn't critical.
    /// The cache is automatically updated by RevenueCat's customerInfoStream listener.
    ///
    /// - Returns: True if user has active subscription based on cached data
    func hasActiveSubscriptionCached() -> Bool {
        return RevenueCatSubscriptionService.shared.hasActiveSubscriptionCached
    }

    /// Check "Remi Unlimited" access using cached data (no API call)
    ///
    /// - Returns: True if user has unlimited entitlement based on cached data
    func hasUnlimitedAccessCached() -> Bool {
        guard let customerInfo = RevenueCatSubscriptionService.shared.currentCustomerInfo else {
            return false
        }
        return customerInfo.entitlements[Self.unlimitedEntitlementID]?.isActive == true
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

    // MARK: - Firestore Subscription Sync

    /// Sync subscription status to Firestore for server-side validation
    ///
    /// This method should be called:
    /// - On app launch after authentication
    /// - After purchase completion
    /// - After restore purchases
    ///
    /// This provides a fallback in case RevenueCat webhook events are delayed or missed.
    /// The Cloud Functions use this Firestore data to validate subscription before sending SMS.
    ///
    /// - Returns: True if sync was successful
    @discardableResult
    func syncSubscriptionStatusToFirestore() async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ [SubscriptionManager] Cannot sync: No authenticated user")
            return false
        }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let hasActive = !customerInfo.entitlements.active.isEmpty

            // Get subscription details
            let expirationDate = customerInfo.entitlements.active.values
                .compactMap { $0.expirationDate }
                .max()

            let productId = customerInfo.activeSubscriptions.first

            // Prepare Firestore update
            var subscriptionData: [String: Any] = [
                "subscriptionActive": hasActive,
                "subscriptionSyncedAt": FieldValue.serverTimestamp(),
                "subscriptionSyncSource": "ios_app"
            ]

            if let productId = productId {
                subscriptionData["subscriptionProductId"] = productId
            }

            if let expirationDate = expirationDate {
                subscriptionData["subscriptionExpiresAt"] = Timestamp(date: expirationDate)
            }

            // If subscription is not active, record expiration
            if !hasActive {
                subscriptionData["subscriptionExpiredAt"] = FieldValue.serverTimestamp()
            }

            // Update Firestore
            try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .updateData(subscriptionData)

            print("✅ [SubscriptionManager] Synced subscription status to Firestore: active=\(hasActive)")
            return true

        } catch {
            print("❌ [SubscriptionManager] Failed to sync subscription to Firestore: \(error.localizedDescription)")
            return false
        }
    }

    /// Called when RevenueCat customer info updates (e.g., after purchase, renewal, expiration)
    /// This should be set up as a listener in App.swift
    ///
    /// Only syncs to Firestore when subscription status actually changes to prevent
    /// redundant writes and reduce costs.
    func handleCustomerInfoUpdate(_ customerInfo: RevenueCat.CustomerInfo) {
        let currentStatus = !customerInfo.entitlements.active.isEmpty

        // Only sync to Firestore if subscription status actually changed
        guard lastSyncedSubscriptionStatus != currentStatus else {
            #if DEBUG
            print("ℹ️ [SubscriptionManager] Subscription status unchanged (\(currentStatus)), skipping Firestore sync")
            #endif
            return
        }

        #if DEBUG
        print("🔄 [SubscriptionManager] Subscription status changed: \(lastSyncedSubscriptionStatus ?? false) → \(currentStatus)")
        #endif

        lastSyncedSubscriptionStatus = currentStatus

        _Concurrency.Task {
            await syncSubscriptionStatusToFirestore()
        }
    }

    /// Reset the sync state (call on logout)
    func resetSyncState() {
        lastSyncedSubscriptionStatus = nil
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
