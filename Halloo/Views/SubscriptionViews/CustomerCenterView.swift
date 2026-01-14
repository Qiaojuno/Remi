//
//  CustomerCenterView.swift
//  Hallo
//
//  Simplified subscription management - links to Apple's subscription settings
//

import SwiftUI
import RevenueCat

struct CustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "creditcard.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Subscription")
                    .font(.title2)
                    .fontWeight(.semibold)

                // Buttons
                VStack(spacing: 12) {
                    // Manage Subscription - opens Apple's settings
                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
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

                    // Restore Purchases
                    Button {
                        _Concurrency.Task {
                            isRestoring = true
                            do {
                                let customerInfo = try await Purchases.shared.restorePurchases()
                                restoreSuccess = !customerInfo.entitlements.active.isEmpty
                            } catch {
                                restoreSuccess = false
                            }
                            isRestoring = false
                            showRestoreAlert = true
                        }
                    } label: {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .tint(.primary)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Restore Purchases")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .disabled(isRestoring)
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Restore Complete", isPresented: $showRestoreAlert) {
                Button("OK") {}
            } message: {
                Text(restoreSuccess
                    ? "Your purchases have been restored!"
                    : "No purchases found to restore.")
            }
        }
    }
}

#Preview {
    CustomerCenterView()
}
