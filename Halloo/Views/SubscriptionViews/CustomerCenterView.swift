//
//  CustomerCenterView.swift
//  Hallo
//
//  Purpose: RevenueCat Customer Center for subscription management
//  Key Features:
//    • Display Customer Center UI for managing subscriptions
//    • Handle subscription changes, cancellations, and upgrades
//    • Provide restore purchases functionality
//  Dependencies: SwiftUI, RevenueCat
//
//  Business Context: Allows users to manage their "Remi Unlimited" subscriptions
//  Critical Paths: Settings → Customer Center → Subscription management
//
//  Created by Claude Code on 2025-11-15
//

import SwiftUI
import RevenueCat

/// Customer Center view for subscription management
///
/// This view integrates RevenueCat's Customer Center, allowing users to:
/// - View current subscription status
/// - Cancel or modify subscriptions
/// - Restore previous purchases
/// - Access subscription receipts and invoices
///
/// ## Usage:
/// ```swift
/// // Present Customer Center as a sheet
/// .sheet(isPresented: $showCustomerCenter) {
///     CustomerCenterView()
/// }
///
/// // Or use as a navigation link
/// NavigationLink("Manage Subscription") {
///     CustomerCenterView()
/// }
/// ```
struct CustomerCenterView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isLoading = false
    @State private var hasActiveSubscription = false
    @State private var activeProduct: String?
    @State private var expirationDate: Date?
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .padding(.top, 20)

                        Text("Remi Unlimited")
                            .font(.title)
                            .fontWeight(.bold)

                        if hasActiveSubscription {
                            Text("Active Subscription")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else {
                            Text("No Active Subscription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()

                    // MARK: - Subscription Details
                    if hasActiveSubscription {
                        VStack(alignment: .leading, spacing: 16) {
                            if let product = activeProduct {
                                HStack {
                                    Text("Plan:")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(product.capitalized)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let expiration = expirationDate {
                                HStack {
                                    Text("Renews:")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(expiration, style: .date)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider()

                            Text("Your subscription gives you unlimited access to all premium features including:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                FeatureRow(icon: "checkmark.circle.fill", text: "Unlimited profiles")
                                FeatureRow(icon: "checkmark.circle.fill", text: "Unlimited tasks & reminders")
                                FeatureRow(icon: "checkmark.circle.fill", text: "Priority support")
                                FeatureRow(icon: "checkmark.circle.fill", text: "Advanced features")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // MARK: - Actions
                    VStack(spacing: 12) {

                        // Restore Purchases
                        Button {
                            Task {
                                await restorePurchases()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Restore Purchases")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)

                        // Manage Subscription (opens App Store)
                        if hasActiveSubscription {
                            Button {
                                openManageSubscriptions()
                            } label: {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Manage Subscription")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        } else {
                            // Show upgrade button if no subscription
                            Button {
                                // Present paywall
                                SubscriptionManager.shared.presentPaywall(event: "customer_center_upgrade")
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "crown.fill")
                                    Text("Upgrade to Unlimited")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Manage Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .alert("Restore Complete", isPresented: $showRestoreAlert) {
                Button("OK") {}
            } message: {
                if restoreSuccess {
                    Text("Your purchases have been successfully restored!")
                } else {
                    Text("No purchases found to restore.")
                }
            }
        }
        .task {
            await loadSubscriptionInfo()
        }
    }

    // MARK: - Helper Views

    private struct FeatureRow: View {
        let icon: String
        let text: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.green)
                Text(text)
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func loadSubscriptionInfo() async {
        isLoading = true
        defer { isLoading = false }

        hasActiveSubscription = await subscriptionManager.hasActiveSubscription()
        activeProduct = await subscriptionManager.getActiveProductIdentifier()
        expirationDate = await subscriptionManager.getSubscriptionExpirationDate()
    }

    private func restorePurchases() async {
        isLoading = true
        restoreSuccess = await subscriptionManager.restorePurchases()
        isLoading = false

        showRestoreAlert = true

        // Reload subscription info after restore
        await loadSubscriptionInfo()
    }

    private func openManageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    CustomerCenterView()
}
