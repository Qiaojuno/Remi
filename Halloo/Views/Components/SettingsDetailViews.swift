import SwiftUI
import SuperwallKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Notifications Settings View
struct NotificationsSettingsView: View {
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation
    @EnvironmentObject private var appState: AppState

    @State private var noReplyAlertsEnabled = true
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button(action: {
                    HapticFeedback.light()
                    dismissWithoutAnimation?()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.leading, 20)

                Spacer()

                Text("Notifications")
                    .font(.custom("Poppins-Medium", size: 20))
                    .foregroundColor(.black)

                Spacer()

                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .opacity(0)
                    .padding(.trailing, 20)
            }
            .frame(height: 60)
            .background(Color(hex: "f9f9f9"))

            ScrollView {
                VStack(spacing: 20) {
                    // Single notification toggle
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No-Reply Alerts")
                                    .font(.custom("Poppins-Regular", size: 15))
                                    .foregroundColor(.black)

                                Text("Get notified when loved ones don't respond within 30 minutes")
                                    .font(.custom("Poppins-Regular", size: 13))
                                    .foregroundColor(Color(hex: "7A7A7A"))
                            }

                            Spacer()

                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Toggle("", isOn: $noReplyAlertsEnabled)
                                    .labelsHidden()
                                    .disabled(isSaving)
                                    .onChange(of: noReplyAlertsEnabled) { _, newValue in
                                        savePreference(enabled: newValue)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Info text
                    Text("When enabled, you'll receive a push notification if your loved one hasn't responded to a reminder within 30 minutes.")
                        .font(.custom("Poppins-Regular", size: 13))
                        .foregroundColor(Color(hex: "7A7A7A"))
                        .padding(.horizontal, 30)
                }
            }
        }
        .background(Color(hex: "f9f9f9"))
        .onAppear {
            loadPreference()
        }
    }

    // MARK: - Firestore Operations

    private func loadPreference() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        Firestore.firestore()
            .collection("users")
            .document(userId)
            .getDocument { snapshot, error in
                DispatchQueue.main.async {
                    if let data = snapshot?.data(),
                       let enabled = data["pushNotificationsEnabled"] as? Bool {
                        noReplyAlertsEnabled = enabled
                    } else {
                        // Default to true if field doesn't exist
                        noReplyAlertsEnabled = true
                    }
                    isLoading = false
                }
            }
    }

    private func savePreference(enabled: Bool) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isSaving = true

        Firestore.firestore()
            .collection("users")
            .document(userId)
            .updateData([
                "pushNotificationsEnabled": enabled,
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        print("❌ Failed to save push notification preference: \(error.localizedDescription)")
                        // Revert toggle on failure
                        noReplyAlertsEnabled = !enabled
                    } else {
                        print("✅ Push notification preference saved: \(enabled)")
                    }
                }
            }
    }
}

// MARK: - Manage Subscription View
struct ManageSubscriptionView: View {
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation

    var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button(action: {
                    HapticFeedback.light()
                    dismissWithoutAnimation?()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.leading, 20)

                Spacer()

                Text("Manage Subscription")
                    .font(.custom("Poppins-Medium", size: 20))
                    .foregroundColor(.black)

                Spacer()

                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .opacity(0)
                    .padding(.trailing, 20)
            }
            .frame(height: 60)
            .background(Color(hex: "f9f9f9"))

            ScrollView {
                VStack(spacing: 30) {
                    // Icon
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "B9E3FF"))
                        .padding(.top, 60)

                    VStack(spacing: 12) {
                        Text("Premium Subscription")
                            .font(.custom("Poppins-Medium", size: 24))
                            .foregroundColor(.black)

                        Text("View and manage your Remi subscription")
                            .font(.custom("Poppins-Regular", size: 15))
                            .foregroundColor(Color(hex: "7A7A7A"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    // Subscription details card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Plan")
                                    .font(.custom("Poppins-Medium", size: 15))
                                    .foregroundColor(.black)

                                Text("Premium - Monthly")
                                    .font(.custom("Poppins-Regular", size: 13))
                                    .foregroundColor(Color(hex: "7A7A7A"))
                            }

                            Spacer()

                            Text("$9.99/mo")
                                .font(.custom("Poppins-Medium", size: 17))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // Action button
                    Button(action: {
                        // Open Superwall subscription management
                        Superwall.shared.getPresentationResult(forPlacement: "manage_subscription") { result in
                            // Handle result
                        }
                    }) {
                        Text("View Subscription Options")
                            .font(.custom("Poppins-Medium", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
        }
        .background(Color(hex: "f9f9f9"))
    }
}

// MARK: - FAQs View
struct FAQsView: View {
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation

    private let faqs: [(question: String, answer: String)] = [
        (
            question: "How do SMS reminders work?",
            answer: "Remi sends automated SMS reminders to your loved ones at scheduled times. They can respond with a photo or text to confirm completion."
        ),
        (
            question: "How many family members can I add?",
            answer: "You can add up to 4 elderly family members to your account, each with their own set of reminders and habits."
        ),
        (
            question: "How many habits can I create?",
            answer: "You can create up to 10 habits per family member, covering medication, exercise, meals, and more."
        ),
        (
            question: "What happens if they don't respond?",
            answer: "If your loved one doesn't respond to a reminder, you'll receive a notification so you can follow up with them directly."
        ),
        (
            question: "Can I customize reminder times?",
            answer: "Yes! You can set custom times for each habit, choose specific days of the week, or set up daily reminders."
        ),
        (
            question: "How long are photos kept?",
            answer: "All photos are stored securely in Firebase Storage and are accessible indefinitely through the Gallery."
        ),
        (
            question: "Can I use this without SMS?",
            answer: "SMS is required for sending reminders to your loved ones, but you can also receive app notifications."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button(action: {
                    HapticFeedback.light()
                    dismissWithoutAnimation?()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.leading, 20)

                Spacer()

                Text("FAQs")
                        .font(.custom("Poppins-Medium", size: 20))
                        .foregroundColor(.black)

                    Spacer()

                    // Invisible spacer for centering
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .opacity(0)
                        .padding(.trailing, 20)
                }
                .frame(height: 60)
                .background(Color(hex: "f9f9f9"))

                ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(faq.question)
                                .font(.custom("Poppins-Medium", size: 15))
                                .foregroundColor(.black)

                            Text(faq.answer)
                                .font(.custom("Poppins-Regular", size: 14))
                                .foregroundColor(Color(hex: "7A7A7A"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "f9f9f9"))
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation
    @State private var feedbackText = ""
    @State private var feedbackType: FeedbackType = .suggestion
    @State private var showingThankYou = false

    enum FeedbackType: String, CaseIterable {
        case bug = "Bug"
        case suggestion = "Idea"
        case compliment = "Love"
        case other = "Other"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button(action: {
                    HapticFeedback.light()
                    dismissWithoutAnimation?()
                }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .padding(.leading, 20)

                    Spacer()

                    Text("Give Feedback")
                        .font(.custom("Poppins-Medium", size: 20))
                        .foregroundColor(.black)

                    Spacer()

                    // Invisible spacer for centering
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .opacity(0)
                        .padding(.trailing, 20)
                }
                .frame(height: 60)
                .background(Color(hex: "f9f9f9"))

                ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("We'd love to hear from you!")
                            .font(.custom("Poppins-Medium", size: 20))
                            .foregroundColor(.black)

                        Text("Your feedback helps us improve Remi for everyone.")
                            .font(.custom("Poppins-Regular", size: 15))
                            .foregroundColor(Color(hex: "7A7A7A"))
                    }

                    // Feedback type picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type of Feedback")
                            .font(.custom("Poppins-Medium", size: 15))
                            .foregroundColor(.black)

                        Picker("Feedback Type", selection: $feedbackType) {
                            ForEach(FeedbackType.allCases, id: \.self) { type in
                                Text(type.rawValue)
                                    .font(.custom("Poppins-Regular", size: 14))
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)

                    // Feedback text area
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Feedback")
                            .font(.custom("Poppins-Medium", size: 15))
                            .foregroundColor(.black)

                        ZStack(alignment: .topLeading) {
                            if feedbackText.isEmpty {
                                Text("Tell us what you think...")
                                    .font(.custom("Poppins-Regular", size: 15))
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                            }

                            TextEditor(text: $feedbackText)
                                .font(.custom("Poppins-Regular", size: 15))
                                .foregroundColor(.black)
                                .frame(minHeight: 150)
                                .padding(8)
                                .background(Color(hex: "f9f9f9"))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)

                    // Submit button
                    Button(action: {
                        submitFeedback()
                    }) {
                        Text("Submit Feedback")
                            .font(.custom("Poppins-Medium", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(feedbackText.isEmpty ? Color.gray : Color.black)
                            .cornerRadius(12)
                    }
                    .disabled(feedbackText.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "f9f9f9"))
        .alert("Thank You!", isPresented: $showingThankYou) {
            Button("OK") {
                dismissWithoutAnimation?()
            }
        } message: {
            Text("We've received your feedback and will review it shortly.")
        }
    }

    private func submitFeedback() {
        // TODO: Send feedback to backend or email
        // For now, just show thank you message
        showingThankYou = true
    }
}

// MARK: - Loading View Preview (DEBUG/TEMPORARY)
struct LoadingViewPreview: View {
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation

    var body: some View {
        ZStack {
            // The actual loading screen animation
            AppLoadingScreen()

            // Back button overlay in top-left
            VStack {
                HStack {
                    Button(action: {
                        HapticFeedback.light()
                        dismissWithoutAnimation?()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .padding(20)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                    }
                    .padding(.leading, 20)
                    .padding(.top, 60)

                    Spacer()
                }

                Spacer()
            }
        }
    }
}

// Replica of LoadingView from ContentView
private struct AppLoadingScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            // Remi logo image - static, no animation
            Image("Remi Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 360) // Doubled from 180

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "f9f9f9"))
    }
}
