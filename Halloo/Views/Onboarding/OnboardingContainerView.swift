//
//  OnboardingContainerView.swift
//  Halloo
//
//  Purpose: Main container that switches between all onboarding views
//  Key Features:
//    • Switches views based on OnboardingViewModel.currentStep
//    • Handles complete onboarding flow from Welcome → Dashboard
//    • Manages navigation between Welcome, Quiz, Auth, Paywall
//
//  Created by Claude Code on 2025-11-10
//

import SwiftUI

/// Main container for the entire onboarding flow
///
/// This view acts as a router, displaying the appropriate view based on
/// the current onboarding step. Handles the complete journey from welcome
/// screen through quiz, authentication, paywall, and completion.
struct OnboardingContainerView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView()

            case .step1WhoFor:
                Step1View()

            case .step2Connection:
                Step2View()

            case .step3NameRelationship:
                Step3View()

            case .step4MemoryVision:
                Step4View()

            case .saveYourProgress:
                SaveYourProgressView()

            case .step6Paywall:
                Step6View()

            case .profileSetupConfirmation:
                ProfileSetupConfirmationView()

            case .signUp:
                // Deprecated - redirect to quiz
                WelcomeView()
                    .onAppear {
                        viewModel.startQuiz()
                    }

            case .preferences:
                // Show CreateProfileView
                Text("Create Profile (TODO)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "f9f9f9"))

            case .complete:
                // This should never show - ContentView handles transition to dashboard
                ProgressView()
            }
        }
        .environmentObject(viewModel)
    }
}
