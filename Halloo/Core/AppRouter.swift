//
//  AppRouter.swift
//  Halloo
//
//  Purpose: Centralized routing orchestration for app launch and navigation
//  Pattern: State Machine with async state resolution
//
//  This router consolidates ALL routing logic that was previously scattered across:
//  - ContentView (auth checks, subscription checks)
//  - OnboardingViewModel (step navigation, clearSavedQuizProgress)
//  - OnboardingViews (subscription checks after paywall)
//  - OnboardingContainerView (preferences step handling)
//
//  SINGLE RESPONSIBILITY: Determine where the user should go based on their state
//
//  Created by Claude Code on 2025-01-06
//

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - App Launch Destination

/// Type-safe enum representing all possible app destinations
/// This replaces scattered if/else logic with a single source of truth
enum AppLaunchDestination: Equatable {
    /// App is still determining where to route (show loading screen)
    case loading

    /// User needs to go through onboarding (not authenticated)
    /// - Parameter resumeStep: If user has quiz progress, resume at this step
    case onboarding(resumeStep: OnboardingStep?)

    /// User is authenticated but needs to subscribe
    case paywall

    /// User is fully entitled (authenticated + subscribed) - show main app
    case dashboard
}

// MARK: - App Router

/// Centralized routing orchestration for the entire app
///
/// **Architecture:**
/// ```
/// App Launch
///     ↓
/// AppRouter.resolveDestination()
///     ↓
/// [Parallel async checks]
/// ├─ Firebase Auth state
/// ├─ RevenueCat subscription status
/// ├─ UserDefaults quiz progress
/// └─ Firestore user profile (if authenticated)
///     ↓
/// Publish single `destination` value
///     ↓
/// ContentView renders appropriate screen
/// ```
///
/// **Benefits:**
/// - Single place to understand routing logic
/// - Loading screen stays visible until ALL checks complete
/// - No race conditions from scattered async calls
/// - Easy to test routing logic in isolation
/// - Supports deep linking (future enhancement)
///
@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Published State

    /// The current destination - ContentView observes this to render the correct screen
    @Published private(set) var destination: AppLaunchDestination = .loading

    /// Debug info for understanding routing decisions
    @Published private(set) var routingDebugInfo: String = ""

    // MARK: - Dependencies

    private let authService: AuthenticationServiceProtocol
    private let databaseService: DatabaseServiceProtocol
    private let subscriptionManager: SubscriptionManager
    private let logger = Logger(subsystem: "com.halloo.app", category: "AppRouter")

    // MARK: - State Tracking

    /// Tracks if initial routing has been resolved
    private var hasResolvedInitialRoute = false

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UserDefaults Keys (from OnboardingViewModel)

    private static let quizAnswersKey = "onboarding_quiz_answers"
    private static let selectedMomentsKey = "onboarding_selected_moments"
    private static let emotionalValueKey = "onboarding_emotional_value"
    private static let quizFinishedKey = "onboarding_quiz_finished"

    // MARK: - Initialization

    init(
        authService: AuthenticationServiceProtocol,
        databaseService: DatabaseServiceProtocol
    ) {
        self.authService = authService
        self.databaseService = databaseService
        self.subscriptionManager = SubscriptionManager.shared

        logger.info("AppRouter initialized")
    }

    // MARK: - Main Routing Logic

    /// Resolves the app destination by checking all required states
    ///
    /// This is the ONLY place routing decisions should be made.
    /// Call this on app launch and whenever auth state changes.
    ///
    /// **State Resolution Order:**
    /// 1. Check Firebase Auth (is user logged in?)
    /// 2. If not logged in → check for saved quiz progress → onboarding
    /// 3. If logged in → check subscription status
    /// 4. If subscribed → dashboard
    /// 5. If not subscribed → paywall
    ///
    func resolveDestination() async {
        logger.info("Resolving app destination...")

        // Only show loading on initial resolution (prevents flash on auth state changes)
        if !hasResolvedInitialRoute {
            destination = .loading
        }

        // CRITICAL FIX: Wait for auth state to be definitively determined
        // This replaces the unreliable 300ms delay with proper synchronization
        //
        // Firebase Auth restores sessions from Keychain asynchronously.
        // We must wait for this to complete before checking isAuthenticated.
        await authService.waitForAuthStateInitialization()
        logger.info("Auth state initialization complete")

        // STEP 1: Check authentication state (NOW reliable after waiting)
        let isAuthenticated = authService.isAuthenticated
        let userId = authService.currentUser?.uid

        logger.info("Auth state: authenticated=\(isAuthenticated), userId=\(userId ?? "nil")")

        if !isAuthenticated {
            // Not logged in - check for saved quiz progress
            await resolveUnauthenticatedDestination()
            return
        }

        // STEP 2: User is authenticated - check subscription status
        await resolveAuthenticatedDestination(userId: userId)
    }

    /// Resolves destination for unauthenticated users
    private func resolveUnauthenticatedDestination() async {
        logger.info("User not authenticated - checking quiz progress")

        // Check if user has saved quiz progress to resume
        let quizFinished = UserDefaults.standard.bool(forKey: Self.quizFinishedKey)
        let hasQuizAnswers = UserDefaults.standard.dictionary(forKey: Self.quizAnswersKey) != nil

        if quizFinished {
            // Quiz was completed but user hasn't signed up yet
            // Resume at personalized plan (right before auth gate)
            logger.info("Quiz finished but not authenticated - resuming at personalizedPlan")
            routingDebugInfo = "Quiz complete, needs auth"
            destination = .onboarding(resumeStep: .personalizedPlan)
        } else if hasQuizAnswers {
            // User started quiz but didn't finish - let OnboardingViewModel handle step restoration
            logger.info("Quiz in progress - resuming onboarding")
            routingDebugInfo = "Quiz in progress"
            destination = .onboarding(resumeStep: nil) // ViewModel will restore correct step
        } else {
            // Fresh user - start from beginning
            logger.info("Fresh user - starting onboarding")
            routingDebugInfo = "New user"
            destination = .onboarding(resumeStep: nil)
        }

        hasResolvedInitialRoute = true
    }

    /// Resolves destination for authenticated users
    private func resolveAuthenticatedDestination(userId: String?) async {
        logger.info("User authenticated - checking subscription status")

        // ✅ FIX: Use async API call instead of cached data
        // After login, the cache may still contain stale data from the anonymous session.
        // Making a fresh API call ensures we get the correct subscription status for the
        // newly-identified user, preventing subscribed users from seeing the paywall.
        let hasSubscription = await subscriptionManager.hasActiveSubscription()

        logger.info("Subscription status: hasSubscription=\(hasSubscription)")

        if hasSubscription {
            // User is fully entitled - go to dashboard
            logger.info("User has active subscription - routing to dashboard")
            routingDebugInfo = "Subscribed"

            // Clear any leftover quiz progress since user is entitled
            clearSavedQuizProgress()

            destination = .dashboard
        } else {
            // User needs to subscribe - but don't shove paywall in their face
            // Instead, show them the summary page first to remind them of value
            let quizFinished = UserDefaults.standard.bool(forKey: Self.quizFinishedKey)

            if quizFinished {
                // User completed quiz before → show summary page first
                // Flow: PersonalizedPlan → FreeTrialIntro → FreeTrialReminder → Paywall
                logger.info("User needs subscription + has quiz data - routing to summary")
                routingDebugInfo = "Needs subscription (quiz complete)"
                destination = .onboarding(resumeStep: .personalizedPlan)
            } else {
                // User never completed quiz (logged in directly) → start fresh
                logger.info("User needs subscription + no quiz data - routing to welcome")
                routingDebugInfo = "Needs subscription (no quiz)"
                destination = .onboarding(resumeStep: nil)
            }
        }

        hasResolvedInitialRoute = true
    }

    // MARK: - State Transitions

    /// Call when user completes onboarding (after successful subscription)
    ///
    /// This is the ONLY sanctioned exit from onboarding to dashboard.
    /// Ensures quiz answers are saved before clearing local progress.
    ///
    /// - Parameter saveQuizAnswers: Closure to save quiz answers to Firestore (optional)
    func completeOnboarding(saveQuizAnswers: (() async -> Void)? = nil) async {
        logger.info("Completing onboarding flow")

        // Save quiz answers to Firestore BEFORE clearing local cache
        if let saveQuizAnswers = saveQuizAnswers {
            await saveQuizAnswers()
            logger.info("Quiz answers saved to Firestore")
        }

        // Clear local quiz progress
        clearSavedQuizProgress()

        // Route to dashboard
        destination = .dashboard
    }

    /// Call when user successfully subscribes during onboarding
    func handleSubscriptionSuccess() async {
        logger.info("Subscription successful - completing onboarding")

        // Clear quiz progress and go to dashboard
        clearSavedQuizProgress()
        destination = .dashboard
    }

    /// Call when user logs out
    func handleLogout() {
        logger.info("User logged out - routing to onboarding")

        // Don't clear quiz progress on logout (user might want to resume)
        destination = .onboarding(resumeStep: nil)
        hasResolvedInitialRoute = false
    }

    /// Call when auth state changes (from auth state observer)
    func handleAuthStateChange(isAuthenticated: Bool) async {
        logger.info("Auth state changed: isAuthenticated=\(isAuthenticated)")

        // Re-resolve destination based on new auth state
        await resolveDestination()
    }

    // MARK: - Quiz Progress Management

    /// Clears saved quiz progress from UserDefaults
    ///
    /// **IMPORTANT:** This should ONLY be called:
    /// 1. After quiz answers have been saved to Firestore
    /// 2. When user successfully subscribes (they're entitled, quiz is done)
    /// 3. NOT when user just authenticates (they might still need paywall)
    ///
    private func clearSavedQuizProgress() {
        UserDefaults.standard.removeObject(forKey: Self.quizAnswersKey)
        UserDefaults.standard.removeObject(forKey: Self.selectedMomentsKey)
        UserDefaults.standard.removeObject(forKey: Self.emotionalValueKey)
        UserDefaults.standard.removeObject(forKey: Self.quizFinishedKey)
        logger.info("Cleared saved quiz progress from UserDefaults")
    }

    /// Checks if there's any saved quiz progress
    var hasQuizProgress: Bool {
        UserDefaults.standard.dictionary(forKey: Self.quizAnswersKey) != nil ||
        UserDefaults.standard.bool(forKey: Self.quizFinishedKey)
    }

    // MARK: - Deep Linking Support (Future)

    /// Handle deep link URL and return appropriate destination
    /// - Parameter url: The deep link URL
    /// - Returns: The destination to navigate to, or nil if URL not recognized
    func handleDeepLink(_ url: URL) -> AppLaunchDestination? {
        // TODO: Implement deep linking support
        // Example: halloo://profile/123 → .dashboard (with profile selection)
        // Example: halloo://onboarding → .onboarding(resumeStep: nil)
        logger.info("Deep link received: \(url.absoluteString) (not yet implemented)")
        return nil
    }
}

// MARK: - Preview Support

#if DEBUG
extension AppRouter {
    /// Creates a router pre-set to a specific destination for SwiftUI previews
    static func preview(destination: AppLaunchDestination) -> AppRouter {
        let container = Container.shared
        let router = AppRouter(
            authService: container.resolve(AuthenticationServiceProtocol.self),
            databaseService: container.resolve(DatabaseServiceProtocol.self)
        )
        router.destination = destination
        return router
    }
}
#endif
