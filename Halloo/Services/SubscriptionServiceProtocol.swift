//
//  SubscriptionServiceProtocol.swift
//  Hallo
//
//  Purpose: Defines subscription and monetization contract for premium elderly care features
//  Key Features:
//    • RevenueCat-powered subscription management with Superwall integration
//    • Entitlement checking for "Remi Unlimited" premium features
//    • Customer info management and purchase handling
//  Dependencies: Foundation, RevenueCat
//
//  Business Context: Enables premium subscription features while working seamlessly with Superwall paywalls
//  Critical Paths: Subscription check → Entitlement validation → Premium feature access
//
//  Created by Claude Code on 2025-11-15
//

import Foundation
import RevenueCat

/// Subscription service contract for managing premium feature access in the Hallo app
///
/// This protocol defines the complete subscription interface working with RevenueCat SDK
/// and Superwall paywalls. It handles entitlement checking, customer info management,
/// and purchase processing for the "Remi Unlimited" premium subscription.
///
/// ## Core Responsibilities:
/// - **Entitlement Management**: Check access to "Remi Unlimited" premium features
/// - **Customer Info**: Retrieve and sync customer subscription status
/// - **Purchase Handling**: Process subscription purchases via RevenueCat
/// - **Restoration**: Restore previous purchases across devices
///
/// ## Integration Notes:
/// - Works with Superwall for paywall UI presentation
/// - RevenueCat handles purchase processing and receipt validation
/// - Automatically syncs with Apple App Store/Google Play
///
/// ## Usage Pattern:
/// ```swift
/// let subscriptionService: SubscriptionServiceProtocol = container.resolve(SubscriptionServiceProtocol.self)
///
/// // Check if user has premium access
/// let hasAccess = await subscriptionService.hasActiveEntitlement(for: "Remi Unlimited")
///
/// // Access current customer info
/// if let customerInfo = subscriptionService.currentCustomerInfo {
///     // Update UI based on subscription status
/// }
/// ```
protocol SubscriptionServiceProtocol {

    /// Current customer information including active subscriptions and entitlements
    var currentCustomerInfo: CustomerInfo? { get }

    // MARK: - Configuration

    /// Configure RevenueCat SDK with API key and user identification
    /// - Parameters:
    ///   - apiKey: RevenueCat API key from dashboard
    ///   - userId: Optional user ID to identify customer (uses anonymous ID if nil)
    func configure(apiKey: String, userId: String?)

    // MARK: - Entitlement Checking

    /// Check if user has access to a specific entitlement
    /// - Parameter entitlementId: Entitlement identifier (e.g., "Remi Unlimited")
    /// - Returns: True if user has active entitlement
    func hasActiveEntitlement(for entitlementId: String) async -> Bool

    /// Check if user has any active subscription
    /// - Returns: True if user has at least one active subscription
    func hasActiveSubscription() async -> Bool

    // MARK: - Customer Info

    /// Fetch latest customer information from RevenueCat
    /// - Returns: Updated customer info with entitlements and subscriptions
    func fetchCustomerInfo() async throws -> CustomerInfo

    /// Sync customer info with user ID
    /// - Parameter userId: User identifier to link RevenueCat customer
    func identify(userId: String) async throws

    /// Clear user identification (useful for logout)
    func logout() async throws

    // MARK: - Purchase Management

    /// Restore previous purchases for this user
    /// - Returns: Restored customer info
    func restorePurchases() async throws -> CustomerInfo

    // MARK: - Offerings (Products)

    /// Get available subscription offerings configured in RevenueCat
    /// - Returns: Current offerings with available packages
    func getOfferings() async throws -> Offerings?
}
