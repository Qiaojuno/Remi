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
    // Background Colors
    static let backgroundColor = Color(hex: "f9f9f9")
    static let gradientColor = Color(hex: "B3B3B3")
    static let successGreen = Color(hex: "228B22")
    static let empathyBreakBackground = Color(hex: "E8F5E9")  // Sage green for emotional reset

    // SMS Bubble Colors (iOS standard)
    static let smsOutgoingBlue = Color(hex: "007AFF")
    static let smsIncomingGray = Color(hex: "E5E5EA")

    // Confirmation/Success Colors
    static let confirmationGreen = Color(hex: "10B981")
    static let confirmationGreenLight = Color(hex: "34D399")

    // Profile Colors
    static let profileLightBlue = Color(hex: "B9E3FF")

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
    static let totalSteps = 16
}

// MARK: - Progress Bar

/// Reusable progress bar with back button for onboarding steps
/// Progress is controlled by parent (OnboardingViewModel) - this is a presentational component
struct OnboardingProgressBar: View {
    @Binding var progress: Double
    let onBack: () -> Void
    var showBar: Bool = true  // When false, only show back chevron

    // Static storage to remember last progress across view recreations
    private static var lastProgress: Double = 0

    /// Reset progress to 0 (call when returning to welcome page)
    static func resetProgress() {
        lastProgress = 0
    }

    // Local state for animated display
    @State private var displayProgress: Double = OnboardingProgressBar.lastProgress

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: OnboardingUI.backButtonSize, height: OnboardingUI.backButtonSize)
            }

            if showBar {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track (rounded)
                        RoundedRectangle(cornerRadius: OnboardingUI.progressBarHeight / 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: OnboardingUI.progressBarHeight)

                        // Progress fill (rounded) - uses local animated state
                        RoundedRectangle(cornerRadius: OnboardingUI.progressBarHeight / 2)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * displayProgress, height: OnboardingUI.progressBarHeight)
                    }
                }
                .frame(height: OnboardingUI.progressBarHeight)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, OnboardingUI.horizontalPadding)
        .padding(.top, OnboardingUI.topPadding)
        .onAppear {
            // Start from last known progress
            displayProgress = Self.lastProgress
            // Animate to target after a brief delay to ensure initial state renders
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.easeOut(duration: 0.3)) {
                    displayProgress = progress
                }
                // Update lastProgress AFTER starting animation
                Self.lastProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            // Animate when progress changes while view is visible
            // But DON'T update lastProgress here - that would break the next view's animation
            withAnimation(.easeOut(duration: 0.3)) {
                displayProgress = newValue
            }
        }
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

// MARK: - Pastel Color Palette for Quiz Options

/// Pastel colors for selected quiz options - cycles based on index
enum QuizPastelColors {
    static let palette: [Color] = [
        Color(hex: "A8D5FF"),  // Pastel Blue - calming, trustworthy
        Color(hex: "B8E6C1"),  // Pastel Green - positive, growth
        Color(hex: "D4C4F5"),  // Pastel Lavender - gentle, creative
        Color(hex: "FFCDB2"),  // Pastel Coral - warm, friendly
        Color(hex: "B5EAD7"),  // Pastel Mint - fresh, light
        Color(hex: "FFE5D9")   // Pastel Peach - soft, approachable
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }
}

// MARK: - Quiz Option Button

/// Reusable option button for single-select quiz questions
/// White → Pastel color toggle design with subtle shadow
/// Sequential scale + spring animation for modern, premium feel
struct QuizOptionButton: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isVisible = false

    private var selectedColor: Color {
        QuizPastelColors.color(for: index)
    }

    var body: some View {
        Button(action: {
            onTap()
            HapticFeedback.medium()
        }) {
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 50)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(isSelected ? selectedColor : Color.clear, lineWidth: 3)
                )
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
/// White button with checkbox (empty → pastel color with checkmark)
/// Sequential scale + spring animation for modern, premium feel
struct QuizMultiSelectButton: View {
    let text: String
    let emoji: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isVisible = false

    private var selectedColor: Color {
        QuizPastelColors.color(for: index)
    }

    var body: some View {
        Button(action: {
            onTap()
            HapticFeedback.medium()
        }) {
            HStack(spacing: 12) {
                // Checkbox on the left with pastel color when selected
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? selectedColor : Color.black.opacity(0.2), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? selectedColor : Color.white)
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black.opacity(0.7))
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
            .background(
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(isSelected ? selectedColor : Color.clear, lineWidth: 3)
            )
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
    let showProgressBar: Bool  // When false, only show back chevron
    let content: Content

    init(
        progress: Binding<Double>,
        onBack: @escaping () -> Void,
        showProgressBar: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self._progress = progress
        self.onBack = onBack
        self.showProgressBar = showProgressBar
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(
                progress: $progress,
                onBack: onBack,
                showBar: showProgressBar
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
    /// Async action to perform Apple Sign In. Returns true if successful.
    let onAppleSignIn: () async -> Bool

    /// Async action to perform Google Sign In. Returns true if successful.
    let onGoogleSignIn: () async -> Bool

    /// Optional callback after successful authentication (e.g., navigate to next step)
    /// Only called when authentication actually succeeds.
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
                    let success = await onAppleSignIn()
                    if success {
                        onAuthComplete?()
                    }
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
                    let success = await onGoogleSignIn()
                    if success {
                        onAuthComplete?()
                    }
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

// MARK: - Habit Capsule Component

/// Reusable habit capsule with emoji, name, and pastel border
/// Used in Step3bView and PersonalizedPlanView to display selected habits
struct HabitCapsule: View {
    let emoji: String
    let name: String
    let colorIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 14))
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(QuizPastelColors.color(for: colorIndex), lineWidth: 2)
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

/// Auto-layout grid for habit capsules (2 per row)
/// Eliminates duplicated row layout code across quiz steps
struct HabitCapsuleGrid: View {
    let habits: [(name: String, emoji: String)]
    private let columns = 2

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(habitsForRow(rowIndex).indices, id: \.self) { localIndex in
                        let globalIndex = (rowIndex * columns) + localIndex
                        let habit = habitsForRow(rowIndex)[localIndex]
                        HabitCapsule(
                            emoji: habit.emoji,
                            name: habit.name,
                            colorIndex: globalIndex
                        )
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var rowCount: Int {
        (habits.count + columns - 1) / columns
    }

    private func habitsForRow(_ row: Int) -> [(name: String, emoji: String)] {
        let start = row * columns
        let end = min(start + columns, habits.count)
        guard start < habits.count else { return [] }
        return Array(habits[start..<end])
    }
}

// MARK: - Fade-In Animation Modifier

/// Auto-applies fade-in animation with configurable delay
/// Replaces the repetitive showContent pattern across quiz steps
struct FadeInOnAppear: ViewModifier {
    let delay: Double
    let duration: Double

    @State private var isVisible = false

    init(delay: Double = 0.1, duration: Double = 0.4) {
        self.delay = delay
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: duration), value: isVisible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// Applies fade-in animation on appear
    /// - Parameters:
    ///   - delay: Delay before animation starts (default 0.1s)
    ///   - duration: Animation duration (default 0.4s)
    func fadeInOnAppear(delay: Double = 0.1, duration: Double = 0.4) -> some View {
        self.modifier(FadeInOnAppear(delay: delay, duration: duration))
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
