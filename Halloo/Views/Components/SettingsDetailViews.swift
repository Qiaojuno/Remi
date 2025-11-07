import SwiftUI
import SuperwallKit

// MARK: - Notifications Settings View
struct NotificationsSettingsView: View {
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation
    @State private var pushNotificationsEnabled = true
    @State private var smsRemindersEnabled = true
    @State private var taskRemindersEnabled = true
    @State private var photoResponsesEnabled = true

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
                    // Notification toggles
                    VStack(spacing: 0) {
                        toggleItem(
                            title: "Push Notifications",
                            subtitle: "App notifications for task updates",
                            isOn: $pushNotificationsEnabled
                        )

                        Divider()
                            .padding(.leading, 16)

                        toggleItem(
                            title: "SMS Reminders",
                            subtitle: "Send SMS to family members",
                            isOn: $smsRemindersEnabled
                        )

                        Divider()
                            .padding(.leading, 16)

                        toggleItem(
                            title: "Task Reminders",
                            subtitle: "Remind me to check on habits",
                            isOn: $taskRemindersEnabled
                        )

                        Divider()
                            .padding(.leading, 16)

                        toggleItem(
                            title: "Photo Response Alerts",
                            subtitle: "When loved ones send photos",
                            isOn: $photoResponsesEnabled
                        )
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Info text
                    Text("You'll receive notifications when your loved ones respond to reminders, complete tasks, or when it's time to send a new reminder.")
                        .font(.custom("Poppins-Regular", size: 13))
                        .foregroundColor(Color(hex: "7A7A7A"))
                        .padding(.horizontal, 30)
                }
            }
        }
        .background(Color(hex: "f9f9f9"))
    }

    private func toggleItem(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Poppins-Regular", size: 15))
                    .foregroundColor(.black)

                Text(subtitle)
                    .font(.custom("Poppins-Regular", size: 13))
                    .foregroundColor(Color(hex: "7A7A7A"))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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
        print("📝 Feedback submitted: [\(feedbackType.rawValue)] \(feedbackText)")
        showingThankYou = true
    }
}
