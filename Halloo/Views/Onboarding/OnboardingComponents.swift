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
    static let topPadding: CGFloat = 30
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

    // Total steps in quiz flow
    static let totalSteps = 9
}

// MARK: - Progress Bar

/// Reusable progress bar with back button for onboarding steps
struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void

    private var progress: CGFloat {
        CGFloat(currentStep) / CGFloat(totalSteps)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: OnboardingUI.backButtonSize, height: OnboardingUI.backButtonSize)
                    .background(Color.white)
                    .clipShape(Circle())
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: OnboardingUI.progressBarHeight)

                    // Progress fill
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width * progress, height: OnboardingUI.progressBarHeight)
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

    var body: some View {
        Button(action: {
            if isEnabled {
                HapticFeedback.medium()
                action()
            }
        }) {
            Text("Next")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isEnabled ? Color.black : Color.gray.opacity(0.3))
                .cornerRadius(OnboardingUI.cornerRadius)
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
    @State private var showContent = false

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: subtitle != nil ? 12 : 0) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
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
        .opacity(showContent ? 1 : 0)
        .animation(.easeIn(duration: 0.3), value: showContent)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Quiz Option Button

/// Reusable option button for single-select quiz questions
/// Simple pastel→black toggle design
struct QuizOptionButton: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isVisible = false

    // Rotate through super shallow pastel colors
    private var unselectedBackground: Color {
        let pastelColors = [
            Color(hex: "B9E3FF").opacity(0.15),  // Light blue
            Color(hex: "FFE3E3").opacity(0.15),  // Light red/pink
            Color(hex: "E3FFE3").opacity(0.15),  // Light green
            Color(hex: "F0E3FF").opacity(0.15),  // Light purple
            Color(hex: "FFF0E3").opacity(0.15),  // Light orange
            Color(hex: "FFE3F0").opacity(0.15)   // Light pink
        ]
        return pastelColors[index % pastelColors.count]
    }

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
                .background(isSelected ? Color.black : unselectedBackground)
                .cornerRadius(12)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(
            .easeOut(duration: 0.4).delay(Double(index) * OnboardingUI.optionAnimationDelay),
            value: isVisible
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isVisible = true
            }
        }
    }
}

// MARK: - Quiz Multi-Select Button

/// Reusable option button for multi-select quiz questions
/// Simple pastel→black toggle design (same as single-select)
struct QuizMultiSelectButton: View {
    let text: String
    let emoji: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isVisible = false

    // Rotate through super shallow pastel colors
    private var unselectedBackground: Color {
        let pastelColors = [
            Color(hex: "B9E3FF").opacity(0.15),  // Light blue
            Color(hex: "FFE3E3").opacity(0.15),  // Light red/pink
            Color(hex: "E3FFE3").opacity(0.15),  // Light green
            Color(hex: "F0E3FF").opacity(0.15),  // Light purple
            Color(hex: "FFF0E3").opacity(0.15),  // Light orange
            Color(hex: "FFE3F0").opacity(0.15)   // Light pink
        ]
        return pastelColors[index % pastelColors.count]
    }

    var body: some View {
        Button(action: {
            onTap()
            HapticFeedback.medium()
        }) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 24))

                Text(text)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.black : unselectedBackground)
            .cornerRadius(12)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(
            .easeOut(duration: 0.4).delay(Double(index) * OnboardingUI.optionAnimationDelay),
            value: isVisible
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isVisible = true
            }
        }
    }
}

// MARK: - Step Container

/// Container that wraps all onboarding steps with consistent layout
struct OnboardingStepContainer<Content: View>: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let content: Content

    init(
        currentStep: Int,
        totalSteps: Int = OnboardingUI.totalSteps,
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(
                currentStep: currentStep,
                totalSteps: totalSteps,
                onBack: onBack
            )

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingGradientBackground())
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
                .frame(maxHeight: OnboardingUI.contentTopSpacing)

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

            Spacer()

            OnboardingNextButton(
                isEnabled: selectedOption != nil,
                action: onNext
            )
        }
    }
}
