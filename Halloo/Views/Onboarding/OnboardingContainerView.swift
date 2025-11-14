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

            case .step2ReminderFrequency:
                Step2View()

            case .step3MedicationProblem:
                Step3View()

            case .step3bProofScreen:
                Step3bView()

            case .step4HabitFocus:
                Step4View()

            case .step5WhatMatters:
                Step5View()

            case .step6NotificationPromise:
                Step6View()

            case .notificationPermission:
                NotificationPermissionView()

            case .step7SocialProof:
                Step7View()

            case .saveYourProgress:
                SaveYourProgressView()

            case .step6Paywall:
                PaywallStepView()

            case .profileSetupConfirmation:
                ProfileSetupConfirmationView()

            // Deprecated cases - redirect
            case .step2Connection:
                Step4View()  // Old habit selection -> new Step4

            case .step3NameRelationship:
                Step3View()  // Redirect to medication problem

            case .step4WhatMatters:
                Step5View()  // Redirect to new Step5

            case .step5NotificationPromise:
                Step6View()  // Redirect to new Step6

            case .step6SocialProof:
                Step7View()  // Redirect to new Step7

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
