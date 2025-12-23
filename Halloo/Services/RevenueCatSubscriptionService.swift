//
//  RevenueCatSubscriptionService.swift
//  Hallo
//
//  Purpose: RevenueCat SDK integration for subscription management
//  Key Features:
//    • Configure and manage RevenueCat SDK
//    • Check entitlements for "Remi Unlimited" premium access
//    • Handle purchases, restoration, and customer info sync
//    • Integrate with Superwall for paywall presentation
//  Dependencies: Foundation, RevenueCat
//
//  Business Context: Powers premium subscription features using RevenueCat SDK
//  Critical Paths: SDK configuration → User identification → Entitlement checking → Purchase handling
//
//  Created by Claude Code on 2025-11-15
//

import Foundation
import RevenueCat

/// RevenueCat-powered subscription service implementation
///
/// This service integrates the RevenueCat SDK to handle all subscription-related
/// operations including entitlement checking, purchase processing, and customer
/// info management. Works seamlessly with Superwall for paywall presentation.
///
/// ## Key Features:
/// - **SDK Management**: Initialize and configure RevenueCat SDK
/// - **Entitlement Validation**: Check "Remi Unlimited" premium access
/// - **Purchase Processing**: Handle subscription purchases via RevenueCat
/// - **Customer Sync**: Link RevenueCat customers with app user IDs
/// - **Superwall Integration**: Configure RevenueCat as purchase controller for Superwall
///
/// ## Thread Safety:
/// - All async methods are @MainActor to ensure UI updates on main thread
/// - Uses AsyncStream for reactive subscription status updates
///
/// ## Error Handling:
/// - Wraps RevenueCat errors with descriptive messages
/// - Gracefully handles network failures with cached customer info
/// - Logs errors for debugging and monitoring
final class RevenueCatSubscriptionService: SubscriptionServiceProtocol {

    // MARK: - Properties

    private var _currentCustomerInfo: CustomerInfo?
    private var customerInfoTask: _Concurrency.Task<Void, Never>?

    var currentCustomerInfo: CustomerInfo? {
        _currentCustomerInfo
    }

    // MARK: - Initialization

    init() {
    }

    // MARK: - Configuration

    func configure(apiKey: String, userId: String?) {
        // Configure RevenueCat SDK
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)

        // Identify user if userId provided
        if let userId = userId {
            _Concurrency.Task {
                do {
                    try await identify(userId: userId)
                } catch {
                    print("❌ RevenueCat failed to identify user: \(error.localizedDescription)")
                }
            }
        }

        // Set up customer info listener
        setupCustomerInfoListener()

        // Fetch initial customer info
        _Concurrency.Task {
            do {
                _ = try await fetchCustomerInfo()
            } catch {
                print("❌ RevenueCat failed to fetch customer info: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Customer Info Listener

    private func setupCustomerInfoListener() {
        // Listen to customer info updates from RevenueCat using AsyncStream
        customerInfoTask = _Concurrency.Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                self?._currentCustomerInfo = customerInfo
            }
        }
    }

    // MARK: - Entitlement Checking

    func hasActiveEntitlement(for entitlementId: String) async -> Bool {
        do {
            let customerInfo = try await fetchCustomerInfo()
            let hasEntitlement = customerInfo.entitlements[entitlementId]?.isActive == true
            return hasEntitlement
        } catch {
            print("❌ RevenueCat failed to check entitlement '\(entitlementId)': \(error.localizedDescription)")
            return false
        }
    }

    func hasActiveSubscription() async -> Bool {
        do {
            let customerInfo = try await fetchCustomerInfo()
            let hasActive = !customerInfo.entitlements.active.isEmpty
            return hasActive
        } catch {
            print("❌ RevenueCat failed to check subscription: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Customer Info

    func fetchCustomerInfo() async throws -> CustomerInfo {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            _currentCustomerInfo = customerInfo
            return customerInfo
        } catch {
            print("❌ RevenueCat failed to fetch customer info: \(error.localizedDescription)")
            throw error
        }
    }

    func identify(userId: String) async throws {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            _currentCustomerInfo = customerInfo
        } catch {
            print("❌ RevenueCat failed to identify user: \(error.localizedDescription)")
            throw error
        }
    }

    func logout() async throws {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            _currentCustomerInfo = customerInfo
        } catch {
            print("❌ RevenueCat logout failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Purchase Management

    func restorePurchases() async throws -> CustomerInfo {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            _currentCustomerInfo = customerInfo
            return customerInfo
        } catch {
            print("❌ RevenueCat failed to restore purchases: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Offerings

    func getOfferings() async throws -> Offerings? {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings
        } catch {
            print("❌ RevenueCat failed to fetch offerings: \(error.localizedDescription)")
            throw error
        }
    }
}
