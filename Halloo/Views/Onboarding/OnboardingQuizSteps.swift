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
        "👩 Mom",
        "👨 Dad",
        "👨‍👩‍👧 Both",
        "💛 Other"
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

                        Text("We'll use this to generate your custom plan")
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
        "🔔 Often",
        "⏰ As needed",
        "🌿 Rarely"
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

// MARK: - Step 4: Current Reminders (Problem Discovery)

struct Step4CurrentRemindersView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedReminders: Set<String> = []
    @State private var showContent = false

    let reminderOptions = [
        ("Phone calendar/alarms", "📱"),
        ("Manual text messages", "💬"),
        ("Sticky notes", "📝"),
        ("Written lists", "🗓️"),
        ("Just trying to remember", "🧠"),
        ("None - this is new for me", "❌")
    ]

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
                        Text("What type of reminders do you currently use?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("Select all that apply")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)

                    // Scrollable multi-select reminder options
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(Array(reminderOptions.enumerated()), id: \.offset) { index, reminder in
                                QuizMultiSelectButton(
                                    text: reminder.0,
                                    emoji: reminder.1,
                                    index: index,
                                    isSelected: selectedReminders.contains(reminder.0),
                                    onTap: {
                                        // "None" is exclusive - deselects all others
                                        if reminder.0 == "None - this is new for me" {
                                            if selectedReminders.contains(reminder.0) {
                                                selectedReminders.remove(reminder.0)
                                            } else {
                                                selectedReminders.removeAll()
                                                selectedReminders.insert(reminder.0)
                                            }
                                        } else {
                                            // Remove "None" if user selects any other option
                                            selectedReminders.remove("None - this is new for me")

                                            if selectedReminders.contains(reminder.0) {
                                                selectedReminders.remove(reminder.0)
                                            } else {
                                                selectedReminders.insert(reminder.0)
                                            }
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
                    isEnabled: !selectedReminders.isEmpty,
                    action: {
                        // Save answers
                        viewModel.userAnswers["current_reminders"] = Array(selectedReminders).joined(separator: ", ")
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

// MARK: - Step 4a: Tech Comfort Level (Objection Handling)

struct Step4aTechComfortView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedComfort: String? = nil

    let techComfortOptions = [
        "Very comfortable with tech",
        "Somewhat comfortable",
        "Prefers simple solutions",
        "Not tech-savvy at all"
    ]

    // Get recipient name from quiz answers
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "they"
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
                    Text("How comfortable are \(recipientName) with technology?")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)

                    // Single-select tech comfort options (black button style)
                    VStack(spacing: 12) {
                        ForEach(Array(techComfortOptions.enumerated()), id: \.element) { index, option in
                            QuizOptionButton(
                                text: option,
                                index: index,
                                isSelected: selectedComfort == option,
                                onTap: {
                                    selectedComfort = option
                                }
                            )
                        }
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedComfort != nil,
                    action: {
                        // Save answer
                        viewModel.userAnswers["tech_comfort"] = selectedComfort ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
    }
}

// MARK: - Step 4b: Satisfaction Level (Pain Amplification)

struct Step4bSatisfactionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedSatisfaction: String? = nil

    let satisfactionOptions = [
        "Pretty well - I like my system",
        "It's okay - but I'd like something better",
        "Not great - I need a better solution"
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Header
                    Text("How well is this working for you?")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)

                    // Single-select satisfaction options (black button style)
                    VStack(spacing: 12) {
                        ForEach(Array(satisfactionOptions.enumerated()), id: \.element) { index, option in
                            QuizOptionButton(
                                text: option,
                                index: index,
                                isSelected: selectedSatisfaction == option,
                                onTap: {
                                    selectedSatisfaction = option
                                }
                            )
                        }
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedSatisfaction != nil,
                    action: {
                        // Save answer
                        viewModel.userAnswers["satisfaction_level"] = selectedSatisfaction ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
    }
}

// MARK: - Step 5a: Current Frustration (Peak Pain Amplification)

struct Step5aCurrentFrustrationView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedFrustration: String? = nil

    let frustrationOptions = [
        "I forget to remind them",
        "They forget even when I remind them",
        "Takes too much of my time",
        "I feel like I'm nagging",
        "Not sure if they actually did it"
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Header
                    Text("What frustrates you most about your current system?")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)

                    // Single-select frustration options (black button style)
                    VStack(spacing: 12) {
                        ForEach(Array(frustrationOptions.enumerated()), id: \.element) { index, option in
                            QuizOptionButton(
                                text: option,
                                index: index,
                                isSelected: selectedFrustration == option,
                                onTap: {
                                    selectedFrustration = option
                                }
                            )
                        }
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedFrustration != nil,
                    action: {
                        // Save answer
                        viewModel.userAnswers["current_frustration"] = selectedFrustration ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
    }
}

// MARK: - Empathy Break (Emotional Release After Pain Questions)

struct EmpathyBreakView: View {
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
                    // Family Lottie animation (larger, matching purple theme)
                    LottieView(animation: .named("Family"))
                        .playing(loopMode: .loop)
                        .frame(width: 280, height: 280)
                        .scaleEffect(showContent ? 1.0 : 0.85)
                        .offset(y: showContent ? 0 : -20)
                        .opacity(showContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showContent)

                    // Title and description with purple gradient hero word
                    VStack(spacing: 16) {
                        // Combined hero statement with purple gradient + black
                        (Text("We understand.\n")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "9333EA"), Color(hex: "C084FC")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                         +
                         Text("Caring for loved ones shouldn't feel this hard.")
                            .foregroundColor(.black)
                        )
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)

                        // Supporting CTA line
                        Text("Let's build a system that works for you both.")
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
                    },
                    buttonText: "Continue"
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Reminder Timing (Bridge Question - Introduces SMS Automation)

struct ReminderTimingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedTiming: String? = nil

    let timingOptions = [
        "Morning routine",
        "Around mealtimes",
        "Evening routine",
        "Throughout the day",
        "I'm not sure yet"
    ]

    // Get recipient name from quiz answers
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "them"
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
                    Text("When would a gentle reminder help \(recipientName) most?")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)

                    // Single-select timing options (black button style)
                    VStack(spacing: 12) {
                        ForEach(Array(timingOptions.enumerated()), id: \.element) { index, option in
                            QuizOptionButton(
                                text: option,
                                index: index,
                                isSelected: selectedTiming == option,
                                onTap: {
                                    selectedTiming = option
                                }
                            )
                        }
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedTiming != nil,
                    action: {
                        // Save answer
                        viewModel.userAnswers["reminder_timing"] = selectedTiming ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
    }
}

// MARK: - Step 4c: Habit Focus (Micro-Commitment) - MOVED FROM STEP 2

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
                    },
                    buttonText: "Got it"
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
    @State private var shouldShowUI = false

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                if shouldShowUI {
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
                    // Already granted - skip this screen immediately (don't show UI)
                    print("✅ Notifications already authorized - skipping")
                    viewModel.nextStep()
                } else if settings.authorizationStatus == .notDetermined {
                    // Not determined - show UI and permission dialog
                    shouldShowUI = true
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
                    // Denied or restricted - show UI with settings option
                    print("⚠️ Notifications denied/restricted - showing settings option")
                    shouldShowUI = true
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
                            Image("Face 1")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                )

                            Image("Face 2")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                )

                            Image("Face 3")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
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

// MARK: - Personalized Plan View

/// Shows user their personalized plan based on quiz answers
///
/// This view summarizes the user's quiz responses in a beautiful, personalized format.
/// Appears after notification permission and before social proof for psychological commitment.
struct PersonalizedPlanView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    // Helper to format recipient name
    private var recipientName: String {
        let answer = viewModel.userAnswers["who_to_help"] ?? "them"
        if answer == "Both" {
            return "your parents"
        } else if answer == "Other" {
            return "your loved one"
        } else {
            return answer
        }
    }

    // Helper to format selected moments
    private var selectedMomentsText: String {
        let moments = Array(viewModel.selectedMoments)
        if moments.isEmpty {
            return "Daily habits"
        } else if moments.count == 1 {
            return moments[0]
        } else if moments.count == 2 {
            return moments.joined(separator: " and ")
        } else {
            let lastMoment = moments.last!
            let otherMoments = moments.dropLast().joined(separator: ", ")
            return "\(otherMoments), and \(lastMoment)"
        }
    }

    // Habits to display with emoji mapping
    private var habitsToDisplay: [(name: String, emoji: String)] {
        let habitEmojiMap: [String: String] = [
            "Taking medication": "💊",
            "Going for a walk": "🚶",
            "Drinking water": "💧",
            "Sending a daily photo": "📸",
            "Staying positive": "😊",
            "Other": "✨"
        ]

        let selectedHabits = Array(viewModel.selectedMoments)

        // If user selected "Other" or no habits, show 3 random default habits
        if selectedHabits.contains("Other") || selectedHabits.isEmpty {
            return [
                ("Taking medication", "💊"),
                ("Going for a walk", "🚶"),
                ("Drinking water", "💧")
            ]
        }

        // Map selected habits to (name, emoji) tuples
        return selectedHabits.compactMap { habit in
            if let emoji = habitEmojiMap[habit] {
                return (name: habit, emoji: emoji)
            }
            return nil
        }
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,

            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                // Scrollable content area (including header)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: OnboardingUI.headerTopSpacing)

                        // Header
                        VStack(spacing: 20) {
                            // Title and description grouped together
                            VStack(spacing: 8) {
                                Text("Your Expert-Backed Plan For Remi")
                                    .font(.system(size: 32, weight: .bold))
                                    .tracking(-1.0)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)

                                Text("Based on your answers about helping \(recipientName)")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                            }
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.05), value: showContent)

                            Text("Start Today!")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .cornerRadius(25)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)
                        }
                        .padding(.horizontal, OnboardingUI.horizontalPadding)

                        Spacer()
                            .frame(height: 20)

                        // White container card for reminder strategies
                        VStack(alignment: .center, spacing: 16) {
                            // 5-star rating with laurel wreaths (smaller version)
                            HStack(spacing: 2) {
                                // Left laurel wreath
                                Image("Laurel Wreath")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 40)
                                    .opacity(showContent ? 1 : 0)
                                    .scaleEffect(showContent ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15), value: showContent)

                                // 5-star rating Lottie animation
                                LottieView(animation: .named("5 stars"))
                                    .playing(loopMode: .playOnce)
                                    .frame(width: 90, height: 36)
                                    .opacity(showContent ? 1 : 0)
                                    .scaleEffect(showContent ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: showContent)

                                // Right laurel wreath (flipped)
                                Image("Laurel Wreath")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 40)
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))  // Flip horizontally
                                    .opacity(showContent ? 1 : 0)
                                    .scaleEffect(showContent ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15), value: showContent)
                            }
                            .padding(.bottom, 8)

                            // Section header
                            HStack(spacing: 8) {
                                Text("🏆")
                                    .font(.system(size: 20))
                                Text("Simple, daily habits")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)

                            // Description with green card background
                            ZStack {
                                // Opaque green card behind text
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.15))

                                Text("Remi helps your parents stay on track with gentle text reminders they already know how to use — no apps, no learning curve, just consistency.")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(16)
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)

                        Spacer()
                            .frame(height: 20)

                        // First benefit section: Feel secure about the little things
                        VStack(spacing: 16) {
                            // Lottie animation
                            LottieView(animation: .named("Relax"))
                                .playing(loopMode: .loop)
                                .frame(width: 250, height: 250)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.35), value: showContent)

                            // Title
                            Text("Feel secure about the little things")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, OnboardingUI.horizontalPadding)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.4), value: showContent)

                            // Benefit points
                            VStack(alignment: .leading, spacing: 14) {
                                // Point 1: Automated reminders
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Automated reminders")
                                        .fontWeight(.bold) +
                                    Text(" keep habits ")
                                        .fontWeight(.regular) +
                                    Text("consistent")
                                        .fontWeight(.bold) +
                                    Text(" without effort")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 2: Clinical backing
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Backed by ")
                                        .fontWeight(.regular) +
                                    Text("clinical studies")
                                        .fontWeight(.bold) +
                                    Text(" showing ")
                                        .fontWeight(.regular) +
                                    Text("improved adherence")
                                        .fontWeight(.bold) +
                                    Text(" in older adults")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 3: Know when unanswered
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("You'll ")
                                        .fontWeight(.regular) +
                                    Text("know")
                                        .fontWeight(.bold) +
                                    Text(" when messages go ")
                                        .fontWeight(.regular) +
                                    Text("unanswered")
                                        .fontWeight(.bold))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 4: Simple text
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "message.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Works through ")
                                        .fontWeight(.regular) +
                                    Text("simple text")
                                        .fontWeight(.bold) +
                                    Text(" — ")
                                        .fontWeight(.regular) +
                                    Text("nothing to download")
                                        .fontWeight(.bold))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 5: Reduce stress
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.pink)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Designed to ")
                                        .fontWeight(.regular) +
                                    Text("reduce stress")
                                        .fontWeight(.bold) +
                                    Text(", not add to it")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }
                            }
                            .padding(.horizontal, OnboardingUI.horizontalPadding)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.45), value: showContent)
                        }
                        .padding(.vertical, 20)

                        Spacer()
                            .frame(height: 20)

                        // Experts recommend card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text("🎩")
                                    .font(.system(size: 20))
                                Text("Experts recommend:")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Card list for reminder strategies
                            VStack(spacing: 8) {
                                // Text reminders card
                                HStack(spacing: 12) {
                                    Text("💬")
                                        .font(.system(size: 28))
                                        .frame(width: 40, height: 40)

                                    Text("Mostly text reminders")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.black)

                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(hex: "F5F5F7"))
                                .cornerRadius(10)

                                // Photo confirmations card
                                HStack(spacing: 12) {
                                    Text("📸")
                                        .font(.system(size: 28))
                                        .frame(width: 40, height: 40)

                                    Text("Occasional photo confirmations")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.black)

                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(hex: "F5F5F7"))
                                .cornerRadius(10)
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.55), value: showContent)

                        Spacer()
                            .frame(height: 32)

                        // Second benefit section: Become the child who always shows up
                        VStack(spacing: 16) {
                            // Lottie animation
                            LottieView(animation: .named("Family"))
                                .playing(loopMode: .loop)
                                .frame(width: 250, height: 250)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)

                            // Title
                            Text("Become the child who always shows up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, OnboardingUI.horizontalPadding)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.55), value: showContent)

                            // Benefit points (no cards, just list)
                            VStack(alignment: .leading, spacing: 14) {
                                // Point 1: Health
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Keep them ")
                                        .fontWeight(.regular) +
                                    Text("healthy")
                                        .fontWeight(.bold) +
                                    Text(" with ")
                                        .fontWeight(.regular) +
                                    Text("minimal effort")
                                        .fontWeight(.bold))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 2: Nothing slips
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Make sure ")
                                        .fontWeight(.regular) +
                                    Text("nothing important")
                                        .fontWeight(.bold) +
                                    Text(" slips through the cracks")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 3: Longevity
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Build habits that ")
                                        .fontWeight(.regular) +
                                    Text("improve their longevity")
                                        .fontWeight(.bold))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 4: Stay close
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "figure.2.and.child.holdinghands")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Stay ")
                                        .fontWeight(.regular) +
                                    Text("close")
                                        .fontWeight(.bold) +
                                    Text(" even when life gets ")
                                        .fontWeight(.regular) +
                                    Text("busy")
                                        .fontWeight(.bold))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 5: Lasting memories
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.pink)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Turn ")
                                        .fontWeight(.regular) +
                                    Text("everyday replies")
                                        .fontWeight(.bold) +
                                    Text(" into ")
                                        .fontWeight(.regular) +
                                    Text("lasting memories")
                                        .fontWeight(.bold))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }
                            }
                            .padding(.horizontal, OnboardingUI.horizontalPadding)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.6), value: showContent)
                        }
                        .padding(.vertical, 20)

                        Spacer()
                            .frame(height: 32)

                        // White container card for personalized plan
                        VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("🌿")
                                        .font(.system(size: 20))
                                    Text("Based on your quiz selections:")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text("We'll add these recommendations when you create habits with Remi later")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.black)
                            }

                            // Card list for selected habits
                            VStack(spacing: 8) {
                                ForEach(Array(habitsToDisplay.enumerated()), id: \.offset) { index, habit in
                                    HStack(spacing: 12) {
                                        Text(habit.emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 40, height: 40)

                                        Text(habit.name)
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.black)

                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color(hex: "F5F5F7"))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.65), value: showContent)

                        Spacer()
                            .frame(height: 32)

                        // Third benefit section: Proven by research
                        VStack(spacing: 16) {
                            // Lottie animation
                            LottieView(animation: .named("Like success"))
                                .playing(loopMode: .loop)
                                .frame(width: 280, height: 280)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.7), value: showContent)

                            // Title
                            Text("Proven by research")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, OnboardingUI.horizontalPadding)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.75), value: showContent)

                            // Benefit points
                            VStack(alignment: .leading, spacing: 14) {
                                // Point 1: 40% improvement
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "6BB6D6"))
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Up to ")
                                        .fontWeight(.regular) +
                                    Text("40% improvement")
                                        .fontWeight(.bold) +
                                    Text(" in habit adherence")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 2: Clinical studies
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Validated by ")
                                        .fontWeight(.regular) +
                                    Text("clinical studies")
                                        .fontWeight(.bold) +
                                    Text(" from JAMA and Stanford")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 3: Text-based
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "message.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Text-based reminders are ")
                                        .fontWeight(.regular) +
                                    Text("most effective")
                                        .fontWeight(.bold) +
                                    Text(" for older adults")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 4: Long-term success
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Sustained ")
                                        .fontWeight(.regular) +
                                    Text("long-term success")
                                        .fontWeight(.bold) +
                                    Text(" through consistent check-ins")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }

                                // Point 5: Real-world results
                                HStack(alignment: .center, spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.pink)
                                            .frame(width: 24, height: 24)

                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }

                                    (Text("Trusted by ")
                                        .fontWeight(.regular) +
                                    Text("thousands of families")
                                        .fontWeight(.bold) +
                                    Text(" nationwide")
                                        .fontWeight(.regular))
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }
                            }
                            .padding(.horizontal, OnboardingUI.horizontalPadding)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.8), value: showContent)
                        }
                        .padding(.vertical, 20)

                        Spacer()
                            .frame(height: 20)

                        // Research-backed studies section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Plan further with Research-backed studies")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, OnboardingUI.horizontalPadding)

                            VStack(alignment: .leading, spacing: 6) {
                                // Study 1: JAMA Network Open
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)

                                    Button(action: {
                                        if let url = URL(string: "https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2794447") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("JAMA: Text messaging improves medication adherence")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.black)
                                            .underline()
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                // Study 2: Cochrane Review
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)

                                    Button(action: {
                                        if let url = URL(string: "https://www.cochranelibrary.com/cdsr/doi/10.1002/14651858.CD007458.pub3/full") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("Cochrane: SMS for long-term adherence")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.black)
                                            .underline()
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                // Study 3: Stanford Behavior Design Lab
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)

                                    Button(action: {
                                        if let url = URL(string: "https://behaviordesign.stanford.edu/") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("Stanford: Tiny Habits framework")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.black)
                                            .underline()
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.horizontal, OnboardingUI.horizontalPadding)
                        }
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.7), value: showContent)

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.bottom, 20)
                }

                OnboardingNextButton(
                    isEnabled: true,
                    action: {
                        viewModel.nextStep()
                    },
                    buttonText: "Save my setup"
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.75), value: showContent)
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

// MARK: - Plan Ready Teaser View (before loading screen)

struct PlanReadyTeaserView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    // Get recipient name from quiz answers
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "your loved one"
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Lottie animation (matching notification banner size/position)
                    LottieView(animation: .named("verification"))
                        .playing(loopMode: .playOnce)
                        .frame(width: 200, height: 200)
                        .scaleEffect(showContent ? 1.0 : 0.85)
                        .offset(y: showContent ? 0 : -20)
                        .opacity(showContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showContent)

                    // Title and description
                    VStack(spacing: 16) {
                        // Title - with gradient on "customized plan"
                        (Text("Time to generate your\n")
                            .foregroundColor(.black)
                         +
                         Text("customized plan!")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "0E9883"), Color(hex: "4ECDC4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)

                        // Description - exact same specs as "We'll ping you"
                        Text("Let us personalize Remi for you")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.4).delay(0.4), value: showContent)
                    }

                    // Privacy section with blurred glass card and shield on top edge
                    ZStack(alignment: .top) {
                        // Blurred glass card background (matching notification box)
                        VStack(spacing: 8) {
                            // Spacer for shield
                            Spacer()
                                .frame(height: 12)

                            // Privacy title
                            Text("We value your privacy and security")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeIn(duration: 0.4).delay(0.6), value: showContent)

                            // Privacy description
                            Text("We'll never share your family's information. Your data is held privately")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeIn(duration: 0.4).delay(0.7), value: showContent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Color.white)
                        )

                        // Lock emoji sitting on top edge
                        Text("🔒")
                            .font(.system(size: 32))
                            .offset(y: -16)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.4).delay(0.5), value: showContent)
                    }
                    .padding(.top, 40)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                // Continue button
                OnboardingNextButton(
                    isEnabled: true,
                    action: {
                        viewModel.nextStep()
                    },
                    buttonText: "Continue"
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Loading Plan View (4s with artificial delays at 60% and 92%)

struct LoadingPlanView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var progress: Double = 0.0
    @State private var currentMessage: String = "Analyzing quiz answers..."
    @State private var completedBullets: Set<Int> = []

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    // Get recipient name from quiz answers
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "your loved one"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Percentage counter
            Text("\(Int(progress * 100))%")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.black)
                .padding(.bottom, 32)

            // Headline
            Text("We're building your plan")
                .font(.system(size: 28, weight: .bold))
                .tracking(-1.0)
                .foregroundColor(.black)
                .padding(.bottom, 4)

            Text("for \(recipientName)")
                .font(.system(size: 28, weight: .bold))
                .tracking(-1.0)
                .foregroundColor(.black)
                .padding(.bottom, 32)

            // Progress bar with blue gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6BB6FF"), Color(hex: "4A9DFF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.1), value: progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)

            // Current task message
            Text(currentMessage)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)

            // What we're personalizing (bullet list)
            VStack(alignment: .leading, spacing: 8) {
                Text("We're personalizing:")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.bottom, 8)

                BulletPoint(text: "Reminder schedule for \(recipientName)", showCheckmark: completedBullets.contains(0))
                BulletPoint(text: "Best daily habits", showCheckmark: completedBullets.contains(1))
                BulletPoint(text: "SMS message style", showCheckmark: completedBullets.contains(2))
                BulletPoint(text: "Check-in frequency", showCheckmark: completedBullets.contains(3))
                BulletPoint(text: "Family notifications", showCheckmark: completedBullets.contains(4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(hex: "f9f9f9")

                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color(hex: "B3B3B3").opacity(0.3)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                }
            }
            .ignoresSafeArea(.all)
        )
        .onAppear {
            startLoading()
        }
    }

    private func startLoading() {
        currentMessage = "Analyzing quiz answers..."
        hapticGenerator.prepare()

        // Start incrementing counter to show every percentage
        startCountingProgress()
    }

    private func showCheckmark(_ index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            self.completedBullets.insert(index)
        }
        hapticGenerator.impactOccurred()
    }

    private func startCountingProgress() {
        var currentPercentage = 0
        let totalDuration: TimeInterval = 4.0  // 4 seconds total
        let incrementDelay: TimeInterval = totalDuration / 100.0  // 0.04 seconds per increment

        Timer.scheduledTimer(withTimeInterval: incrementDelay, repeats: true) { timer in
            if currentPercentage <= 100 {
                // Update progress
                self.progress = Double(currentPercentage) / 100.0

                // Show checkmarks at specific milestones
                if currentPercentage == 20 {
                    self.showCheckmark(0)
                } else if currentPercentage == 40 {
                    self.showCheckmark(1)
                } else if currentPercentage == 60 {
                    self.showCheckmark(2)
                } else if currentPercentage == 80 {
                    self.showCheckmark(3)
                } else if currentPercentage == 100 {
                    self.showCheckmark(4)
                }

                // Update message at key points
                if currentPercentage == 60 {
                    // Pause at 60% for artificial delay
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.currentMessage = "Selecting best reminder times..."
                        currentPercentage += 1
                        self.continueCountingFrom(currentPercentage, totalDuration: totalDuration, incrementDelay: incrementDelay)
                    }
                } else if currentPercentage == 92 {
                    // Pause at 92% for artificial delay
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.currentMessage = "Finalizing recommendations..."
                        currentPercentage += 1
                        self.continueCountingFrom(currentPercentage, totalDuration: totalDuration, incrementDelay: incrementDelay)
                    }
                } else if currentPercentage == 100 {
                    // Done - advance to next screen
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.viewModel.nextStep()
                    }
                } else {
                    currentPercentage += 1
                }
            }
        }
    }

    private func continueCountingFrom(_ startPercentage: Int, totalDuration: TimeInterval, incrementDelay: TimeInterval) {
        var currentPercentage = startPercentage

        Timer.scheduledTimer(withTimeInterval: incrementDelay, repeats: true) { timer in
            if currentPercentage <= 100 {
                self.progress = Double(currentPercentage) / 100.0

                // Show checkmarks at specific milestones
                if currentPercentage == 20 {
                    self.showCheckmark(0)
                } else if currentPercentage == 40 {
                    self.showCheckmark(1)
                } else if currentPercentage == 60 {
                    self.showCheckmark(2)
                } else if currentPercentage == 80 {
                    self.showCheckmark(3)
                } else if currentPercentage == 100 {
                    self.showCheckmark(4)
                }

                if currentPercentage == 92 {
                    // Pause at 92% for artificial delay
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.currentMessage = "Finalizing recommendations..."
                        currentPercentage += 1
                        self.continueCountingFrom(currentPercentage, totalDuration: totalDuration, incrementDelay: incrementDelay)
                    }
                } else if currentPercentage == 100 {
                    // Done - advance to next screen
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.viewModel.nextStep()
                    }
                } else {
                    currentPercentage += 1
                }
            }
        }
    }
}

// Helper view for bullet points with optional checkmark
private struct BulletPoint: View {
    let text: String
    let showCheckmark: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 15))
                .foregroundColor(.black)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.black)

            Spacer()

            // Always reserve space for checkmark to prevent layout shift
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.black)
                .opacity(showCheckmark ? 1 : 0)
                .scaleEffect(showCheckmark ? 1 : 0.5)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCheckmark)
        }
    }
}
