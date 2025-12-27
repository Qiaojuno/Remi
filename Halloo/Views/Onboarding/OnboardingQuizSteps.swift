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

// MARK: - Step 1: Personalization - Emotional Connection (Who For)

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
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Set up your first profile")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("Who's this for?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
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
            // Restore saved answer if available
            if let saved = viewModel.userAnswers["who_to_help"], !saved.isEmpty {
                selectedOption = saved
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Name Input Step (NEW - Personalization)

struct NameInputStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var name: String = ""
    @State private var showContent = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("What's their first name?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("We'll personalize Remi just for them")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                    }

                    // Name input field (pill style)
                    TextField("Enter their name", text: $name)
                        .font(.system(size: 20, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 50)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 50)
                                .stroke(isNameFieldFocused ? Color.black : Color.gray.opacity(0.3), lineWidth: isNameFieldFocused ? 2 : 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                                viewModel.userAnswers["loved_one_name"] = name.trimmingCharacters(in: .whitespaces)
                                viewModel.nextStep()
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                OnboardingNextButton(
                    isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                    action: {
                        viewModel.userAnswers["loved_one_name"] = name.trimmingCharacters(in: .whitespaces)
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onAppear {
            // Restore saved name if available
            if let saved = viewModel.userAnswers["loved_one_name"], !saved.isEmpty {
                name = saved
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
            // Auto-focus the text field after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFieldFocused = true
            }
        }
    }
}

// MARK: - Step 2: Reminder Frequency (MOVED to end of flow)

struct Step2View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showContent = false

    // Get recipient name for personalization
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "them"
    }

    let options = [
        "🤗 Full Support",
        "📅 Daily Routine",
        "✨ Light Touch"
    ]

    let optionDescriptions = [
        "🤗 Full Support": "Multiple check-ins throughout the day",
        "📅 Daily Routine": "Once or twice a day",
        "✨ Light Touch": "A few times a week for big things"
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("How much support does \(recipientName) need right now?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("You can always adjust this later")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
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
            // Restore saved answer if available
            if let saved = viewModel.userAnswers["reminder_frequency"], !saved.isEmpty {
                selectedOption = saved
            }
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

    // Get recipient name for personalization
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "their"
    }

    let reminderOptions = [
        ("Phone calendar/alarms", "📱"),
        ("Manual text messages", "💬"),
        ("Sticky notes", "📝"),
        ("Written lists", "🗓️"),
        ("Trying to remember", "🧠"),
        ("None - this is new for me", "❌")
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("What should Remi take over?")
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
                        .padding(.top, 8)
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
            // Restore saved answer if available (comma-separated)
            if let saved = viewModel.userAnswers["current_reminders"], !saved.isEmpty {
                selectedReminders = Set(saved.components(separatedBy: ", "))
            }
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
    @State private var showContent = false
    @State private var showReassurance = false  // For "no download needed" banner

    let techComfortOptions = [
        "👍 Very comfortable",
        "🤷 Somewhat comfortable",
        "✨ Prefers simple solutions",
        "❌ Not tech-savvy at all"
    ]

    // Get recipient name from quiz answers
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "they"
    }

    // Check if selected option indicates low tech comfort
    private var isLowTechComfort: Bool {
        selectedComfort == "✨ Prefers simple solutions" || selectedComfort == "❌ Not tech-savvy at all"
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Header
                    Text("How does \(recipientName) feel about technology?")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                    // Single-select tech comfort options
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
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                }

                Spacer()

                // Reassurance banner (shows when low tech comfort selected) - above Next button
                if showReassurance {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(OnboardingUI.successGreen)
                            .font(.system(size: 20))

                        Text("That's exactly why we built Remi. \(recipientName) won't need to download anything — just simple text messages.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                OnboardingNextButton(
                    isEnabled: selectedComfort != nil,
                    action: {
                        viewModel.userAnswers["tech_comfort"] = selectedComfort ?? ""
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onChange(of: selectedComfort) { _, newValue in
            // Show reassurance when low tech comfort is selected
            let shouldShow = newValue == "✨ Prefers simple solutions" || newValue == "❌ Not tech-savvy at all"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showReassurance = shouldShow
            }
        }
        .onAppear {
            // Restore saved answer if available
            if let saved = viewModel.userAnswers["tech_comfort"], !saved.isEmpty {
                selectedComfort = saved
                // Also show reassurance if restored answer is low tech
                showReassurance = saved == "✨ Prefers simple solutions" || saved == "❌ Not tech-savvy at all"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Step 5a: Current Frustration (Peak Pain Amplification)

struct Step5aCurrentFrustrationView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedFrustration: String? = nil
    @State private var showContent = false
    @State private var showReassurance = false

    let frustrationOptions: [(label: String, emoji: String, reassurance: String)] = [
        ("The Nagging Feeling", "😤", "You are 42% more likely to achieve a goal simply by writing it down. Photo replies show you exactly what's happening."),
        ("Uncertainty & Doubt", "🤔", "98% of text messages are read within 3 minutes. Compare that to just 20% for emails or app notifications."),
        ("Forgetfulness", "🧠", "Most seniors miss app notifications, but 98% of text messages are read within 3 minutes."),
        ("Time Management", "⏰", "We handle the scheduling so you don't have to. Text messages are hard to miss.")
    ]

    private var currentReassurance: String? {
        frustrationOptions.first { $0.label == selectedFrustration }?.reassurance
    }

    private var currentOptionIndex: Int {
        frustrationOptions.firstIndex { $0.label == selectedFrustration } ?? 0
    }

    private var currentOptionColor: Color {
        QuizPastelColors.color(for: currentOptionIndex)
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            ZStack(alignment: .bottom) {
                // Main content - stable layout
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 24) {
                        // Header
                        Text("What would automation help you solve?")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, OnboardingUI.horizontalPadding)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        // Single-select frustration options
                        VStack(spacing: 12) {
                            ForEach(Array(frustrationOptions.enumerated()), id: \.offset) { index, option in
                                QuizOptionButton(
                                    text: "\(option.emoji) \(option.label)",
                                    index: index,
                                    isSelected: selectedFrustration == option.label,
                                    onTap: {
                                        selectedFrustration = option.label
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
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

                // Reassurance banner overlay - doesn't affect main layout
                if showReassurance, let message = currentReassurance {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(currentOptionColor)
                                .font(.system(size: 20))

                            Text(message)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(currentOptionColor.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .padding(.bottom, 100) // Position above the button
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .id(selectedFrustration)
                }
            }
        }
        .onChange(of: selectedFrustration) { oldValue, newValue in
            // Animate card out and back in when switching options
            if oldValue != nil && newValue != nil {
                // Switching between options - animate out then in
                withAnimation(.easeOut(duration: 0.15)) {
                    showReassurance = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showReassurance = true
                    }
                }
            } else {
                // First selection or deselection
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showReassurance = newValue != nil
                }
            }
        }
        .onAppear {
            // Restore saved answer if available
            if let saved = viewModel.userAnswers["current_frustration"], !saved.isEmpty {
                selectedFrustration = saved
                // Also show reassurance if restored answer exists
                showReassurance = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Empathy Break (Emotional Release After Pain Questions)

struct EmpathyBreakView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var showButton = false  // Separate state for delayed button

    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "your loved one"
    }

    var body: some View {
        ZStack {
            // Sage green background for emotional reset (per research doc)
            OnboardingUI.empathyBreakBackground
                .ignoresSafeArea()

            OnboardingStepContainer(
                progress: $viewModel.progress,
                onBack: viewModel.previousStep,
                showProgressBar: viewModel.showsProgressBar
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

                        // Title and description
                        VStack(spacing: 16) {
                            Text("Let Remi handle the logistics for you 💜")
                                .font(.system(size: 32, weight: .bold))
                                .tracking(-1.0)
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)

                            // Supporting description
                            Text("Plus, we'll save their replies in the Family Memory Gallery.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeIn(duration: 0.4).delay(0.4), value: showContent)
                        }
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)

                    Spacer()

                    // Button with 1.5s delay (per research doc - forces user to read/absorb)
                    OnboardingNextButton(
                        isEnabled: true,
                        action: {
                            viewModel.nextStep()
                        },
                        buttonText: "Let's do this"
                    )
                    .opacity(showButton ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: showButton)
                }
            }
            .background(Color.clear)  // Make container transparent to show sage background
        }
        .onAppear {
            // Show content immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
            // Brief delay for button after content appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showButton = true
            }
        }
    }
}

// MARK: - Reminder Timing (Bridge Question - Introduces SMS Automation)

struct ReminderTimingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedTiming: String? = nil
    @State private var showContent = false

    let timingOptions = [
        "🌅 Morning routine",
        "🍽️ Around mealtimes",
        "🌙 Evening routine",
        "☀️ Throughout the day",
        "🤔 I'm not sure yet"
    ]

    // Get recipient name from quiz answers
    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "them"
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
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
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

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
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
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
        .onAppear {
            // Restore saved answer if available
            if let saved = viewModel.userAnswers["reminder_timing"], !saved.isEmpty {
                selectedTiming = saved
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
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

    // Use loved_one_name if available, otherwise fall back to relationship
    private var recipientName: String {
        if let name = viewModel.userAnswers["loved_one_name"], !name.isEmpty {
            return name
        }
        let answer = viewModel.userAnswers["who_to_help"] ?? "them"
        if answer.contains("Both") || answer.contains("Other") {
            return "them"
        }
        if answer.contains("Mom") { return "Mom" }
        if answer.contains("Dad") { return "Dad" }
        return "them"
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Let's design \(recipientName)'s healthy day.")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("What habits should we support?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
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
                        .padding(.top, 8)
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
            // Restore saved selection if available
            if !viewModel.selectedMoments.isEmpty {
                selectedHabits = viewModel.selectedMoments
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Tone Selection Step (NEW - IKEA Effect)

struct ToneSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var currentToneIndex: Int = 0
    @State private var showContent = false

    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "Mom"
    }

    // Colors for each tone option
    private let toneColors: [Color] = [
        Color(hex: "FFB5C5"),  // Warm - soft pink
        Color(hex: "B5D4FF"),  // Polite - soft blue
        Color(hex: "FFD4B5")   // Playful - soft orange
    ]

    private var currentToneColor: Color {
        toneColors[currentToneIndex % toneColors.count]
    }

    // Compute restored index from saved answer
    private var restoredToneIndex: Int {
        guard let saved = viewModel.userAnswers["remi_tone"], !saved.isEmpty else { return 0 }
        let keys = ["warm", "polite", "playful"]
        return keys.firstIndex(of: saved) ?? 0
    }

    // Tone options: (label, key, message template, mock reply)
    private var toneOptions: [(label: String, key: String, message: String, reply: String)] {
        let name = recipientName
        return [
            ("Warm & Cheerful", "warm", "Hi \(name)! Hope you're having a lovely day. Time for your medication! 💊", "Thanks sweetie! Just took them 💕"),
            ("Polite & Respectful", "polite", "Good morning, \(name). This is a gentle reminder to take your medication.", "Thank you for the reminder. Done."),
            ("Fun & Playful", "playful", "Hey \(name)! Ready to crush today? Don't forget those meds! 💪", "Haha you got it! 👍")
        ]
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 20)

                // Header
                VStack(spacing: 12) {
                    Text("Choose your Tone")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                    Text("(you can change this later)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                // Card stack - use id to force recreation when saved tone changes
                ToneCardStack(
                    toneOptions: toneOptions,
                    currentIndex: $currentToneIndex,
                    initialIndex: restoredToneIndex
                )
                .id(viewModel.userAnswers["remi_tone"] ?? "default")
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)

                // Current tone label in colored pill
                Text(toneOptions[currentToneIndex].label)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .overlay(
                                Capsule()
                                    .stroke(currentToneColor, lineWidth: 3)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    )
                    .padding(.top, 40)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: showContent)
                    .animation(.easeInOut(duration: 0.3), value: currentToneIndex)

                Spacer()

                OnboardingNextButton(
                    isEnabled: true,
                    action: {
                        viewModel.userAnswers["remi_tone"] = toneOptions[currentToneIndex].key
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onAppear {
            // Restore saved selection using computed restoredToneIndex
            currentToneIndex = restoredToneIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

/// Swipeable card stack for tone selection (matching WelcomeCardStack style)
struct ToneCardStack: View {
    let toneOptions: [(label: String, key: String, message: String, reply: String)]
    @Binding var currentIndex: Int
    let initialIndex: Int

    @State private var stackedCards: [Int] = []
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var showCards = false

    private let sidePadding: CGFloat = 18
    private var cardWidth: CGFloat {
        (UIScreen.main.bounds.width - (sidePadding * 2)) * 0.855
    }
    private var cardHeight: CGFloat {
        cardWidth * 1.2
    }
    private let swipeThreshold: CGFloat = 90

    var body: some View {
        ZStack {
            ForEach(stackedCards, id: \.self) { cardIndex in
                if showCards {
                    let currentPosition = stackedCards.firstIndex(of: cardIndex) ?? 0

                    toneCard(for: cardIndex)
                        .scaleEffect(getCardScale(for: currentPosition))
                        .offset(
                            x: currentPosition == 0 ? dragOffset.width : getCardXOffset(for: currentPosition),
                            y: currentPosition == 0 ? dragOffset.height : getCardYOffset(for: currentPosition)
                        )
                        .rotationEffect(.degrees(
                            currentPosition == 0 ? Double(dragOffset.width * 0.02) : getCardRotation(for: currentPosition)
                        ))
                        .zIndex(currentPosition == 0 ? 100 : Double(10 - currentPosition))
                        .animation(currentPosition == 0 && isDragging ? nil : .easeOut(duration: 0.35), value: dragOffset)
                        .animation(currentPosition == 0 && isDragging ? nil : .linear(duration: 0.2), value: stackedCards)
                        .opacity(showCards ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(Double(currentPosition) * 0.1), value: showCards)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .gesture(DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = CGSize(width: value.translation.width, height: 0)
            }
            .onEnded { value in
                isDragging = false

                if abs(value.translation.width) > swipeThreshold && stackedCards.count > 1 {
                    HapticFeedback.light()

                    // Animate card off screen in swipe direction
                    let targetX = value.translation.width > 0 ? 405 : -405
                    dragOffset = CGSize(width: targetX, height: 0)

                    // Same queue behavior for both directions (top card moves to back)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        let topCard = stackedCards.removeFirst()
                        stackedCards.append(topCard)
                        currentIndex = stackedCards[0]
                        dragOffset = .zero
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = .zero
                    }
                }
            })
        .onAppear {
            stackedCards = Array(0..<toneOptions.count)
            if initialIndex > 0 && initialIndex < toneOptions.count {
                // Reorder so initialIndex is at front
                while stackedCards[0] != initialIndex {
                    let first = stackedCards.removeFirst()
                    stackedCards.append(first)
                }
            }
            // Ensure currentIndex matches the top card on initial load
            currentIndex = stackedCards[0]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showCards = true
            }
        }
    }

    private func toneCard(for index: Int) -> some View {
        let option = toneOptions[index]
        let currentPosition = stackedCards.firstIndex(of: index) ?? 0

        // Progressive lightening for stacked cards (matching WelcomeCardStack)
        let lighteningAmount = Double(currentPosition) * 0.05
        let cardColor = Color(
            red: 0.08 + lighteningAmount,
            green: 0.08 + lighteningAmount,
            blue: 0.12 + lighteningAmount
        )

        return ZStack {
            cardColor

            VStack {
                // Header with card counter
                HStack {
                    Text("\(index + 1)/\(toneOptions.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }

                Spacer()

                // SMS conversation preview
                VStack(spacing: 14) {
                    // Outgoing message (Remi's reminder)
                    HStack {
                        Spacer(minLength: 0)
                        SpeechBubbleView(
                            text: option.message,
                            isOutgoing: true,
                            backgroundColor: Color.blue,
                            textColor: .white,
                            maxWidth: cardWidth * 0.75,
                            scale: 0.85
                        )
                    }

                    // Incoming reply (loved one's response)
                    HStack {
                        SpeechBubbleView(
                            text: option.reply,
                            isOutgoing: false,
                            backgroundColor: Color(red: 0.9, green: 0.9, blue: 0.9),
                            textColor: .black,
                            maxWidth: cardWidth * 0.6,
                            scale: 0.85
                        )
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
                Spacer()
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(16)
    }

    // Card stack positioning helpers (matching WelcomeCardStack exactly)
    private func getCardScale(for position: Int) -> CGFloat {
        switch position {
        case 0: return 1.0
        case 1, 2: return 0.98
        default: return 0.96
        }
    }

    private func getCardXOffset(for position: Int) -> CGFloat {
        switch position {
        case 1: return -11  // Peek left
        case 2: return 9    // Peek right
        case 3: return -6   // Slight left
        default: return 0
        }
    }

    private func getCardYOffset(for position: Int) -> CGFloat {
        switch position {
        case 1: return -18  // Above
        case 2: return 16   // Below
        case 3: return -10  // Slight above
        default: return 0
        }
    }

    private func getCardRotation(for position: Int) -> Double {
        switch position {
        case 1: return -2.5
        case 2: return 1.8
        case 3: return -1.2
        default: return 0
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
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Auto-scrolling gallery carousel
                    AutoScrollingGalleryCarousel()
                        .frame(height: 220)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.5).delay(0.1), value: showContent)

                    VStack(spacing: 16) {
                        // Main text with green gradient on "Memories"
                        (Text("Saved as ")
                            .foregroundColor(.black)
                         +
                         Text("Memories")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "34D399"), Color(hex: "10B981")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)

                        Text("Remi doesn't just handle scheduled messages. We update your gallery with replies and photos.")
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
                    action: viewModel.nextStep
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

// MARK: - Auto-Scrolling Gallery Carousel

/// A 3-column gallery grid that auto-scrolls upward in a seamless infinite loop
/// Uses TimelineView for professional-grade continuous animation
/// Mix of ~40% text messages and ~60% pastel photo placeholders
struct AutoScrollingGalleryCarousel: View {
    // Gallery items - mixed content types for realistic feel
    // .photo = pastel icon cell, .text = SMS conversation cell
    private let galleryItems: [CarouselItemType] = [
        // Row 1
        .photo(color: Color(hex: "FFE5E5"), icon: "heart.fill", hasCheck: false),
        .text(hasCheck: true),
        .photo(color: Color(hex: "E5FFE5"), icon: "leaf.fill", hasCheck: false),
        // Row 2
        .photo(color: Color(hex: "FFF5E5"), icon: "cup.and.saucer.fill", hasCheck: true),
        .photo(color: Color(hex: "F0E5FF"), icon: "moon.stars.fill", hasCheck: false),
        .text(hasCheck: true),
        // Row 3
        .text(hasCheck: false),
        .photo(color: Color(hex: "F5FFE5"), icon: "figure.walk", hasCheck: true),
        .photo(color: Color(hex: "E5E5FF"), icon: "pills.fill", hasCheck: true),
        // Row 4
        .photo(color: Color(hex: "FFF0E5"), icon: "photo.fill", hasCheck: false),
        .text(hasCheck: true),
        .photo(color: Color(hex: "FFE5FF"), icon: "star.fill", hasCheck: false),
        // Row 5
        .text(hasCheck: true),
        .photo(color: Color(hex: "FFF5F0"), icon: "fork.knife", hasCheck: false),
        .photo(color: Color(hex: "F0FFE5"), icon: "eye.fill", hasCheck: true),
        // Row 6
        .photo(color: Color(hex: "FFE5F5"), icon: "gift.fill", hasCheck: false),
        .text(hasCheck: false),
        .photo(color: Color(hex: "E5FFFF"), icon: "phone.fill", hasCheck: true),
    ]

    private let columns = 3
    private let itemSize: CGFloat = 85
    private let spacing: CGFloat = 8
    private let scrollSpeed: Double = 25 // Points per second

    // Triple the items for seamless infinite scroll
    private var loopedItems: [CarouselItemType] {
        galleryItems + galleryItems + galleryItems
    }

    private var singleSetHeight: CGFloat {
        let rowCount = galleryItems.count / columns
        return CGFloat(rowCount) * (itemSize + spacing)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsedTime = timeline.date.timeIntervalSinceReferenceDate
            // Calculate offset using modulo for seamless loop
            let rawOffset = elapsedTime * scrollSpeed
            let offset = rawOffset.truncatingRemainder(dividingBy: Double(singleSetHeight))

            ZStack {
                VStack(spacing: 0) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(itemSize), spacing: spacing), count: columns),
                        spacing: spacing
                    ) {
                        ForEach(0..<loopedItems.count, id: \.self) { index in
                            CarouselCell(item: loopedItems[index], size: itemSize)
                        }
                    }
                }
                .offset(y: -CGFloat(offset))
            }
        }
        .frame(height: 220)
        .clipped()
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 25)
                Rectangle().fill(Color.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 25)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Carousel Item Types

enum CarouselItemType {
    case photo(color: Color, icon: String, hasCheck: Bool)
    case text(hasCheck: Bool)
}

// MARK: - Carousel Cell (renders either photo or text)

struct CarouselCell: View {
    let item: CarouselItemType
    let size: CGFloat

    var body: some View {
        switch item {
        case .photo(let color, let icon, let hasCheck):
            GalleryItemCell(color: color, icon: icon, hasCheck: hasCheck)
                .frame(width: size, height: size)
        case .text(let hasCheck):
            TextMessageCell(hasCheck: hasCheck)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Text Message Cell (SMS style)

struct TextMessageCell: View {
    let hasCheck: Bool

    var body: some View {
        ZStack {
            // Light gray background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "f5f5f5"))

            // SMS conversation bubbles
            VStack(spacing: 4) {
                // Outgoing message (blue, right aligned)
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "007AFF"))
                        .frame(width: 38, height: 16)
                        .overlay(
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 28, height: 2)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 22, height: 2)
                            }
                        )
                }
                .padding(.trailing, 8)

                // Incoming message (gray, left aligned)
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "E5E5EA"))
                        .frame(width: 32, height: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 22, height: 2)
                        )
                    Spacer()
                }
                .padding(.leading, 8)
            }

            // Confirmation checkmark overlay
            if hasCheck {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "10B981"))
                            .background(Circle().fill(Color.white).padding(2))
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
    }
}

/// Individual gallery cell with icon and optional confirmation check
struct GalleryItemCell: View {
    let color: Color
    let icon: String
    let hasCheck: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)

            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color.opacity(0.6).blended(with: .black, amount: 0.3))

            // Confirmation checkmark overlay
            if hasCheck {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "10B981"))
                            .background(Circle().fill(Color.white).padding(2))
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
    }
}

// Color blending extension for icon visibility
extension Color {
    func blended(with other: Color, amount: Double) -> Color {
        // Simple approximation - returns a darker version
        return self.opacity(1 - amount)
    }
}

// MARK: - Step 3b: Proof Screen (Authority & Logic)

struct Step3bView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "Mom"
    }

    // Get selected habits with emojis
    private var selectedHabitsWithEmoji: [(name: String, emoji: String)] {
        let habitEmojiMap: [String: String] = [
            "Taking medication": "💊",
            "Going for a walk": "🚶",
            "Drinking water": "💧",
            "Sending a daily photo": "📸",
            "Staying positive": "😊",
            "Other": "🥗"
        ]

        return Array(viewModel.selectedMoments).compactMap { habit in
            if let emoji = habitEmojiMap[habit] {
                // If "Other" is selected, display as "Meal picture"
                let displayName = habit == "Other" ? "Meal picture" : habit
                return (name: displayName, emoji: emoji)
            }
            return nil
        }
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Mock SMS conversation with glowing bubbles and tails
                    VStack(spacing: 16) {
                        // Outgoing message (blue, right aligned) - Remi's reminder
                        HStack {
                            Spacer(minLength: 60)
                            Text("Hi \(recipientName)! 🌞 Time to take your morning walk\n\nText back when you're done — I'd love to hear how it went 💬")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    BubbleWithTail(isOutgoing: true, cornerRadius: 16, tailSize: 12)
                                        .fill(Color(hex: "007AFF"))
                                )
                                .shadow(color: Color(hex: "007AFF").opacity(0.4), radius: 16, x: 0, y: 6)
                                .opacity(showContent ? 1 : 0)
                                .offset(x: showContent ? 0 : 30)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: showContent)
                        }

                        // Incoming message (gray, left aligned) - Reply
                        HStack {
                            Text("Just finished! Feeling great 💪")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    BubbleWithTail(isOutgoing: false, cornerRadius: 16, tailSize: 12)
                                        .fill(Color(hex: "E5E5EA"))
                                )
                                .shadow(color: Color(hex: "E5E5EA").opacity(0.5), radius: 16, x: 0, y: 6)
                                .opacity(showContent ? 1 : 0)
                                .offset(x: showContent ? 0 : -30)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: showContent)
                            Spacer(minLength: 60)
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        // Main title
                        Text("Planning is power 🔥")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        // Description with stat
                        Text("Scheduling when to do a habit increases follow-through by 91%, especially with the texts you chose:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        // Habit capsules - 2 per row layout
                        if !selectedHabitsWithEmoji.isEmpty {
                            VStack(spacing: 8) {
                                // Row 1: habits 0-1
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedHabitsWithEmoji.prefix(2).enumerated()), id: \.offset) { index, habit in
                                        HStack(spacing: 4) {
                                            Text(habit.emoji)
                                                .font(.system(size: 14))
                                            Text(habit.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.black)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(QuizPastelColors.color(for: index), lineWidth: 2)
                                        )
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                    }
                                }

                                // Row 2: habits 2-3
                                if selectedHabitsWithEmoji.count > 2 {
                                    HStack(spacing: 8) {
                                        ForEach(Array(selectedHabitsWithEmoji.dropFirst(2).prefix(2).enumerated()), id: \.offset) { index, habit in
                                            HStack(spacing: 4) {
                                                Text(habit.emoji)
                                                    .font(.system(size: 14))
                                                Text(habit.name)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(QuizPastelColors.color(for: index + 2), lineWidth: 2)
                                            )
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                        }
                                    }
                                }

                                // Row 3: habits 4-5
                                if selectedHabitsWithEmoji.count > 4 {
                                    HStack(spacing: 8) {
                                        ForEach(Array(selectedHabitsWithEmoji.dropFirst(4).prefix(2).enumerated()), id: \.offset) { index, habit in
                                            HStack(spacing: 4) {
                                                Text(habit.emoji)
                                                    .font(.system(size: 14))
                                                Text(habit.name)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(QuizPastelColors.color(for: index + 4), lineWidth: 2)
                                            )
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
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

    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "your loved one"
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Define your mission")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                        Text("What matters most to \(recipientName)?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
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
            // Restore saved answer if available
            if let saved = viewModel.userAnswers["what_matters_most"], !saved.isEmpty {
                selectedOption = saved
            }
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
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
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
    @State private var hasCheckedPermission = false

    var body: some View {
        Group {
            if !hasCheckedPermission {
                // Completely invisible while checking - prevents flash
                Color.clear
                    .onAppear {
                        checkAndRequestPermission()
                    }
            } else if shouldShowUI {
                permissionContent
            }
        }
    }

    private var permissionContent: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
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
        }
    }

    private func checkAndRequestPermission() {
        // Check current authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // Already granted - skip this screen immediately (don't show UI)
                    viewModel.nextStep()
                } else if settings.authorizationStatus == .notDetermined {
                    // Not determined - show UI and permission dialog
                    hasCheckedPermission = true
                    shouldShowUI = true
                    isCheckingPermission = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                            DispatchQueue.main.async {
                                // Proceed to next step after user responds
                                viewModel.nextStep()
                            }
                        }
                    }
                } else {
                    // Denied or restricted - show UI with settings option
                    hasCheckedPermission = true
                    shouldShowUI = true
                    authorizationStatus = settings.authorizationStatus
                    isCheckingPermission = false
                }
            }
        }
    }
}

// MARK: - Referral Source Question

struct ReferralSourceView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil
    @State private var showContent = false

    let options = [
        "Yes",
        "No"
    ]

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Were you recommended Remi by a Doctor or Home-care worker?")
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)

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
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: selectedOption != nil,
                    action: {
                        viewModel.userAnswers["referral_source"] = selectedOption ?? ""
                        viewModel.nextStep()
                    }
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)
            }
        }
        .onAppear {
            // Restore saved answer if available
            if let saved = viewModel.userAnswers["referral_source"], !saved.isEmpty {
                selectedOption = saved
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Free Trial Intro

struct FreeTrialIntroView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background
            OnboardingGradientBackground()

            VStack(spacing: 0) {
                // Header section with identity-focused messaging
                VStack(spacing: 12) {
                    // Main headline (identity transformation)
                    Text("Be Present, Not the Manager")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                    // Subhead
                    Text("Let Remi handle the logistics for less than the cost of a coffee")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)
                .padding(.top, 60)

                // Phone demo image
                Spacer()

                Image("PhoneDemo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 350)
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)

                Spacer()

                // Bottom section
                VStack(spacing: 16) {
                    // No payment due now
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text("No payment due now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: showContent)

                    // Try for $0.00 button
                    Button(action: {
                        HapticFeedback.medium()
                        viewModel.nextStep()
                    }) {
                        Text("Try for $0.00")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.black)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Free Trial Reminder

struct FreeTrialReminderView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background
            OnboardingGradientBackground()

            VStack(spacing: 0) {
                // Back chevron at top left
                HStack {
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Title
                Text("We'll send you a reminder before your free trial ends")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                    .padding(.top, 8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                Spacer()

                // Notification bell lottie
                LottieView(animation: .named("Notification"))
                    .playing(loopMode: .loop)
                    .frame(width: 200, height: 200)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showContent)

                Spacer()

                // Bottom section
                VStack(spacing: 16) {
                    // No payment due now
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text("No payment due now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)

                    // Continue for FREE button
                    Button(action: {
                        HapticFeedback.medium()
                        viewModel.nextStep()
                    }) {
                        Text("Continue for FREE")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.black)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: showContent)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
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
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
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
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                    // 5-star rating with laurel wreaths in bordered box
                    HStack(spacing: 4) {
                        // Left laurel wreath (30% smaller)
                        Image("Laurel Wreath")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 31.5, height: 63)
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showContent)

                        // 5-star rating Lottie animation (30% smaller)
                        LottieView(animation: .named("5 stars"))
                            .playing(loopMode: .playOnce)
                            .frame(width: 140, height: 56)
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: showContent)

                        // Right laurel wreath (flipped, 30% smaller)
                        Image("Laurel Wreath")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 31.5, height: 63)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))  // Flip horizontally
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showContent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                    )
                    .padding(.horizontal, OnboardingUI.horizontalPadding)

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
    @State private var improvementProgress: CGFloat = 0

    // Helper to format recipient name
    private var recipientName: String {
        let answer = viewModel.userAnswers["who_to_help"] ?? "them"
        if answer.contains("Both") {
            return "your parents"
        } else if answer.contains("Other") {
            return "your loved one"
        } else if answer.contains("Mom") {
            return "Mom"
        } else if answer.contains("Dad") {
            return "Dad"
        } else {
            return "your loved one"
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

    // Helper to format reminder frequency from quiz
    private var frequencyText: String {
        let frequency = viewModel.userAnswers["reminder_frequency"] ?? ""
        if frequency.contains("Often") {
            return "frequent reminders"
        } else if frequency.contains("Rarely") {
            return "gentle reminders"
        } else {
            return "reminders as needed"
        }
    }

    // Helper to format reminder timing from quiz
    private var timingText: String {
        let timing = viewModel.userAnswers["reminder_timing"] ?? ""
        switch timing {
        case "Morning routine":
            return "mornings"
        case "Around mealtimes":
            return "mealtimes"
        case "Evening routine":
            return "evenings"
        case "Throughout the day":
            return "key moments throughout the day"
        default:
            return "the times that work best"
        }
    }

    // Get the personalized name for SMS
    private var lovedOneName: String {
        viewModel.userAnswers["loved_one_name"] ?? "Mom"
    }

    // Generate sample SMS message based on selected tone
    private var sampleSMSMessage: String {
        let tone = viewModel.userAnswers["remi_tone"] ?? "warm"
        let name = lovedOneName

        // Get the first habit for the message
        let habit = habitsToDisplay.first?.name ?? "Taking medication"
        let habitAction = habit.lowercased().replacingOccurrences(of: "taking ", with: "take your ").replacingOccurrences(of: "going for a ", with: "go for a ").replacingOccurrences(of: "drinking ", with: "drink some ").replacingOccurrences(of: "sending a daily ", with: "send a ")

        switch tone {
        case "warm":
            return "Hi \(name)! Hope you're having a lovely day. Just a friendly reminder to \(habitAction)! 💊"
        case "polite":
            return "Good morning, \(name). This is a gentle reminder to \(habitAction). Have a wonderful day."
        case "direct":
            return "Reminder: Time to \(habitAction)."
        case "playful":
            return "Hey \(name)! Ready to crush today? Don't forget to \(habitAction)! 💪"
        default:
            return "Hi \(name)! Time for your \(habitAction). 💊"
        }
    }

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
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
                                Text("Congrats! Remi is now set up for \(lovedOneName)")
                                    .font(.system(size: 32, weight: .bold))
                                    .tracking(-1.0)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)

                                Text("They'll receive gentle SMS reminders every morning. We'll use a 'Reply to Confirm' system so you never have to wonder if they did it.")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                            }
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.05), value: showContent)

                            // SMS Preview Mockup - at the top for immediate visualization
                            VStack(spacing: 0) {
                                // Message header bar
                                HStack {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                    Spacer()
                                    VStack(spacing: 2) {
                                        Text("Remi")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.black)
                                        Text("Text Message")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(hex: "F6F6F6"))

                                Divider()

                                // Message bubble
                                HStack {
                                    Text(sampleSMSMessage)
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: "E9E9EB"))
                                        .cornerRadius(18)
                                        .frame(maxWidth: 260, alignment: .leading)

                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.white)
                            }
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                            // Improvement chance card
                            VStack(alignment: .leading, spacing: 10) {
                                // 89% text
                                Text("89%")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.black)

                                // Progress bar with circle indicator
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background track
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 12)

                                        // Progress fill with pink-to-blue gradient
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "E4D4F4"), Color(hex: "7BA4F4")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * improvementProgress, height: 12)

                                        // Circle indicator
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 20, height: 20)
                                            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
                                            .offset(x: max(0, (geometry.size.width * improvementProgress) - 10))
                                            .opacity(improvementProgress > 0 ? 1 : 0)
                                    }
                                }
                                .frame(height: 20)

                                // Description text
                                Text("Chance of improvement with Remi")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            )
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

                            // Description with blue card background
                            ZStack {
                                // Blue card behind text
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "7BA4F4").opacity(0.15))

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

                        // Second benefit section: Become the person who always shows up
                        VStack(spacing: 16) {
                            // Lottie animation
                            LottieView(animation: .named("Family"))
                                .playing(loopMode: .loop)
                                .frame(width: 250, height: 250)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)

                            // Title
                            Text("Become the person who always shows up")
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

                        // Personalized reminder schedule card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text("📅")
                                    .font(.system(size: 20))
                                Text("Your reminder schedule:")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("You should send \(frequencyText) around \(timingText).")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("We'll ping you when they miss anything!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "7BA4F4").opacity(0.15))
                        )
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.85), value: showContent)

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
                // Animate progress bar after card fades in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        improvementProgress = 0.89
                    }
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
///
/// Uses shared `AuthButtonsView` component for DRY auth UI.
struct SaveYourProgressView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
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

                // Shared auth buttons component
                AuthButtonsView(
                    onAppleSignIn: { await viewModel.signInWithApple() },
                    onGoogleSignIn: { await viewModel.signInWithGoogle() },
                    onAuthComplete: { viewModel.nextStep() },
                    showPrivacyText: true
                )
                .padding(.horizontal, 24)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: showContent)

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
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
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
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeIn(duration: 0.4).delay(0.5), value: showContent)
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

            // Progress bar with pink-to-blue gradient
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
                                colors: [Color(hex: "E4D4F4"), Color(hex: "7BA4F4")],
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
        _ = withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
