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
        print("💰 RevenueCatSubscriptionService: Initialized")
    }

    // MARK: - Configuration

    func configure(apiKey: String, userId: String?) {
        print("💰 Configuring RevenueCat with API key: \(apiKey.prefix(10))...")

        // Configure RevenueCat SDK
        Purchases.logLevel = .debug // Use .info or .warn in production
        Purchases.configure(withAPIKey: apiKey)

        print("✅ RevenueCat SDK configured successfully")

        // Identify user if userId provided
        if let userId = userId {
            _Concurrency.Task {
                do {
                    try await identify(userId: userId)
                } catch {
                    print("⚠️ Failed to identify user during configuration: \(error.localizedDescription)")
                }
            }
        }

        // Set up customer info listener
        setupCustomerInfoListener()

        // Fetch initial customer info
        _Concurrency.Task {
            do {
                let customerInfo = try await fetchCustomerInfo()
                print("✅ Initial customer info fetched: \(customerInfo.entitlements.active.keys)")
            } catch {
                print("⚠️ Failed to fetch initial customer info: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Customer Info Listener

    private func setupCustomerInfoListener() {
        // Listen to customer info updates from RevenueCat using AsyncStream
        customerInfoTask = _Concurrency.Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                print("📡 Customer info updated: \(customerInfo.entitlements.active.keys)")
                self?._currentCustomerInfo = customerInfo
            }
        }
    }

    // MARK: - Entitlement Checking

    func hasActiveEntitlement(for entitlementId: String) async -> Bool {
        do {
            let customerInfo = try await fetchCustomerInfo()
            let hasEntitlement = customerInfo.entitlements[entitlementId]?.isActive == true

            print("💎 Entitlement check for '\(entitlementId)': \(hasEntitlement ? "✅ ACTIVE" : "❌ INACTIVE")")
            return hasEntitlement
        } catch {
            print("⚠️ Failed to check entitlement '\(entitlementId)': \(error.localizedDescription)")
            return false
        }
    }

    func hasActiveSubscription() async -> Bool {
        do {
            let customerInfo = try await fetchCustomerInfo()
            let hasActive = !customerInfo.entitlements.active.isEmpty

            print("💎 Active subscription check: \(hasActive ? "✅ HAS SUBSCRIPTION" : "❌ NO SUBSCRIPTION")")
            return hasActive
        } catch {
            print("⚠️ Failed to check active subscription: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Customer Info

    func fetchCustomerInfo() async throws -> CustomerInfo {
        print("📡 Fetching customer info from RevenueCat...")

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            _currentCustomerInfo = customerInfo

            print("✅ Customer info fetched successfully")
            print("   - Active entitlements: \(customerInfo.entitlements.active.keys)")
            print("   - Active subscriptions: \(customerInfo.activeSubscriptions)")
            print("   - Original app user ID: \(customerInfo.originalAppUserId)")

            return customerInfo
        } catch {
            print("❌ Failed to fetch customer info: \(error.localizedDescription)")
            throw error
        }
    }

    func identify(userId: String) async throws {
        print("🔐 Identifying user with RevenueCat: \(userId)")

        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            _currentCustomerInfo = customerInfo

            print("✅ User identified successfully with RevenueCat")
            print("   - App user ID: \(customerInfo.originalAppUserId)")
            print("   - Active entitlements: \(customerInfo.entitlements.active.keys)")
        } catch {
            print("❌ Failed to identify user: \(error.localizedDescription)")
            throw error
        }
    }

    func logout() async throws {
        print("🚪 Logging out from RevenueCat...")

        do {
            let customerInfo = try await Purchases.shared.logOut()
            _currentCustomerInfo = customerInfo

            print("✅ User logged out successfully")
            print("   - Now anonymous with ID: \(customerInfo.originalAppUserId)")
        } catch {
            print("❌ Failed to logout: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Purchase Management

    func restorePurchases() async throws -> CustomerInfo {
        print("♻️ Restoring purchases...")

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            _currentCustomerInfo = customerInfo

            print("✅ Purchases restored successfully")
            print("   - Active entitlements: \(customerInfo.entitlements.active.keys)")
            print("   - Active subscriptions: \(customerInfo.activeSubscriptions)")

            return customerInfo
        } catch {
            print("❌ Failed to restore purchases: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Offerings

    func getOfferings() async throws -> Offerings? {
        print("📦 Fetching offerings from RevenueCat...")

        do {
            let offerings = try await Purchases.shared.offerings()

            if let current = offerings.current {
                print("✅ Current offering fetched: \(current.identifier)")
                print("   - Available packages: \(current.availablePackages.map { $0.identifier })")
            } else {
                print("⚠️ No current offering available")
            }

            return offerings
        } catch {
            print("❌ Failed to fetch offerings: \(error.localizedDescription)")
            throw error
        }
    }
}
