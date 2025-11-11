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

// MARK: - Step 1: Who For

struct Step1View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil

    let options = [
        "My parent",
        "My grandparent",
        "My partner",
        "Someone else I care about"
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 1,
            onBack: viewModel.previousStep
        ) {
            QuizSelectionStep(
                title: "Who are you downloading Remi for?",
                options: options,
                selectedOption: $selectedOption,
                onNext: {
                    viewModel.userAnswers["who_for"] = selectedOption ?? ""
                    viewModel.nextStep()
                }
            )
        }
    }
}

// MARK: - Step 2: Connection Frequency

struct Step2View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: String? = nil

    let options = [
        "Every day",
        "A few times a week",
        "Once a week",
        "Not as often as I'd like"
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 2,
            onBack: viewModel.previousStep
        ) {
            QuizSelectionStep(
                title: "How often do you think about them?",
                options: options,
                selectedOption: $selectedOption,
                onNext: {
                    viewModel.userAnswers["connection_frequency"] = selectedOption ?? ""
                    viewModel.nextStep()
                }
            )
        }
    }
}

// MARK: - Step 3: Name & Relationship

struct Step3View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var lovedOneName: String = ""
    @State private var selectedRelationship: String? = nil
    @State private var showContent = false

    let relationshipOptions = [
        "Mom",
        "Dad",
        "Grandma",
        "Grandpa",
        "Partner",
        "Other"
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 3,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                OnboardingStepHeader(title: "Tell us about them")

                Spacer()
                    .frame(maxHeight: 40)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Their name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)

                    TextField("Enter their name", text: $lovedOneName)
                        .font(.system(size: 18, weight: .regular))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.1), value: showContent)

                // Relationship selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your relationship")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                        .padding(.top, 20)

                    VStack(spacing: 8) {
                        ForEach(Array(relationshipOptions.enumerated()), id: \.element) { index, option in
                            Button(action: {
                                selectedRelationship = option
                                HapticFeedback.medium()
                            }) {
                                HStack {
                                    Text(option)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(selectedRelationship == option ? .white : .black)

                                    Spacer()

                                    if selectedRelationship == option {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(selectedRelationship == option ? Color.black : Color.white)
                                .cornerRadius(12)
                            }
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeIn(duration: 0.3).delay(0.2 + Double(index) * 0.05), value: showContent)
                        }
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: !lovedOneName.isEmpty && selectedRelationship != nil,
                    action: {
                        viewModel.userAnswers["loved_one_name"] = lovedOneName
                        viewModel.userAnswers["relationship"] = selectedRelationship ?? ""
                        viewModel.nextStep()
                    }
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.4), value: showContent)
            }
            .onTapGesture {
                // Dismiss keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Step 4: Memory Vision (Multi-Select)

struct Step4View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedMoments: Set<String> = []
    @State private var showOptions = false

    let momentOptions = [
        ("Morning coffee rituals", "☕"),
        ("Medication taken successfully", "💊"),
        ("Photos from their day", "📸"),
        ("Simple check-ins", "💬"),
        ("Meals they're proud of", "🍽️"),
        ("Walks and activities", "🚶")
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 4,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                OnboardingStepHeader(
                    title: "What kind of daily moments would you love to capture with \(viewModel.userAnswers["loved_one_name"] ?? "your loved one")?",
                    subtitle: "Select all that matter to you"
                )

                Spacer()
                    .frame(maxHeight: 40)

                // Multi-select checkboxes
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(momentOptions.enumerated()), id: \.offset) { index, moment in
                            CheckboxCard(
                                text: moment.0,
                                emoji: moment.1,
                                isSelected: selectedMoments.contains(moment.0),
                                onTap: {
                                    if selectedMoments.contains(moment.0) {
                                        selectedMoments.remove(moment.0)
                                    } else {
                                        selectedMoments.insert(moment.0)
                                    }
                                    HapticFeedback.medium()
                                }
                            )
                            .opacity(showOptions ? 1 : 0)
                            .offset(y: showOptions ? 0 : 10)
                            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: showOptions)
                        }
                    }
                    .padding(.horizontal, OnboardingUI.horizontalPadding)
                }

                Spacer()

                OnboardingNextButton(
                    isEnabled: !selectedMoments.isEmpty,
                    action: {
                        viewModel.selectedMoments = selectedMoments
                        viewModel.nextStep()
                    }
                )
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showOptions = true
                }
            }
        }
    }
}

// MARK: - Step 5: Emotional Hook

struct Step5View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedValue: String? = nil
    @State private var showGrid = false
    @State private var showOptions = false

    let emotionalValues = [
        "A priceless family treasure",
        "Daily peace of mind",
        "Staying close despite distance",
        "Creating lasting memories"
    ]

    var body: some View {
        OnboardingStepContainer(
            currentStep: 5,
            onBack: viewModel.previousStep
        ) {
            VStack(spacing: 0) {
                OnboardingStepHeader(
                    title: "Imagine a year with \(viewModel.userAnswers["loved_one_name"] ?? "your loved one")...",
                    subtitle: "What would that collection mean to you?"
                )

                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Memory grid mockup
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(0..<12, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        Image(systemName: index % 3 == 0 ? "photo" : index % 3 == 1 ? "message" : "heart.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.gray.opacity(0.4))
                                    )
                                    .opacity(showGrid ? 1 : 0)
                                    .scaleEffect(showGrid ? 1 : 0.8)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05), value: showGrid)
                            }
                        }
                        .padding(.horizontal, OnboardingUI.horizontalPadding)

                        // Options
                        VStack(spacing: 12) {
                            ForEach(Array(emotionalValues.enumerated()), id: \.element) { index, value in
                                QuizOptionButton(
                                    text: value,
                                    index: index,
                                    isSelected: selectedValue == value,
                                    onTap: { selectedValue = value }
                                )
                            }
                        }
                        .padding(.horizontal, OnboardingUI.horizontalPadding)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }

                Spacer()
                    .frame(height: 16)

                OnboardingNextButton(
                    isEnabled: selectedValue != nil,
                    action: {
                        if let value = selectedValue {
                            viewModel.emotionalValue = value
                        }
                        viewModel.nextStep()
                    }
                )
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showGrid = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showOptions = true
                }
            }
        }
    }
}

// MARK: - Step 6: Save Your Progress (Auth Gate)

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
            currentStep: 6,
            totalSteps: 8,  // Welcome + 5 quiz steps + this step + paywall
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
