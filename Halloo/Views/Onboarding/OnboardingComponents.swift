//
//  OnboardingComponents.swift
//  Halloo
//
//  Purpose: Reusable UI components for onboarding quiz flow
//  Key Features:
//    • Shared progress bar, backgrounds, buttons
//    • Eliminates 800+ lines of duplicated code
//    • Single source of truth for onboarding UI
//
//  Created by Claude Code on 2025-11-10
//

import SwiftUI

// MARK: - Onboarding Constants

/// Simple constants for onboarding UI - avoids magic numbers
enum OnboardingUI {
    // Colors
    static let backgroundColor = Color(hex: "f9f9f9")
    static let gradientColor = Color(hex: "B3B3B3")
    static let successGreen = Color(hex: "228B22")

    // Spacing
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 16
    static let headerTopSpacing: CGFloat = 20
    static let contentTopSpacing: CGFloat = 60

    // Sizing
    static let backButtonSize: CGFloat = 32
    static let progressBarHeight: CGFloat = 4
    static let buttonHeight: CGFloat = 47
    static let cornerRadius: CGFloat = 25
    static let checkmarkCircleSize: CGFloat = 20

    // Animation
    static let optionAnimationDelay: TimeInterval = 0.1

    // Total steps in quiz flow (notification permission, teaser, loading not counted)
    static let totalSteps = 17
}

// MARK: - Progress Bar

/// Reusable progress bar with back button for onboarding steps
/// Progress is controlled by parent (OnboardingViewModel) - this is a presentational component
struct OnboardingProgressBar: View {
    @Binding var progress: Double  // Animated by ViewModel
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: OnboardingUI.backButtonSize, height: OnboardingUI.backButtonSize)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track (rounded)
                    RoundedRectangle(cornerRadius: OnboardingUI.progressBarHeight / 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: OnboardingUI.progressBarHeight)

                    // Progress fill (rounded) - directly bound to ViewModel progress
                    RoundedRectangle(cornerRadius: OnboardingUI.progressBarHeight / 2)
                        .fill(Color.black)
                        .frame(width: geometry.size.width * progress, height: OnboardingUI.progressBarHeight)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: OnboardingUI.progressBarHeight)
        }
        .padding(.horizontal, OnboardingUI.horizontalPadding)
        .padding(.top, OnboardingUI.topPadding)
    }
}

// MARK: - Gradient Background

/// Reusable gradient background used across all onboarding steps
struct OnboardingGradientBackground: View {
    var body: some View {
        ZStack {
            OnboardingUI.backgroundColor

            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        OnboardingUI.gradientColor.opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
        }
        .ignoresSafeArea(.all)
    }
}

// MARK: - Next Button

/// Reusable "Next" button for onboarding steps
struct OnboardingNextButton: View {
    let isEnabled: Bool
    let action: () -> Void
    var buttonText: String = "Next"

    var body: some View {
        Button(action: {
            if isEnabled {
                HapticFeedback.medium()
                action()
            }
        }) {
            Text(buttonText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(isEnabled ? Color.black : Color.gray.opacity(0.3))
                .clipShape(Capsule())
        }
        .disabled(!isEnabled)
        .padding(.horizontal, OnboardingUI.horizontalPadding)
        .padding(.bottom, 20)
    }
}

// MARK: - Step Header

/// Reusable header for quiz steps (title only)
struct OnboardingStepHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: subtitle != nil ? 12 : 0) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .tracking(-1.0)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, OnboardingUI.horizontalPadding)
        .padding(.top, OnboardingUI.headerTopSpacing)
    }
}

// MARK: - Quiz Option Button

/// Reusable option button for single-select quiz questions
/// Simple white→black toggle design with subtle shadow
/// Sequential scale + spring animation for modern, premium feel
struct QuizOptionButton: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: {
            onTap()
            HapticFeedback.medium()
        }) {
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(isSelected ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.black : Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .scaleEffect(isVisible ? 1.0 : 0.92)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isVisible)
        .onAppear {
            // Sequential animation: 160ms delay between buttons
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.16)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Quiz Multi-Select Button

/// Reusable option button for multi-select quiz questions
/// White button with checkbox on right (empty→black with checkmark)
/// Sequential scale + spring animation for modern, premium feel
struct QuizMultiSelectButton: View {
    let text: String
    let emoji: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: {
            onTap()
            HapticFeedback.medium()
        }) {
            HStack(spacing: 12) {
                // Checkbox on the left
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.black : Color.white)
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(text)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)

                Text(emoji)
                    .font(.system(size: 24))

                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .scaleEffect(isVisible ? 1.0 : 0.92)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isVisible)
        .onAppear {
            // Sequential animation: 160ms delay between buttons
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.16)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Step Container

/// Container that wraps all onboarding steps with consistent layout
struct OnboardingStepContainer<Content: View>: View {
    @Binding var progress: Double  // Progress from ViewModel
    let onBack: () -> Void
    let content: Content

    init(
        progress: Binding<Double>,
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._progress = progress
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(
                progress: $progress,
                onBack: onBack
            )

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingGradientBackground())
    }
}

// MARK: - Auth Buttons (Shared Apple/Google Sign In)

/// Reusable authentication buttons for Apple and Google Sign In
///
/// This component provides consistent auth UI across:
/// - SaveYourProgressView (quiz flow auth gate)
/// - LoginSheetView (welcome page direct login)
///
/// ## Usage:
/// ```swift
/// AuthButtonsView(
///     onAppleSignIn: { await viewModel.signInWithApple() },
///     onGoogleSignIn: { await viewModel.signInWithGoogle() },
///     onAuthComplete: { viewModel.nextStep() }  // Optional post-auth action
/// )
/// ```
///
/// ## Design:
/// - Apple button: Black background, white text/icon
/// - Google button: White background with gray border, GoogleIcon asset
/// - Both buttons use consistent 16pt semibold text, 12pt corner radius
struct AuthButtonsView: View {
    /// Async action to perform Apple Sign In (typically viewModel.signInWithApple)
    let onAppleSignIn: () async -> Void

    /// Async action to perform Google Sign In (typically viewModel.signInWithGoogle)
    let onGoogleSignIn: () async -> Void

    /// Optional callback after successful authentication (e.g., navigate to next step)
    /// If nil, relies on reactive navigation via authService.isAuthenticated
    var onAuthComplete: (() -> Void)? = nil

    /// Whether to show privacy policy text below buttons
    var showPrivacyText: Bool = true

    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 12) {
            // Apple Sign In
            Button {
                guard !isAuthenticating else { return }
                _Concurrency.Task {
                    isAuthenticating = true
                    await onAppleSignIn()
                    onAuthComplete?()
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

            // Google Sign In
            Button {
                guard !isAuthenticating else { return }
                _Concurrency.Task {
                    isAuthenticating = true
                    await onGoogleSignIn()
                    onAuthComplete?()
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

            // Privacy text (optional)
            if showPrivacyText {
                Text("By continuing, you agree to our Terms & Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Quiz Selection Step (Generic)

/// Generic single-select quiz step - eliminates most duplication
struct QuizSelectionStep: View {
    let title: String
    let subtitle: String?
    let options: [String]
    @Binding var selectedOption: String?
    let onNext: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        options: [String],
        selectedOption: Binding<String?>,
        onNext: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.options = options
        self._selectedOption = selectedOption
        self.onNext = onNext
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(title: title, subtitle: subtitle)

            Spacer()
                .frame(height: 80)  // Fixed spacing from header

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

            Spacer()  // Flexible spacer to bottom

            OnboardingNextButton(
                isEnabled: selectedOption != nil,
                action: onNext
            )
        }
    }
}
