//
//  OnboardingQuizSteps.swift
//  Halloo
//
//  Purpose: All onboarding quiz steps including auth gate
//  Key Features:
//    • Steps 1-6 of onboarding flow (quiz + auth gate)
//    • Dramatically reduced code duplication (800+ lines → 500 lines)
//    • Uses OnboardingComponents for consistency
//    • Step 6: "Save Your Progress" auth gate before paywall
//
//  Created on 2025-11-10
//

import SwiftUI
import Lottie
import UserNotifications

// MARK: - Step 1: Personalization - Emotional Connection

struct Step1View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showContent = false

    let options = [
        "Mom",
        "Dad",
        "Both",
        "Other"
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Who would you like to help with Remi?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("We'll personalize reminders and tone for your family.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                    }

                    // Options
                    VStack(spacing: 12) {
                        ForEach(Array(options.enumerated()), id: \.element) { index, option in
                            QuizOptionButton(
                                text: option,
                                index: index,
                                isSelected: selectedOption == option,
                                onTap: { selectedOption = option }
                            )
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedOption != nil,
                    action: {
                        viewModel.userAnswers["who_to_help"] = selectedOption ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Step 2: Reminder Frequency

struct Step2View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showContent = false

    let options = [
        "Often",
        "As needed",
        "Rarely"
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("How often do they need reminders?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("This helps us understand their needs.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                    }

                    // Options
                    VStack(spacing: 12) {
                        ForEach(Array(options.enumerated()), id: \.element) { index, option in
                            QuizOptionButton(
                                text: option,
                                index: index,
                                isSelected: selectedOption == option,
                                onTap: { selectedOption = option }
                            )
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedOption != nil,
                    action: {
                        viewModel.userAnswers["reminder_frequency"] = selectedOption ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Step 4: Habit Focus (Micro-Commitment) - MOVED FROM STEP 2

struct Step4View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedHabits: Set<String> = []
    @State private var showContent = false

    let habitOptions = [
        ("Taking medication", "💊"),
        ("Going for a walk", "🚶"),
        ("Drinking water", "💧"),
        ("Sending a daily photo", "📸"),
        ("Staying positive", "😊"),
        ("Other", "✨")
    ]

    // Convert "Both" and "Other" to "them" for grammatical correctness
    private var personPronoun: String {
        let answer = viewModel.userAnswers["who_to_help"] ?? "them"
        if answer == "Both" || answer == "Other" {
            return "them"
        }
        return answer
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("What would you like to remind \(personPronoun) about?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("You can always add or change these later.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)

                    // Scrollable multi-select habit options
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(Array(habitOptions.enumerated()), id: \.offset) { index, habit in
                                QuizMultiSelectButton(
                                    text: habit.0,
                                    emoji: habit.1,
                                    index: index,
                                    isSelected: selectedHabits.contains(habit.0),
                                    onTap: {
                                        if selectedHabits.contains(habit.0) {
                                            selectedHabits.remove(habit.0)
                                        } else {
                                            selectedHabits.insert(habit.0)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .padding(.bottom, 20)
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: !selectedHabits.isEmpty,
                    action: {
                        viewModel.selectedMoments = selectedHabits
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Step 3: Problem Statement (Medication Adherence Crisis)

struct Step3View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Lottie animation
                    LottieView(animation: .named("Money"))
                        .playing(loopMode: .playOnce)
                        .frame(width: 200, height: 200)

                    VStack(spacing: 16) {
                        // Main text with gradient on "Half"
                        (Text("Half")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "E53E3E"), Color(hex: "FC8181")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                         +
                         Text(" of aging parents quietly skip their meds")
                            .foregroundColor(.black)
                        )
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.2), value: showContent)

                        Text("$300 billion lost to medication non-adherence last year alone")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)
                    }
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                OnboardingNextButton(
                    isEnabled: true,
                    action: viewModel.nextStep
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.5), value: showContent)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Step 3b: Proof Screen (Authority & Logic)

struct Step3bView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Animated comparison chart (Cal AI style)
                    HStack(alignment: .bottom, spacing: 30) {
                        // Manual Reminders (20% height)
                        ZStack(alignment: .bottom) {
                            // White 100% baseline bar (shorter, no stroke)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .frame(width: 100, height: 220)
                                .overlay(
                                    VStack {
                                        Text("Manual\nReminders")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.center)
                                            .opacity(showContent ? 1 : 0)
                                            .animation(.easeIn(duration: 0.3).delay(0.1), value: showContent)
                                        Spacer()
                                    }
                                    .padding(.top, 16)
                                )

                            // Grey bar animates to 20% (~44pt of 220pt)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: showContent ? 44 : 0)
                                .overlay(
                                    Text("20%")
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundColor(.black)
                                        .opacity(showContent ? 1 : 0)
                                )
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: showContent)
                        }

                        // Remi Reminders (70% height)
                        ZStack(alignment: .bottom) {
                            // White 100% baseline bar (shorter, no stroke)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .frame(width: 100, height: 220)
                                .overlay(
                                    VStack {
                                        Text("Remi")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.center)
                                            .opacity(showContent ? 1 : 0)
                                            .animation(.easeIn(duration: 0.3).delay(0.1), value: showContent)
                                        Spacer()
                                    }
                                    .padding(.top, 16)
                                )

                            // Black bar animates to 70% (~154pt of 220pt)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                                .frame(width: 100, height: showContent ? 154 : 0)
                                .overlay(
                                    Text("+40%")
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundColor(.white)
                                        .opacity(showContent ? 1 : 0)
                                )
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5), value: showContent)
                        }
                    }

                    VStack(spacing: 16) {
                        // Main text with gradient on "40%"
                        (Text("Automated text messages improve habit adherence by ")
                            .foregroundColor(.black)
                         +
                         Text("40%")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "4A9DFF"), Color(hex: "A8D8FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                        // Source citation
                        Text("JAMA Internal Medicine, 2016")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.2), value: showContent)

                Spacer()

                OnboardingNextButton(
                    isEnabled: true,
                    action: {
                        viewModel.nextStep()
                    }
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.7), value: showContent)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Step 5: What Matters Most (Emotional Connection) - MOVED FROM STEP 4

struct Step5View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showContent = false

    let options = [
        "Peace of mind",
        "Helping them stay consistent",
        "Staying connected even when far apart"
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("What matters most to you right now?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)
                    }

                    // Options
                    VStack(spacing: 12) {
                        ForEach(Array(options.enumerated()), id: \.element) { index, option in
                            QuizOptionButton(
                                text: option,
                                index: index,
                                isSelected: selectedOption == option,
                                onTap: { selectedOption = option }
                            )
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedOption != nil,
                    action: {
                        viewModel.userAnswers["what_matters_most"] = selectedOption ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Step 6: Reassurance / Notification Promise - MOVED FROM STEP 5

struct Step6View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    // Dynamic subtext based on user's "what matters most" answer
    private var dynamicSubtext: String {
        let whatMatters = viewModel.userAnswers["what_matters_most"] ?? ""

        if whatMatters == "Peace of mind" {
            return "If they ever miss a reminder, Remi lets you know — so you'll never have to worry again."
        } else if whatMatters == "Helping them stay consistent" {
            return "Remi gently checks in when habits are missed, helping them stay consistent without pressure."
        } else if whatMatters == "Staying connected even when far apart" {
            return "You'll be notified when they reply — so every message becomes a little connection moment."
        } else {
            return "Remi notifies you when reminders are missed, keeping you connected without being intrusive."
        }
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Authentic iOS notification banner (infographic)
                    ZStack {
                        // Blur background (iOS frosted glass effect)
                        RoundedRectangle(cornerRadius: 13)
                            .fill(.ultraThinMaterial)
                            .frame(maxWidth: 340, maxHeight: 110)
                            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)

                        VStack(alignment: .leading, spacing: 8) {
                            // Header row: App icon + name + timestamp
                            HStack(spacing: 10) {
                                // Rounded square app icon (iOS style)
                                Image("AppIconNotification")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                // App name
                                Text("Remi")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)

                                Spacer()

                                // Timestamp
                                Text("2m ago")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                            }

                            // Notification message
                            Text("Mom hasn't replied to her morning walk reminder yet. Want to check in?")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: 340)
                    }
                    .scaleEffect(showContent ? 1.0 : 0.85)
                    .offset(y: showContent ? 0 : -20)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showContent)

                    // Title and subtitle
                    VStack(spacing: 16) {
                        // Main text with gradient on "ping"
                        (Text("We'll ")
                            .foregroundColor(.black)
                         +
                         Text("ping")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "F59E0B"), Color(hex: "FBBF24")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                         +
                         Text(" you when there's missed replies")
                            .foregroundColor(.black)
                        )
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)

                        // Dynamic subtext
                        Text(dynamicSubtext)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.4).delay(0.4), value: showContent)
                    }
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                OnboardingNextButton(
                    isEnabled: true,
                    action: {
                        viewModel.nextStep()
                    }
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.6), value: showContent)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Notification Permission Request

struct NotificationPermissionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var authorizationStatus: UNAuthorizationStatus?
    @State private var isCheckingPermission = true

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                // Header at top
                Text("Enable notifications")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                    .padding(.top, OnboardingUI.headerTopSpacing)

                Spacer()

                if isCheckingPermission {
                    // Loading indicator while checking status or showing dialog
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else if authorizationStatus == .denied || authorizationStatus == .provisional {
                    // Mock iOS alert popup for denied state
                    // Alert container
                    VStack(spacing: 0) {
                        // Alert title
                        Text("\"Remi\" Would Like to Send You Notifications")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 8)

                        // Alert message
                        Text("Notifications are currently turned off. Enable them in Settings to get notified when they need a gentle nudge.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)

                        // Divider
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 0.5)

                        // Buttons
                        HStack(spacing: 0) {
                            // Cancel button
                            Button(action: {
                                HapticFeedback.light()
                                viewModel.nextStep()
                            }) {
                                Text("Not Now")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Color.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }

                            // Vertical divider
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 0.5)

                            // Settings button
                            Button(action: {
                                HapticFeedback.medium()
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }) {
                                Text("Settings")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Color.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(UIColor.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
                    .frame(maxWidth: 270)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                }

                Spacer()

                // Continue button (always show when in denied state)
                if authorizationStatus == .denied || authorizationStatus == .provisional {
                    OnboardingNextButton(
                        isEnabled: true,
                        action: {
                            viewModel.nextStep()
                        }
                    )
                }
            }
            .onAppear {
                checkAndRequestPermission()
            }
        }
    }

    private func checkAndRequestPermission() {
        // Check current authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // Already granted - skip this screen immediately
                    print("✅ Notifications already authorized - skipping")
                    viewModel.nextStep()
                } else if settings.authorizationStatus == .notDetermined {
                    // Not determined - show the permission dialog
                    isCheckingPermission = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    print("❌ Notification permission error: \(error.localizedDescription)")
                                }
                                print(granted ? "✅ Notification permission granted" : "⚠️ Notification permission denied")

                                // Proceed to next step after user responds
                                viewModel.nextStep()
                            }
                        }
                    }
                } else {
                    // Denied or restricted - show settings option
                    print("⚠️ Notifications denied/restricted - showing settings option")
                    authorizationStatus = settings.authorizationStatus
                    isCheckingPermission = false
                }
            }
        }
    }
}

// MARK: - Step 7: Rating Request - MOVED FROM STEP 6

struct Step7View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                // Header section with title, stars, and description
                VStack(spacing: 24) {
                    // Title (center-aligned)
                    Text("Give us a Rating")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .padding(.top, OnboardingUI.headerTopSpacing)

                    // 5-star rating with laurel wreaths (30% smaller overall)
                    HStack(spacing: 4) {
                        // Left laurel wreath (30% smaller)
                        Image("Laurel Wreath")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 31.5, height: 63)
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: showContent)

                        // 5-star rating Lottie animation (30% smaller)
                        LottieView(animation: .named("5 stars"))
                            .playing(loopMode: .playOnce)
                            .frame(width: 140, height: 56)
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showContent)

                        // Right laurel wreath (flipped, 30% smaller)
                        Image("Laurel Wreath")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 31.5, height: 63)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))  // Flip horizontally
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: showContent)
                    }

                    // Description (same font settings as title)
                    Text("Remi was created for people like you")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.6), value: showContent)
                }

                // Scrollable content area for reviews
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Top spacing
                        Spacer()
                            .frame(height: 20)

                        // Overlapping circles (avatars)
                        HStack(spacing: -12) {
                            Circle()
                                .fill(Color(hex: "4A9DFF"))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                )

                            Circle()
                                .fill(Color(hex: "FC8181"))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                )

                            Circle()
                                .fill(Color(hex: "FBBF24"))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                )
                        }
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.7), value: showContent)

                        // User count text
                        Text("10,000+ families who use Remi")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.4).delay(0.8), value: showContent)

                        // Review cards
                        VStack(spacing: 16) {
                            // Review 1
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 4) {
                                    ForEach(0..<5) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "FFD700"))
                                    }
                                }

                                Text("\"Remi helped me stop worrying about my dad's meds — now I just get a text and a smile photo every day.\"")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("— Sarah M.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)

                            // Review 2
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 4) {
                                    ForEach(0..<5) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "FFD700"))
                                    }
                                }

                                Text("\"My mom finally takes her walks consistently — she even sends me photos! Remi made it so easy.\"")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("— Michael T.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)

                            // Review 3
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 4) {
                                    ForEach(0..<5) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "FFD700"))
                                    }
                                }

                                Text("\"The peace of mind is priceless. I know exactly when Dad needs a gentle nudge without being overbearing.\"")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("— Jennifer L.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.9), value: showContent)
                    }
                    .padding(.bottom, 20)
                }

                OnboardingNextButton(
                    isEnabled: true,
                    action: {
                        viewModel.nextStep()
                    }
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.8), value: showContent)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Step 7: Save Your Progress (Auth Gate)

/// Auth gate that appears between quiz and paywall
///
/// This view presents authentication as a value-add ("save your progress")
/// rather than a hard requirement. Appears naturally after quiz completion
/// and before the paywall conversion step.
struct SaveYourProgressView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var isAuthenticating = false

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: 40)

                // Yoga Lottie animation (much bigger, looping)
                LottieView(animation: .named("Yoga"))
                    .playing(loopMode: .loop)
                    .frame(width: 350, height: 350)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showContent)

                Spacer()
                    .frame(height: 40)

                // Title
                Text("We remind, you relax")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)

                // Subtitle
                Text("You're almost there! Create an account to save your progress")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)

                Spacer()
                    .frame(minHeight: 40)

                // Auth buttons
                VStack(spacing: 12) {
                    // Apple Sign In
                    Button {
                        _Concurrency.Task {
                            isAuthenticating = true
                            await viewModel.signInWithApple()

                            // handleSuccessfulAuthentication() handles all navigation logic:
                            // - New user: Creates user with trial → dashboard
                            // - Existing user with subscription: → dashboard
                            // - Existing user without subscription: → paywall
                            // Quiz data is automatically saved in handleSuccessfulAuthentication
                            isAuthenticating = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .disabled(isAuthenticating)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: showContent)

                    // Google Sign In
                    Button {
                        _Concurrency.Task {
                            isAuthenticating = true
                            await viewModel.signInWithGoogle()

                            // handleSuccessfulAuthentication() handles all navigation logic:
                            // - New user: Creates user with trial → dashboard
                            // - Existing user with subscription: → dashboard
                            // - Existing user without subscription: → paywall
                            // Quiz data is automatically saved in handleSuccessfulAuthentication
                            isAuthenticating = false
                        }
                    } label: {
                        HStack {
                            Image("GoogleIcon")
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isAuthenticating)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)
                }
                .padding(.horizontal, 24)

                // Privacy text
                Text("By continuing, you agree to our Terms & Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.6), value: showContent)

                Spacer()
            }
        }
        .onAppear {
            // Trigger animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}
