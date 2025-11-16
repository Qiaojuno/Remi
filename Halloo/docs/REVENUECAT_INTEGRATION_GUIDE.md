# RevenueCat + Superwall Integration Guide

Complete integration guide for RevenueCat subscription management with Superwall paywalls in the Remi app.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Configuration](#configuration)
4. [Usage Examples](#usage-examples)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

---

## Overview

### What's Integrated

- **RevenueCat SDK** (v5.48.0): Subscription management, purchase processing, receipt validation
- **Superwall SDK** (v4.7.0): Paywall UI presentation, A/B testing, analytics
- **API Key**: `test_JxDSDtqZjJxdAqlujuzvhPtVHSO` (test mode)
- **Entitlement**: `Remi Unlimited` (premium access)
- **Products**: `monthly` and `yearly` subscriptions

### How It Works

```
User Action → Entitlement Check → (No Access) → Superwall Paywall
                ↓                                        ↓
          (Has Access)                          User Purchases
                ↓                                        ↓
         Premium Feature                    RevenueCat Processing
                                                        ↓
                                              Subscription Active
```

---

## Architecture

### Service Layer

```
SubscriptionServiceProtocol
    ↓
RevenueCatSubscriptionService (Singleton)
    ↓
Container DI Registration
    ↓
App.swift Configuration
```

### Key Files

| File | Purpose |
|------|---------|
| `Services/SubscriptionServiceProtocol.swift` | Service contract |
| `Services/RevenueCatSubscriptionService.swift` | RevenueCat implementation |
| `Core/PurchaseController.swift` | Superwall ↔ RevenueCat bridge |
| `Utilities/SubscriptionManager.swift` | High-level helpers |
| `Views/SubscriptionViews/CustomerCenterView.swift` | Subscription management UI |
| `Core/App.swift` | SDK configuration |
| `Models/Container.swift` | DI registration |

---

## Configuration

### 1. SDK Initialization (App.swift)

```swift
// Configured in HalloApp.init()
configureRevenueCat()  // Must run before configureSuperwall()
configureSuperwall()   // Integrates with RevenueCat
```

### 2. RevenueCat Setup

```swift
private func configureRevenueCat() {
    let REVENUECAT_API_KEY = "test_JxDSDtqZjJxdAqlujuzvhPtVHSO"
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    let userId = authService.currentUser?.uid  // Optional

    subscriptionService.configure(apiKey: REVENUECAT_API_KEY, userId: userId)
}
```

### 3. Superwall Integration

```swift
private func configureSuperwall() {
    let SUPERWALL_API_KEY = "pk_1FZVcGgpr1JMD5XJ4d0Cb"

    Superwall.configure(
        apiKey: SUPERWALL_API_KEY,
        purchaseController: PurchaseController()  // 👈 RevenueCat integration
    )
}
```

---

## Usage Examples

### ✅ Example 1: Check Entitlement Before Feature Access

```swift
import SwiftUI

struct PremiumFeatureView: View {
    @State private var hasAccess = false
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Checking access...")
            } else if hasAccess {
                // Show premium feature
                Text("Welcome to Premium!")
            } else {
                // Show upgrade button
                Button("Unlock Premium") {
                    SubscriptionManager.shared.presentPaywall(event: "premium_feature")
                }
            }
        }
        .task {
            hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
            isLoading = false
        }
    }
}
```

### ✅ Example 2: Conditional Feature Access

```swift
struct DashboardView: View {
    @State private var hasUnlimitedAccess = false

    var body: some View {
        VStack {
            // Free features
            BasicStatsView()

            // Premium features (gated)
            if hasUnlimitedAccess {
                AdvancedAnalyticsView()
                UnlimitedProfilesView()
            } else {
                Button("Unlock Advanced Features") {
                    SubscriptionManager.shared.presentPaywall(event: "advanced_features")
                }
            }
        }
        .task {
            hasUnlimitedAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
        }
    }
}
```

### ✅ Example 3: Present Paywall on Tap

```swift
Button("Create 4th Profile") {
    Task {
        let hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()

        if hasAccess {
            // Allow profile creation
            createProfile()
        } else {
            // Show paywall
            SubscriptionManager.shared.presentPaywall(event: "profile_limit")
        }
    }
}
```

### ✅ Example 4: Show Customer Center

```swift
struct SettingsView: View {
    @State private var showCustomerCenter = false

    var body: some View {
        List {
            Section("Subscription") {
                Button("Manage Subscription") {
                    showCustomerCenter = true
                }
            }
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
    }
}
```

### ✅ Example 5: Using SubscriptionService Directly

```swift
@EnvironmentObject var container: Container

func checkSubscription() async {
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)

    // Method 1: Check specific entitlement
    let hasUnlimited = await subscriptionService.hasActiveEntitlement(for: "Remi Unlimited")

    // Method 2: Check any active subscription
    let hasAnySubscription = await subscriptionService.hasActiveSubscription()

    // Method 3: Get full customer info
    if let customerInfo = try? await subscriptionService.fetchCustomerInfo() {
        print("Active entitlements: \(customerInfo.entitlements.active.keys)")
        print("Active subscriptions: \(customerInfo.activeSubscriptions)")
    }
}
```

### ✅ Example 6: Listen to Subscription Changes

```swift
import Combine

class MyViewModel: ObservableObject {
    @Published var hasUnlimitedAccess = false
    private var cancellables = Set<AnyCancellable>()
    private let subscriptionService: SubscriptionServiceProtocol

    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService

        // Listen to customer info updates
        subscriptionService.customerInfoPublisher
            .sink { [weak self] customerInfo in
                self?.hasUnlimitedAccess = customerInfo?.entitlements["Remi Unlimited"]?.isActive == true
            }
            .store(in: &cancellables)
    }
}
```

### ✅ Example 7: Restore Purchases

```swift
Button("Restore Purchases") {
    Task {
        let success = await SubscriptionManager.shared.restorePurchases()

        if success {
            showAlert("Purchases restored successfully!")
        } else {
            showAlert("No purchases found to restore.")
        }
    }
}
```

---

## Best Practices

### 🎯 When to Check Entitlements

```swift
// ✅ GOOD: Check on view appear
.task {
    hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
}

// ✅ GOOD: Check before premium action
func createPremiumTask() async {
    guard await SubscriptionManager.shared.hasUnlimitedAccess() else {
        SubscriptionManager.shared.presentPaywall(event: "premium_task")
        return
    }
    // Create task...
}

// ❌ BAD: Don't check synchronously
let hasAccess = SubscriptionManager.shared.hasUnlimitedAccess()  // Won't compile
```

### 🎯 User Identification

```swift
// Identify user after authentication
func signIn(email: String, password: String) async throws {
    let result = try await authService.signIn(email: email, password: password)

    // Link RevenueCat customer to user ID
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    try? await subscriptionService.identify(userId: result.uid)
}

// Logout from RevenueCat when user signs out
func signOut() async throws {
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    try? await subscriptionService.logout()

    try await authService.signOut()
}
```

### 🎯 Superwall Event Naming

Configure events in Superwall Dashboard:
- `premium_feature` - Generic premium access
- `profile_limit` - User hits profile creation limit
- `advanced_features` - Advanced analytics/features
- `customer_center_upgrade` - From Customer Center view

### 🎯 Error Handling

```swift
do {
    let customerInfo = try await subscriptionService.fetchCustomerInfo()
    print("Customer info: \(customerInfo)")
} catch {
    // Graceful fallback - don't block user
    print("Failed to fetch subscription: \(error)")
    // Show error message or use cached data
}
```

### 🎯 Performance

```swift
// ✅ GOOD: Cache subscription status
@Published var hasUnlimitedAccess = false

func checkSubscription() async {
    hasUnlimitedAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
}

// ❌ BAD: Check on every render
var body: some View {
    // Don't do this - causes repeated network calls
    if await SubscriptionManager.shared.hasUnlimitedAccess() { }
}
```

---

## Troubleshooting

### Issue: Purchases Not Working

**Solution**: Check RevenueCat dashboard:
1. Verify API key is correct (`test_` prefix = sandbox mode)
2. Ensure products (`monthly`, `yearly`) are configured
3. Check entitlement `Remi Unlimited` is linked to products
4. Verify StoreKit configuration in Xcode

### Issue: Superwall Not Showing Paywall

**Solution**:
1. Check Superwall dashboard for paywall configuration
2. Verify event names match dashboard settings
3. Ensure `PurchaseController` is passed to Superwall.configure()
4. Check console logs for Superwall errors

### Issue: Entitlement Not Activating After Purchase

**Solution**:
1. Wait 5-10 seconds for RevenueCat server sync
2. Force refresh: `try await subscriptionService.fetchCustomerInfo()`
3. Check RevenueCat dashboard → Customers → Find user
4. Verify receipt was validated

### Issue: User ID Not Linking

**Solution**:
```swift
// After authentication, identify user
let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
try await subscriptionService.identify(userId: authService.currentUser!.uid)
```

### Debug Logging

Enable verbose logging:
```swift
// In RevenueCatSubscriptionService.configure()
Purchases.logLevel = .debug  // Change to .info in production
```

---

## Production Checklist

Before going live:

- [ ] Replace test API key with production key
- [ ] Configure production products in RevenueCat
- [ ] Set up App Store Connect subscriptions
- [ ] Test purchase flow in sandbox
- [ ] Test restore purchases
- [ ] Verify entitlement activation
- [ ] Set `Purchases.logLevel = .warn` or `.error`
- [ ] Configure Superwall production paywalls
- [ ] Test user identification flow
- [ ] Add privacy policy and terms links to paywall

---

## Support & Resources

- **RevenueCat Docs**: https://www.revenuecat.com/docs
- **Superwall Docs**: https://docs.superwall.com
- **RevenueCat Dashboard**: https://app.revenuecat.com
- **Superwall Dashboard**: https://superwall.com/dashboard

---

**Last Updated**: 2025-11-15
**Integration Version**: RevenueCat v5.48.0 + Superwall v4.7.0
