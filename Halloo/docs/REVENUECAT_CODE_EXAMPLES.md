# RevenueCat Integration - Practical Code Examples

Ready-to-use code snippets for integrating RevenueCat subscriptions into your Remi app.

## Quick Start Examples

### 1. Add Subscription Gate to Existing Feature

**Scenario**: Limit users to 3 profiles unless they have "Remi Unlimited"

```swift
// In ProfileViewModel.swift
@Published var hasUnlimitedAccess = false

func createProfile(name: String) async throws {
    // Check if user has reached limit
    if profiles.count >= 3 && !hasUnlimitedAccess {
        // Show paywall
        await MainActor.run {
            SubscriptionManager.shared.presentPaywall(event: "profile_limit")
        }
        throw ProfileError.subscriptionRequired
    }

    // Create profile...
}

// Load subscription status on init
init(...) {
    // ...existing code...

    Task {
        hasUnlimitedAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
    }
}
```

### 2. Add Customer Center to Settings

**In your Settings/Profile view:**

```swift
struct SettingsView: View {
    @State private var showCustomerCenter = false
    @State private var hasActiveSubscription = false

    var body: some View {
        List {
            Section("Subscription") {
                if hasActiveSubscription {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Remi Unlimited")
                        Spacer()
                        Text("Active")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    Button("Manage Subscription") {
                        showCustomerCenter = true
                    }
                } else {
                    Button {
                        SubscriptionManager.shared.presentPaywall(event: "settings_upgrade")
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Upgrade to Unlimited")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button("Restore Purchases") {
                    Task {
                        await restorePurchases()
                    }
                }
            }
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
        .task {
            hasActiveSubscription = await SubscriptionManager.shared.hasActiveSubscription()
        }
    }

    private func restorePurchases() async {
        let success = await SubscriptionManager.shared.restorePurchases()
        // Show alert with result
    }
}
```

### 3. Update User Identification on Login

**In OnboardingViewModel or AuthService:**

```swift
func signIn(email: String, password: String) async throws {
    // Existing sign-in logic
    let authResult = try await authService.signIn(email: email, password: password)

    // ✨ NEW: Link RevenueCat customer to user ID
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    do {
        try await subscriptionService.identify(userId: authResult.uid)
        print("✅ User identified with RevenueCat")
    } catch {
        print("⚠️ Failed to identify user with RevenueCat: \(error)")
        // Don't block login on subscription service errors
    }
}

func signOut() async throws {
    // ✨ NEW: Logout from RevenueCat before signing out
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    try? await subscriptionService.logout()

    // Existing sign-out logic
    try await authService.signOut()
}
```

### 4. Add Subscription Status to Dashboard

**In DashboardView:**

```swift
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var hasUnlimitedAccess = false

    var body: some View {
        ScrollView {
            VStack {
                // Subscription status banner (if not subscribed)
                if !hasUnlimitedAccess {
                    UpgradeBanner()
                }

                // Existing dashboard content
                ProfilesSection()
                TasksSection()
                GallerySection()
            }
        }
        .task {
            hasUnlimitedAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
        }
    }
}

struct UpgradeBanner: View {
    var body: some View {
        Button {
            SubscriptionManager.shared.presentPaywall(event: "dashboard_banner")
        } label: {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Unlimited Access")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Get unlimited profiles, tasks & more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
```

### 5. Reactive Subscription Status (Advanced)

**Create a SubscriptionViewModel:**

```swift
import SwiftUI
import Combine
import RevenueCat

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var hasUnlimitedAccess = false
    @Published var activeProductId: String?
    @Published var expirationDate: Date?
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()
    private let subscriptionService: SubscriptionServiceProtocol

    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
        setupSubscriptionListener()
        Task { await refreshSubscriptionStatus() }
    }

    private func setupSubscriptionListener() {
        // Listen to customer info changes
        subscriptionService.customerInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] customerInfo in
                guard let self = self, let info = customerInfo else { return }

                self.hasUnlimitedAccess = info.entitlements["Remi Unlimited"]?.isActive == true
                self.activeProductId = info.activeSubscriptions.first
                self.expirationDate = info.entitlements.active.values.first?.expirationDate
            }
            .store(in: &cancellables)
    }

    func refreshSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await subscriptionService.fetchCustomerInfo()
        } catch {
            print("⚠️ Failed to refresh subscription: \(error)")
        }
    }

    func presentPaywall(event: String) {
        SubscriptionManager.shared.presentPaywall(event: event)
    }
}

// Usage in Views:
struct MyView: View {
    @StateObject private var subscriptionVM: SubscriptionViewModel

    init(container: Container) {
        let service = container.resolve(SubscriptionServiceProtocol.self)
        _subscriptionVM = StateObject(wrappedValue: SubscriptionViewModel(subscriptionService: service))
    }

    var body: some View {
        VStack {
            if subscriptionVM.hasUnlimitedAccess {
                Text("Premium Active")
            } else {
                Button("Upgrade") {
                    subscriptionVM.presentPaywall(event: "feature_access")
                }
            }
        }
    }
}
```

### 6. Feature-Specific Entitlement Checks

```swift
// In TaskViewModel.swift
func createTask(task: Task) async throws {
    // Check subscription for premium task features
    let hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()

    // Free tier: limit to 10 tasks per profile
    if !hasAccess && tasksForProfile.count >= 10 {
        await MainActor.run {
            SubscriptionManager.shared.presentPaywall(event: "task_limit")
        }
        throw TaskError.limitReached
    }

    // Create task...
}

// In GalleryViewModel.swift
func uploadPhoto() async throws {
    let hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()

    // Free tier: limit to 50 photos
    if !hasAccess && totalPhotos >= 50 {
        await MainActor.run {
            SubscriptionManager.shared.presentPaywall(event: "photo_limit")
        }
        throw GalleryError.limitReached
    }

    // Upload photo...
}
```

### 7. Subscription Banner Component (Reusable)

```swift
struct SubscriptionBannerView: View {
    let event: String
    let title: String
    let subtitle: String

    var body: some View {
        Button {
            SubscriptionManager.shared.presentPaywall(event: event)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Upgrade")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// Usage:
SubscriptionBannerView(
    event: "premium_feature",
    title: "Unlock Unlimited Profiles",
    subtitle: "Create as many profiles as you need"
)
```

### 8. Check Subscription in ViewModels

```swift
// Pattern for ViewModels
class MyFeatureViewModel: ObservableObject {
    @Published var hasUnlimitedAccess = false
    private let subscriptionService: SubscriptionServiceProtocol

    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService

        // Load subscription status
        Task {
            await checkSubscription()
        }
    }

    @MainActor
    func checkSubscription() async {
        hasUnlimitedAccess = await subscriptionService.hasActiveEntitlement(for: "Remi Unlimited")
    }

    func performPremiumAction() async {
        guard hasUnlimitedAccess else {
            // Show paywall
            await MainActor.run {
                SubscriptionManager.shared.presentPaywall(event: "premium_action")
            }
            return
        }

        // Perform action...
    }
}
```

---

## Common Patterns

### Pattern 1: Subscription Gate with Alert

```swift
@State private var showSubscriptionRequired = false

Button("Premium Feature") {
    Task {
        let hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()

        if !hasAccess {
            showSubscriptionRequired = true
        } else {
            // Access feature
        }
    }
}
.alert("Subscription Required", isPresented: $showSubscriptionRequired) {
    Button("Upgrade Now") {
        SubscriptionManager.shared.presentPaywall(event: "alert_upgrade")
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("This feature requires Remi Unlimited subscription.")
}
```

### Pattern 2: Conditional View Rendering

```swift
struct FeatureView: View {
    @State private var hasAccess = false

    var body: some View {
        Group {
            if hasAccess {
                PremiumContentView()
            } else {
                LockedContentView {
                    SubscriptionManager.shared.presentPaywall(event: "locked_content")
                }
            }
        }
        .task {
            hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
        }
    }
}
```

### Pattern 3: Environment-Based Subscription Check

```swift
// Create environment key
private struct HasSubscriptionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hasSubscription: Bool {
        get { self[HasSubscriptionKey.self] }
        set { self[HasSubscriptionKey.self] = newValue }
    }
}

// Set in root view
struct RootView: View {
    @State private var hasSubscription = false

    var body: some View {
        ContentView()
            .environment(\.hasSubscription, hasSubscription)
            .task {
                hasSubscription = await SubscriptionManager.shared.hasUnlimitedAccess()
            }
    }
}

// Use in child views
struct ChildView: View {
    @Environment(\.hasSubscription) private var hasSubscription

    var body: some View {
        if hasSubscription {
            Text("Premium Feature")
        }
    }
}
```

---

## Testing Tips

```swift
#if DEBUG
// For testing subscription flows

// Test with subscription active
Purchases.shared.customerInfoStream.send(mockCustomerInfoWithSubscription)

// Test with no subscription
Purchases.shared.customerInfoStream.send(mockCustomerInfoWithoutSubscription)

// Mock customer info
extension CustomerInfo {
    static var mockWithSubscription: CustomerInfo {
        // Create mock CustomerInfo with active entitlement
        // (Requires creating test data)
    }
}
#endif
```

---

**Next Steps**:
1. Configure products (`monthly`, `yearly`) in RevenueCat dashboard
2. Configure paywalls and events in Superwall dashboard
3. Add subscription checks to your existing features
4. Test purchase flow in sandbox mode
5. Add Customer Center to settings/profile screen

---

**Need Help?** See `REVENUECAT_INTEGRATION_GUIDE.md` for full documentation.
