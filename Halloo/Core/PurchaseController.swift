//
//  PurchaseController.swift
//  Hallo
//
//  Purpose: Bridges Superwall paywall presentation with RevenueCat purchase processing
//  Key Features:
//    • Implements SuperwallKit PurchaseController protocol
//    • Delegates all purchases to RevenueCat SDK
//    • Handles subscription state and user ID synchronization
//  Dependencies: Foundation, SuperwallKit, RevenueCat
//
//  Business Context: Enables Superwall to use RevenueCat for purchase processing
//  Critical Paths: Paywall trigger → Purchase request → RevenueCat processing → Subscription activation
//
//  Created by Claude Code on 2025-11-15
//

import Foundation
import SuperwallKit
import RevenueCat

/// Purchase controller that integrates Superwall with RevenueCat
///
/// This class implements the `PurchaseController` protocol from SuperwallKit,
/// allowing Superwall to delegate all purchase operations to RevenueCat.
/// This enables you to use Superwall's advanced paywall UI and A/B testing
/// while RevenueCat handles the actual purchase processing and receipt validation.
///
/// ## Integration Flow:
/// 1. User triggers paywall in Superwall
/// 2. Superwall calls `purchase(product:)` on this controller
/// 3. Controller delegates to RevenueCat's `Purchases.shared.purchase()`
/// 4. RevenueCat processes purchase and updates entitlements
/// 5. Both Superwall and RevenueCat customer info sync automatically
///
/// ## Thread Safety:
/// - All methods are thread-safe and use async/await
/// - RevenueCat SDK handles internal synchronization
final class PurchaseController: SuperwallKit.PurchaseController {

    // MARK: - Subscription Status Sync

    /// Syncs subscription status from RevenueCat to Superwall
    ///
    /// This method listens to RevenueCat's customer info stream and updates
    /// Superwall's subscriptionStatus whenever entitlements change.
    /// MUST be called after both RevenueCat and Superwall are configured.
    ///
    /// Without this, Superwall will timeout waiting for subscription status
    /// and fail to present paywalls properly.
    func syncSubscriptionStatus() {
        guard Purchases.isConfigured else {
            print("⚠️ [PurchaseController] RevenueCat not configured yet, skipping subscription sync")
            return
        }

        _Concurrency.Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                // Extract active entitlement IDs
                let superwallEntitlements = customerInfo.entitlements.activeInCurrentEnvironment.keys.map {
                    Entitlement(id: $0)
                }

                await MainActor.run { [superwallEntitlements] in
                    if superwallEntitlements.isEmpty {
                        Superwall.shared.subscriptionStatus = .inactive
                        print("🔄 [PurchaseController] Superwall subscription status set to: inactive")
                    } else {
                        Superwall.shared.subscriptionStatus = .active(Set(superwallEntitlements))
                        print("🔄 [PurchaseController] Superwall subscription status set to: active(\(superwallEntitlements.map { $0.id }))")
                    }
                }
            }
        }
    }

    // MARK: - PurchaseController Protocol

    /// Handle purchase request from Superwall paywall
    /// - Parameter product: StoreKit product to purchase
    /// - Returns: Purchase result with customer info and transaction
    func purchase(product: SuperwallKit.StoreProduct) async -> SuperwallKit.PurchaseResult {
        do {
            // Convert Superwall StoreProduct to RevenueCat StoreProduct
            // RevenueCat requires StoreKit 2 products
            guard let sk2Product = product.sk2Product else {
                return .failed(NSError(domain: "PurchaseController", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "StoreKit 2 product required"]))
            }

            let storeProduct = RevenueCat.StoreProduct(sk2Product: sk2Product)
            let result = try await Purchases.shared.purchase(product: storeProduct)

            // Check if user cancelled
            if result.userCancelled {
                return .cancelled
            }

            // SECURITY: Sync subscription status to Firestore after successful purchase
            // This ensures Cloud Functions can immediately validate subscription for SMS
            await MainActor.run {
                SubscriptionManager.shared.handleCustomerInfoUpdate(result.customerInfo)
            }

            return .purchased

        } catch let error as ErrorCode {
            if error == .paymentPendingError {
                return .pending
            } else {
                return .failed(error)
            }

        } catch {
            return .failed(error)
        }
    }

    /// Restore previous purchases
    /// - Returns: Restore result with customer info
    func restorePurchases() async -> SuperwallKit.RestorationResult {
        do {
            // Delegate restoration to RevenueCat
            let customerInfo = try await Purchases.shared.restorePurchases()

            // SECURITY: Sync subscription status to Firestore after restore
            await MainActor.run {
                SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo)
            }

            // Return success with restored customer info
            return .restored

        } catch {
            return .failed(error)
        }
    }
}
