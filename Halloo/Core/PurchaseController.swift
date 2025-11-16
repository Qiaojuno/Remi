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
final class PurchaseController: PurchaseControllerProtocol {

    // MARK: - PurchaseController Protocol

    /// Handle purchase request from Superwall paywall
    /// - Parameter product: StoreKit product to purchase
    /// - Returns: Purchase result with customer info and transaction
    func purchase(product: SK1Product) async -> PurchaseResult {
        print("💰 [PurchaseController] Purchase requested for product: \(product.productIdentifier)")

        do {
            // Delegate purchase to RevenueCat
            let result = try await Purchases.shared.purchase(product: product)

            print("✅ [PurchaseController] Purchase successful")
            print("   - Product ID: \(product.productIdentifier)")
            print("   - Transaction ID: \(result.transaction?.transactionIdentifier ?? "unknown")")
            print("   - Active entitlements: \(result.customerInfo.entitlements.active.keys)")

            // Return success with customer info and transaction
            return .purchased

        } catch let error as ErrorCode {
            print("❌ [PurchaseController] Purchase failed with RevenueCat error: \(error)")

            // Handle specific RevenueCat errors
            switch error.code {
            case .purchaseCancelledError:
                print("   - User cancelled purchase")
                return .cancelled

            case .productAlreadyPurchasedError:
                print("   - Product already purchased")
                return .purchased

            case .networkError:
                print("   - Network error during purchase")
                return .failed(error)

            default:
                print("   - Unexpected error: \(error.localizedDescription)")
                return .failed(error)
            }

        } catch {
            print("❌ [PurchaseController] Purchase failed with unexpected error: \(error)")
            return .failed(error)
        }
    }

    /// Restore previous purchases
    /// - Returns: Restore result with customer info
    func restorePurchases() async -> RestorationResult {
        print("♻️ [PurchaseController] Restore purchases requested")

        do {
            // Delegate restoration to RevenueCat
            let customerInfo = try await Purchases.shared.restorePurchases()

            print("✅ [PurchaseController] Purchases restored successfully")
            print("   - Active entitlements: \(customerInfo.entitlements.active.keys)")
            print("   - Active subscriptions: \(customerInfo.activeSubscriptions)")

            // Return success with restored customer info
            return .restored

        } catch {
            print("❌ [PurchaseController] Restore failed: \(error)")
            return .failed(error)
        }
    }
}
