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

// MARK: - Step 1: Personalization - Emotional Connection

struct Step1View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil

    let options = [
        "My Mom",
        "My Dad",
        "Both",
        "Another Relative"
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 1,
            onBack: viewModel.previousStep
        ) {
            QuizSelectionStep(
                title: "Who would you like to help with Remi?",
                subtitle: "We'll personalize reminders and tone for your family.",
                options: options,
                selectedOption: $selectedOption,
                onNext: {
                    viewModel.userAnswers["who_to_help"] = selectedOption ?? ""
                    viewModel.nextStep()
                }
            )
        }
    }
}

// MARK: - Step 2: Habit Focus (Micro-Commitment)

struct Step2View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedHabits: Set<String> = []

    let habitOptions = [
        ("Taking medication", "💊"),
        ("Going for a walk", "🚶"),
        ("Drinking water", "💧"),
        ("Sending a daily photo", "📸"),
        ("Staying positive", "😊"),
        ("Other", "✨")
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 2,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                OnboardingStepHeader(
                    title: "What would you like to remind \(viewModel.userAnswers["who_to_help"] ?? "them") about?",
                    subtitle: "You can always add or change these later."
                )

                Spacer()
                    .frame(maxHeight: OnboardingUI.contentTopSpacing)

                // Multi-select habit options
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
    }
}

// MARK: - Step 3: Proof Screen (Authority & Logic)

struct Step3View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        OnboardingStepContainer(
            currentStep: 3,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                OnboardingStepHeader(title: "Remi helps families build habits that stick.")

                Spacer()
                    .frame(maxHeight: 40)

                // Stats content
                VStack(alignment: .leading, spacing: 24) {
                    // Stat text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Studies show daily text reminders improve habit adherence by up to 40% in older adults.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Simple messages → consistent routines → lasting independence.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.1), value: showContent)

                    // Visual comparison chart
                    VStack(spacing: 16) {
                        // Remi Users - rising line
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Remi Users")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)

                            HStack(spacing: 4) {
                                ForEach(0..<7) { index in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black)
                                        .frame(width: 30, height: CGFloat(30 + index * 8))
                                }
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)

                        // Manual Reminders - declining line
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manual Reminders")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)

                            HStack(spacing: 4) {
                                ForEach(0..<7) { index in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(width: 30, height: CGFloat(80 - index * 8))
                                }
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.5), value: showContent)
                    }
                    .padding(.vertical, 20)
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

// MARK: - Step 4: Social Proof & Safety Beat

struct Step4View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var currentTestimonialIndex = 0
    @State private var showContent = false

    let testimonials = [
        "Remi helped me stop worrying about my dad's meds — now I just get a text and a smile photo every day.",
        "My mom finally takes her walks consistently — she even sends me photos!",
        "Remi made caring for my parents easy and stress-free."
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 4,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                OnboardingStepHeader(title: "Families everywhere use Remi to stay connected.")

                Spacer()
                    .frame(maxHeight: OnboardingUI.contentTopSpacing)

                // Testimonials
                VStack(spacing: 24) {
                    // Rotating testimonials
                    VStack(alignment: .leading, spacing: 16) {
                        Text("💬")
                            .font(.system(size: 32))
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.3).delay(0.1), value: showContent)

                        Text(testimonials[currentTestimonialIndex])
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.4).delay(0.2), value: showContent)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(12)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.3), value: showContent)

                    // Pagination dots
                    HStack(spacing: 8) {
                        ForEach(0..<testimonials.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentTestimonialIndex ? Color.black : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.5), value: showContent)
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

                // Auto-rotate testimonials every 4 seconds
                Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentTestimonialIndex = (currentTestimonialIndex + 1) % testimonials.count
                    }
                }
            }
        }
    }
}

// MARK: - Step 5: Save Your Progress (Auth Gate)

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
            currentStep: 5,
            totalSteps: 7,  // Welcome + 4 quiz steps + this step + paywall
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: 60)

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.black)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showContent)

                // Title
                Text("Save Your Progress")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .padding(.top, 24)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)

                // Subtitle
                Text("Create an account to save your personalized reminders for \(viewModel.userAnswers["loved_one_name"] ?? "your loved one")")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
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

                            // After successful auth, proceed to paywall
                            // Quiz data is automatically saved in handleSuccessfulAuthentication
                            await saveQuizDataToUser()
                            viewModel.nextStep()
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

                            // After successful auth, proceed to paywall
                            // Quiz data is automatically saved in handleSuccessfulAuthentication
                            await saveQuizDataToUser()
                            viewModel.nextStep()
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

    // MARK: - Save Quiz Data

    /// Save quiz answers to authenticated user's Firestore document
    ///
    /// Note: Quiz data is automatically saved in OnboardingViewModel.handleSuccessfulAuthentication
    /// when the user is created. This method is kept for future use if needed.
    private func saveQuizDataToUser() async {
        print("✅ Quiz data is automatically saved during authentication")
        // Quiz answers are already saved in OnboardingViewModel.handleSuccessfulAuthentication
        // when creating the new user with userAnswers
    }
}
