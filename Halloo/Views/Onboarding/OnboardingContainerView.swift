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
        ZStack {
            // Persistent background to prevent white flash during view transitions
            Color(hex: "f9f9f9")
                .ignoresSafeArea()

            switch viewModel.currentStep {
            case .welcome:
                WelcomeView()

            // PHASE 1: Identity & Motivation
            case .step1WhoFor:
                Step1View()

            case .nameInput:
                NameInputStepView()

            case .step5WhatMatters:
                Step5View()

            // PHASE 2: Objection Handling
            case .step4aTechComfort:
                Step4aTechComfortView()

            // PHASE 3: Pain Amplification
            case .step3MedicationProblem:
                Step3View()

            case .step4CurrentReminders:
                Step4CurrentRemindersView()

            case .step4bSatisfaction:
                EmptyView() // Deprecated step - navigation skips this

            case .step5aCurrentFrustration:
                Step5aCurrentFrustrationView()

            case .empathyBreak:
                EmpathyBreakView()

            // PHASE 4: Co-Creation
            case .step4HabitFocus:
                Step4View()

            case .toneSelection:
                ToneSelectionView()

            case .step3bProofScreen:
                Step3bView()

            // PHASE 5: Logistics Last
            case .reminderTiming:
                ReminderTimingView()

            case .step2ReminderFrequency:
                Step2View()

            // PHASE 6: Social Proof & Conversion
            case .step6NotificationPromise:
                Step6View()

            case .notificationPermission:
                NotificationPermissionView()

            case .referralSource:
                ReferralSourceView()

            case .step7SocialProof:
                Step7View()

            case .planReadyTeaser:
                PlanReadyTeaserView()

            case .loadingPlan:
                LoadingPlanView()

            case .personalizedPlan:
                PersonalizedPlanView()

            case .saveYourProgress:
                SaveYourProgressView()

            case .freeTrialIntro:
                FreeTrialIntroView()

            case .freeTrialReminder:
                FreeTrialReminderView()

            case .step6Paywall:
                PaywallStepView()

            case .profileSetupConfirmation:
                ProfileSetupConfirmationView()

            case .preferences:
                Text("Create Profile (TODO)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "f9f9f9"))
            }
        }
        .environmentObject(viewModel)
    }
}
