//
//  OnboardingViewModel.swift
//  Hallo
//
//  Purpose: Guides families through first-time setup and elderly care education workflow
//  Key Features: 
//    • Multi-step account creation with elderly care context education
//    • Personalized quiz to understand family care needs and elderly preferences
//    • Onboarding completion tracking with trial subscription activation
//  Dependencies: AuthenticationService, DatabaseService, ErrorCoordinator
//  
//  Business Context: Critical first impression that shapes family understanding of elderly care coordination
//  Critical Paths: Welcome → Account creation → Care needs quiz → Setup completion → Profile creation readiness
//
//  Created by Claude Code on 2025-07-28
//

import Foundation
import SwiftUI
import Combine
import SuperwallKit
import OSLog


/// Guides families through comprehensive onboarding and elderly care education workflow
///
/// This ViewModel manages the critical first-time user experience that introduces families
/// to elderly care coordination concepts, collects essential user information, and prepares
/// them for successful elderly profile creation and SMS reminder management. It serves as
/// the foundation for building family confidence in digital elderly care coordination.
///
/// ## Key Responsibilities:
/// - **Educational Onboarding**: Introduce families to elderly care coordination concepts
/// - **Account Setup**: Secure authentication with email/password or social providers
/// - **Care Needs Assessment**: Personalized quiz to understand family's elderly care context
/// - **Preference Configuration**: Setup notification and communication preferences
/// - **Trial Activation**: Enable 3-day free trial for immediate elderly care access
///
/// ## Elderly Care Considerations:
/// - **Family Education**: Explains SMS confirmation process and elderly user respect
/// - **Realistic Expectations**: Sets appropriate expectations for elderly tech comfort levels
/// - **Care Priority Guidance**: Helps families identify most important reminder types
/// - **Gentle Introduction**: Avoids overwhelming families with complex care concepts
///
/// ## Usage Example:
/// ```swift
/// let onboardingViewModel = container.makeOnboardingViewModel()
/// // User progresses through: Welcome → SignUp → Quiz → Preferences → Complete
/// await onboardingViewModel.nextStep() // Advances through onboarding flow
/// ```
///
/// - Important: Onboarding completion enables elderly profile creation and SMS reminders
/// - Note: Quiz answers inform care recommendations and default reminder configurations
/// - Warning: Incomplete onboarding prevents access to elderly care coordination features
@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Onboarding Flow State Properties
    
    /// Current step in the elderly care onboarding workflow
    /// 
    /// Tracks progression through the educational and setup process:
    /// - .welcome: Introduction to elderly care coordination concepts
    /// - Quiz steps: Care needs assessment and elderly preference gathering
    /// - .saveYourProgress: Authentication gate
    /// - .step6Paywall: Subscription selection
    /// - .preferences: Profile creation view
    @Published var currentStep: OnboardingStep = .welcome
    
    /// Family's responses to elderly care assessment questions
    /// 
    /// Stores quiz answers that inform:
    /// - Recommended reminder types (medication, exercise, social)
    /// - Communication style based on elderly tech comfort
    /// - Family relationship context for appropriate messaging
    /// - Default notification preferences for care coordination
    ///
    /// Used to personalize elderly care recommendations and SMS templates.
    @Published var userAnswers: [String: String] = [:]
    
    /// Loading state for onboarding operations (account creation, data saving)
    /// 
    /// Shows loading during:
    /// - Firebase authentication account creation
    /// - User profile database creation
    /// - Onboarding completion and preference saving
    ///
    /// Used by families to understand when onboarding steps are processing.
    @Published var isLoading = false
    
    /// User-friendly error messages for onboarding failures
    /// 
    /// Displays context-aware error messages for:
    /// - Account creation failures (email conflicts, weak passwords)
    /// - Authentication provider issues (Apple/Google sign-in)
    /// - Network connectivity problems during setup
    ///
    /// Used by families to understand and resolve onboarding obstacles.
    @Published var errorMessage: String?
    
    /// Whether quiz flow has been completed
    ///
    /// ✅ ARCHITECTURE: This is NOT a navigation gate (see ContentView for navigation logic)
    /// This tracks quiz completion for analytics/personalization only
    /// Navigation is controlled by authService.isAuthenticated in ContentView
    @Published var isComplete = false
    
    /// Visual progress indicator for onboarding workflow completion
    /// 
    /// Shows families how much of the setup process remains.
    /// Updates smoothly as users progress through onboarding steps.
    @Published var progress: Double = 0.0
    
    // MARK: - Family Account Creation Properties
    
    /// Email address for family member's Hallo account
    /// 
    /// Used for:
    /// - Firebase authentication and account recovery
    /// - Important notifications about elderly care adherence
    /// - Weekly care summary reports and analytics
    /// - Emergency alerts when elderly tasks are severely overdue
    @Published var email = ""
    
    /// Secure password for family member's account
    /// 
    /// Must meet security requirements for protecting elderly care data:
    /// - Minimum 8 characters with uppercase, lowercase, and numbers
    /// - Protects access to elderly profiles and SMS response history
    /// - Secures family coordination and care adherence information
    @Published var password = ""
    
    /// Password confirmation to prevent account creation errors
    @Published var confirmPassword = ""
    
    /// Full name of family member creating the account
    /// 
    /// Used for:
    /// - Personalizing family care coordination interface
    /// - SMS attribution when family members mark tasks complete
    /// - Care team identification for multi-family coordination
    @Published var fullName = ""
    
    /// Phone number for family member (optional but recommended)
    /// 
    /// Used for:
    /// - Emergency contact when elderly care issues arise
    /// - Two-factor authentication for enhanced account security
    /// - Family coordination when multiple members manage care
    @Published var phoneNumber = ""
    
    // MARK: - Elderly Care Assessment Properties
    

    // MARK: - New Onboarding Flow Properties (Steps 4-6)

    /// Selected moments that the family wants to capture
    ///
    /// Stores the multi-select choices from Step 4 (Memory Vision)
    /// Used to personalize the paywall preview and app experience
    @Published var selectedMoments: Set<String> = []

    /// The emotional value selected by the family
    ///
    /// Stores the selected emotional value from Step 5 (Emotional Hook)
    /// Used for understanding family motivation and personalization
    @Published var emotionalValue: String = ""

    /// The selected subscription plan
    ///
    /// Stores the subscription plan choice from Step 6 (Paywall)
    /// Options: "annual", "monthly", "family"
    @Published var selectedSubscriptionPlan: String = "annual"


    // MARK: - Account Creation Validation Properties
    
    /// Validation error for email address field
    /// 
    /// Shows when email format is invalid or already in use.
    /// Critical for ensuring families can receive elderly care notifications
    /// and account recovery communications.
    @Published var emailError: String?
    
    /// Validation error for password security requirements
    /// 
    /// Shows when password doesn't meet security standards for protecting
    /// elderly care data and family coordination information.
    /// Ensures account security for sensitive care information.
    @Published var passwordError: String?
    
    /// Validation error for phone number format
    /// 
    /// Shows when phone number format is invalid for emergency contact
    /// and two-factor authentication purposes.
    @Published var phoneError: String?
    
    // MARK: - Service Dependencies
    
    /// Authentication service for family account creation and social sign-in
    private let authService: AuthenticationServiceProtocol
    
    /// Database service for user profile creation and onboarding data persistence
    private let databaseService: DatabaseServiceProtocol

    /// Logger for onboarding flow tracking and error diagnosis
    private let logger = Logger(subsystem: "com.halloo.app", category: "Onboarding")

    // MARK: - Internal Onboarding Coordination Properties
    
    /// Combine cancellables for reactive onboarding form validation
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Onboarding Flow Validation Properties
    
    /// Whether family can proceed to the next onboarding step
    ///
    /// Validates step-specific requirements:
    /// - .welcome: Always ready to proceed (introduction step)
    /// - Quiz steps: Validation based on step type (most allow progression)
    /// - .saveYourProgress: Requires authentication
    /// - .step6Paywall: Always can proceed after selecting plan
    /// - .preferences: Always ready (profile creation view)
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .step1WhoFor:
            return true
        case .step2ReminderFrequency:
            return true
        case .step3MedicationProblem:
            return true  // Informational screen - no validation needed
        case .step3bProofScreen:
            return true  // Informational screen - no validation needed
        case .step4HabitFocus:
            return true
        case .step5WhatMatters:
            return true  // Optional question - no validation needed
        case .step6NotificationPromise:
            return true  // Informational screen - no validation needed
        case .notificationPermission:
            return true  // Permission request - no validation needed
        case .personalizedPlan:
            return true  // Summary screen - no validation needed
        case .step7SocialProof:
            return true  // Social proof screen - no validation needed
        case .saveYourProgress:
            return authService.currentUser != nil // Can proceed after auth
        case .step6Paywall:
            return true // Always can proceed after selecting plan
        case .profileSetupConfirmation:
            return true
        case .preferences:
            return true
        }
    }
    
    /// Whether family account creation form meets all requirements
    /// 
    /// Validates that:
    /// - Email is properly formatted and available
    /// - Password meets security requirements for elderly care data protection
    /// - Phone number is valid for emergency contact and 2FA
    /// - All required fields are completed without validation errors
    /// - Password confirmation matches for account security
    var isValidSignUpForm: Bool {
        return !email.isEmpty && 
               !password.isEmpty && 
               !confirmPassword.isEmpty &&
               !fullName.isEmpty &&
               !phoneNumber.isEmpty &&
               emailError == nil && 
               passwordError == nil && 
               phoneError == nil &&
               password == confirmPassword
    }
    
    
    /// Calculated progress percentage for onboarding workflow visualization
    ///
    /// Shows families how much of the setup process remains.
    /// Calculates progress based on actual quiz flow steps (not all enum cases)
    /// Used for progress bars and completion indicators.
    var progressPercentage: Double {
        let totalSteps: Double = 12  // Actual quiz flow steps (notification permission not counted)
        let stepNumber: Double

        switch currentStep {
        case .welcome: stepNumber = 0
        case .step1WhoFor: stepNumber = 1
        case .step2ReminderFrequency: stepNumber = 2
        case .step3MedicationProblem: stepNumber = 3
        case .step4HabitFocus: stepNumber = 4
        case .step3bProofScreen: stepNumber = 5
        case .step5WhatMatters: stepNumber = 6
        case .step6NotificationPromise: stepNumber = 7
        case .notificationPermission: stepNumber = 7  // Same as previous step - not counted
        case .personalizedPlan: stepNumber = 8
        case .step7SocialProof: stepNumber = 9
        case .saveYourProgress: stepNumber = 10
        case .step6Paywall: stepNumber = 11
        case .profileSetupConfirmation: stepNumber = 12
        case .preferences: stepNumber = 12  // Same as profileSetupConfirmation
        }

        return stepNumber / totalSteps
    }
    
    // MARK: - Family Onboarding Setup
    
    /// Initializes onboarding workflow with elderly-care-focused education and validation
    /// 
    /// Sets up the complete infrastructure for guiding families through their first
    /// experience with elderly care coordination. Configures form validation, progress
    /// tracking, and educational workflow to build family confidence in digital care.
    ///
    /// ## Setup Process:
    /// 1. **Service Integration**: Connects authentication and database services
    /// 2. **Form Validation**: Configures real-time validation for account creation
    /// 3. **Progress Tracking**: Sets up visual progress indicators for family feedback
    /// 4. **Educational Flow**: Prepares quiz and preference collection workflows
    /// 5. **Error Handling**: Establishes family-friendly error communication
    ///
    /// - Parameter authService: Handles account creation and social authentication
    /// - Parameter databaseService: Manages user profile creation and quiz data persistence
    init(
        authService: AuthenticationServiceProtocol,
        databaseService: DatabaseServiceProtocol
    ) {
        self.authService = authService
        self.databaseService = databaseService

        // Configure real-time form validation for account security
        setupValidation()

        // Enable visual progress feedback for family confidence
        setupProgressTracking()
    }
    
    // MARK: - Setup Methods
    private func setupValidation() {
        // Email validation
        $email
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] email in
                self?.validateEmail(email)
            }
            .store(in: &cancellables)
        
        // Password validation
        $password
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] password in
                self?.validatePassword(password)
            }
            .store(in: &cancellables)
        
        // Phone validation
        $phoneNumber
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] phone in
                self?.validatePhoneNumber(phone)
            }
            .store(in: &cancellables)
    }
    
    private func setupProgressTracking() {
        $currentStep
            .sink { [weak self] step in
                self?.updateProgress()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Onboarding Flow Navigation
    
    /// Advances family through the next step of elderly care onboarding workflow
    ///
    /// This method orchestrates the progression through onboarding steps, handling
    /// step-specific logic and validation requirements. Each step transition is
    /// designed to build family understanding and confidence in elderly care coordination.
    ///
    /// ## Step Progression:
    /// - **Welcome → SignUp**: Transition from introduction to account creation
    /// - **SignUp → Quiz**: Account creation triggers elderly care assessment
    /// - **Quiz → Preferences**: Completed assessment leads to preference setup
    /// - **Preferences → Complete**: Final setup completion and trial activation
    ///
    /// - Important: Validates step requirements before allowing progression
    /// - Note: Some steps trigger async operations (account creation, completion)
    /// - Warning: Incomplete steps prevent progression to maintain data integrity
    /// Start the quiz flow from welcome screen (Get Started button)
    func startQuiz() {
        currentStep = .step1WhoFor
        updateProgress()
        print("🚀 startQuiz: Starting quiz flow from welcome screen")
    }

    /// Skip quiz and go directly to login (Login button)
    func goToLogin() {
        currentStep = .saveYourProgress // This is the auth gate
        print("🔐 goToLogin: Skipping quiz, going directly to login")
    }

    func nextStep() {
        guard canProceed else { return }

        switch currentStep {
        case .welcome:
            // New flow: "Let's get started" button calls startQuiz() directly
            startQuiz()
        case .step1WhoFor:
            currentStep = .step2ReminderFrequency
            updateProgress()
            print("🧪 nextStep: Advanced from step 1 to step 2 (Reminder Frequency)")
        case .step2ReminderFrequency:
            currentStep = .step3MedicationProblem
            updateProgress()
            print("🧪 nextStep: Advanced from step 2 (Reminder Frequency) to step 3 (Medication Problem)")
        case .step3MedicationProblem:
            currentStep = .step4HabitFocus
            updateProgress()
            print("🧪 nextStep: Advanced from step 3 (Medication Problem) to step 4 (Habit Focus)")
        case .step4HabitFocus:
            currentStep = .step3bProofScreen
            updateProgress()
            print("🧪 nextStep: Advanced from step 4 (Habit Focus) to step 3b (Proof Screen)")
        case .step3bProofScreen:
            currentStep = .step5WhatMatters
            updateProgress()
            print("🧪 nextStep: Advanced from step 3b (Proof) to step 5 (What Matters)")
        case .step5WhatMatters:
            currentStep = .step6NotificationPromise
            updateProgress()
            print("🧪 nextStep: Advanced from step 5 (What Matters) to step 6 (Notification Promise)")
        case .step6NotificationPromise:
            currentStep = .notificationPermission
            updateProgress()
            print("🧪 nextStep: Advanced from step 6 (Notification Promise) to notification permission")
        case .notificationPermission:
            currentStep = .personalizedPlan
            updateProgress()
            print("🧪 nextStep: Advanced from notification permission to personalized plan")
        case .personalizedPlan:
            currentStep = .step7SocialProof
            updateProgress()
            print("🧪 nextStep: Advanced from personalized plan to step 7 (Social Proof)")
        case .step7SocialProof:
            currentStep = .saveYourProgress
            updateProgress()
            print("🧪 nextStep: Advanced from step 7 (Social Proof) to Save Your Progress (auth gate)")
        case .saveYourProgress:
            // After auth, proceed to paywall
            currentStep = .step6Paywall
            updateProgress()
            print("🧪 nextStep: Advanced from Save Your Progress to paywall")
        case .step6Paywall:
            currentStep = .profileSetupConfirmation
            updateProgress()
            print("🧪 nextStep: Advanced from paywall to profile setup confirmation")
        case .profileSetupConfirmation:
            currentStep = .preferences
            updateProgress()
            print("🧪 nextStep: Advanced from profile setup confirmation to preferences")
        case .preferences:
            // Show CreateProfileView - don't auto-complete
            print("🧪 nextStep: Reached preferences step - should show CreateProfileView")
            break
        }
    }


    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .step1WhoFor:
            currentStep = .welcome
            updateProgress()
        case .step2ReminderFrequency:
            currentStep = .step1WhoFor
            updateProgress()
        case .step3MedicationProblem:
            currentStep = .step2ReminderFrequency
            updateProgress()
        case .step4HabitFocus:
            currentStep = .step3MedicationProblem
            updateProgress()
        case .step3bProofScreen:
            currentStep = .step4HabitFocus
            updateProgress()
        case .step5WhatMatters:
            currentStep = .step3bProofScreen
            updateProgress()
        case .step6NotificationPromise:
            currentStep = .step5WhatMatters
            updateProgress()
        case .notificationPermission:
            currentStep = .step6NotificationPromise
            updateProgress()
        case .personalizedPlan:
            currentStep = .step6NotificationPromise  // Skip notification permission screen
            updateProgress()
        case .step7SocialProof:
            currentStep = .personalizedPlan
            updateProgress()
        case .saveYourProgress:
            currentStep = .step7SocialProof
            updateProgress()
        case .step6Paywall:
            currentStep = .saveYourProgress
            updateProgress()
        case .profileSetupConfirmation:
            currentStep = .step6Paywall
            updateProgress()
        case .preferences:
            currentStep = .profileSetupConfirmation
            updateProgress()
        }
    }

    // ✅ REMOVED: handleSuccessfulAuthentication()
    // ARCHITECTURE: ContentView handles navigation via authService.isAuthenticated
    // No need to manage isComplete or navigation state in OnboardingViewModel
    // Firebase creates user document automatically in FirebaseAuthenticationService

    // MARK: - Profile Setup Actions

    /// Navigate to profile setup after quiz completion
    func proceedToProfileSetup() {
        // Move to preferences step (CreateProfileView)
        currentStep = .preferences
    }

    /// Skip profile setup and go to main app
    /// ✅ ARCHITECTURE: isComplete triggers navigation to dashboard via ContentView
    func skipProfileSetup() {
        // Mark onboarding as complete (no need to change currentStep)
        isComplete = true
    }
    
    // MARK: - Family Account Creation & Trial Activation
    
    /*
    BUSINESS LOGIC: Family Account Creation with Elderly Care Trial Access
    
    CONTEXT: Families need immediate access to elderly care coordination features
    to evaluate the app's value. The 3-day trial provides enough time to create
    elderly profiles, send SMS confirmations, and experience care coordination.
    
    DESIGN DECISION: Automatic trial activation upon account creation
    - Alternative 1: Require payment upfront (rejected - prevents evaluation)
    - Alternative 2: Limited free tier (rejected - insufficient for proper trial)  
    - Chosen Solution: Full-featured 3-day trial for comprehensive evaluation
    
    FAMILY ONBOARDING: Account creation immediately enables elderly profile
    creation and SMS confirmation workflow, allowing families to start
    coordinating care within minutes of signing up.
    
    TRIAL STRATEGY: 3 days provides enough time for families to create profiles,
    experience SMS confirmation, set up daily reminders, and see elderly
    response patterns - sufficient for informed subscription decision.
    */
    private func createAccount() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create secure Firebase authentication account
            let authResult = try await authService.createAccount(
                email: email,
                password: password,
                fullName: fullName
            )
            
            // Create family user profile with trial access to elderly care features
            let user = User(
                id: authResult.uid,
                email: email,
                fullName: fullName,
                phoneNumber: phoneNumber,
                createdAt: Date(),
                subscriptionStatus: .trial, // Full feature access for evaluation
                trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                quizAnswers: nil,
                profileCount: 0,
                taskCount: 0,
                updatedAt: Date(),
                lastSyncTimestamp: nil
            )
            
            // Persist family profile for elderly care coordination
            try await databaseService.createUser(user)

            // MVP: Skip onboarding, go straight to dashboard
            isComplete = true
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Creating family account failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Elderly Care Onboarding Completion
    
    /*
    BUSINESS LOGIC: Save Quiz Answers for Personalization (Optional)

    CONTEXT: If user went through quiz funnel, save their answers for personalization.
    This is optional - users can skip quiz entirely and still use the app.

    DESIGN DECISION: Store quiz answers with user profile for persistent personalization
    - Alternative 1: Separate quiz results table (rejected - adds complexity)
    - Alternative 2: Recalculate preferences each time (rejected - poor performance)
    - Chosen Solution: Embed quiz answers in user profile for fast access

    PERSONALIZATION: Quiz answers inform default reminder types, SMS language
    style, and care priority recommendations throughout the app experience.
    */
    private func saveQuizAnswers() async {
        // Only save if quiz was actually completed
        guard !userAnswers.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            guard let currentUser = authService.currentUser else {
                throw OnboardingError.userNotFound
            }

            // Fetch existing user and update only quiz answers
            guard let user = try await databaseService.getUser(currentUser.uid) else {
                throw OnboardingError.userNotFound
            }

            let updatedUser = User(
                id: user.id,
                email: user.email,
                fullName: user.fullName,
                phoneNumber: user.phoneNumber,
                createdAt: user.createdAt,
                subscriptionStatus: user.subscriptionStatus,
                trialEndDate: user.trialEndDate,
                quizAnswers: userAnswers, // Save quiz personalization data
                profileCount: user.profileCount,
                taskCount: user.taskCount,
                updatedAt: Date(),
                lastSyncTimestamp: user.lastSyncTimestamp
            )

            try await databaseService.updateUser(updatedUser)
            print("✅ Quiz answers saved for personalization")

        } catch {
            errorMessage = error.localizedDescription
            logger.error("Saving quiz answers failed: \(error.localizedDescription)")
        }

        isLoading = false
    }
    
    /// Proceed to profile creation after successful paywall interaction
    func proceedAfterPaywall() {
        print("🧪 Proceeding to profile creation after paywall")

        // Show the thank you message first, then proceed to profile setup
        currentStep = .profileSetupConfirmation
        print("🎉 Paywall completed successfully - showing thank you confirmation")
    }

    /// Complete the onboarding flow and navigate to dashboard
    /// NEW ARCHITECTURE: No more "onboarding complete" flag - just go to dashboard
    func completeOnboardingFlow() async {
        // Save quiz answers if collected (optional personalization)
        if !userAnswers.isEmpty {
            await saveQuizAnswers()
        }

        // Navigate to dashboard
        await MainActor.run {
            isComplete = true
            print("✅ Onboarding flow completed - navigating to dashboard")
        }
    }

    // MARK: - Validation Methods
    private func validateEmail(_ email: String) {
        if email.isEmpty {
            emailError = nil
        } else if !email.isValidEmail {
            emailError = "Please enter a valid email address"
        } else {
            emailError = nil
        }
    }
    
    private func validatePassword(_ password: String) {
        if password.isEmpty {
            passwordError = nil
        } else if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
        } else if !password.hasUppercaseLetter || !password.hasLowercaseLetter || !password.hasNumber {
            passwordError = "Password must contain uppercase, lowercase, and number"
        } else {
            passwordError = nil
        }
    }
    
    private func validatePhoneNumber(_ phone: String) {
        if phone.isEmpty {
            phoneError = nil
        } else if !phone.isValidPhoneNumber {
            phoneError = "Please enter a valid phone number"
        } else {
            phoneError = nil
        }
    }
    
    private func updateProgress() {
        withAnimation(.linear(duration: 0.5)) {
            progress = progressPercentage
        }
    }
    
    // MARK: - Sign In Methods
    /// ✅ ARCHITECTURE: Authentication only - no navigation management
    /// ContentView will automatically react to authService.isAuthenticated changes
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        do {
            print("🍎 [OnboardingVM] Starting Apple Sign In...")
            _ = try await authService.signInWithApple()
            print("✅ [OnboardingVM] Apple Sign In successful - authService will trigger navigation")
            // ✅ No navigation logic needed - ContentView reacts to authService.isAuthenticated

        } catch {
            print("❌ [OnboardingVM] Apple Sign In failed: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                logger.error("Apple Sign In failed: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            print("🔐 [OnboardingVM] Starting Google Sign In...")
            _ = try await authService.signInWithGoogle()
            print("✅ [OnboardingVM] Google Sign In successful - authService will trigger navigation")
            // ✅ No navigation logic needed - ContentView reacts to authService.isAuthenticated

        } catch {
            print("❌ [OnboardingVM] Google Sign In failed: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                logger.error("Google Sign In failed: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Onboarding Models
/// ✅ CLEANED UP: Removed deprecated enum cases (not persisted, safe to remove)
enum OnboardingStep: String, CaseIterable {
    case welcome = "welcome"
    case step1WhoFor = "step1WhoFor"
    case step2ReminderFrequency = "step2ReminderFrequency"
    case step3MedicationProblem = "step3MedicationProblem"
    case step3bProofScreen = "step3bProofScreen"
    case step4HabitFocus = "step4HabitFocus"
    case step5WhatMatters = "step5WhatMatters"
    case step6NotificationPromise = "step6NotificationPromise"
    case notificationPermission = "notificationPermission"
    case loadingPlan = "loadingPlan"  // Loading screen with progress
    case personalizedPlan = "personalizedPlan"  // Summary of quiz answers
    case step7SocialProof = "step7SocialProof"
    case saveYourProgress = "saveYourProgress"  // Auth gate
    case step6Paywall = "step6Paywall"
    case profileSetupConfirmation = "profileSetupConfirmation"
    case preferences = "preferences"  // Profile creation view

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Remi"
        case .step1WhoFor:
            return "Who For"
        case .step2ReminderFrequency:
            return "Reminder Frequency"
        case .step3MedicationProblem:
            return "Medication Problem"
        case .step3bProofScreen:
            return "Proof Screen"
        case .step4HabitFocus:
            return "Habit Focus"
        case .step5WhatMatters:
            return "What Matters"
        case .step6NotificationPromise:
            return "Stay Informed"
        case .notificationPermission:
            return "Notifications"
        case .loadingPlan:
            return "Building Your Plan"
        case .personalizedPlan:
            return "Your Summary"
        case .step7SocialProof:
            return "Social Proof"
        case .saveYourProgress:
            return "Save Your Progress"
        case .step6Paywall:
            return "Choose Your Plan"
        case .profileSetupConfirmation:
            return "Profile Setup"
        case .preferences:
            return "Preferences"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "Create reminders for anyone you love"
        case .step1WhoFor:
            return "Who are you downloading Remi for?"
        case .step2ReminderFrequency:
            return "How often do they need reminders?"
        case .step3MedicationProblem:
            return "The medication adherence crisis"
        case .step3bProofScreen:
            return "Proof screen"
        case .step4HabitFocus:
            return "What would you like to remind them about?"
        case .step5WhatMatters:
            return "What matters most to you"
        case .step6NotificationPromise:
            return "Remi keeps you in the loop"
        case .notificationPermission:
            return "Never miss a moment"
        case .loadingPlan:
            return "Analyzing your answers"
        case .personalizedPlan:
            return "See your personalized reminder strategy"
        case .step7SocialProof:
            return "Families everywhere use Remi"
        case .saveYourProgress:
            return "Create an account to save your personalized reminders"
        case .step6Paywall:
            return "Start your personalized memory plan"
        case .profileSetupConfirmation:
            return "Ready to create your first profile?"
        case .preferences:
            return "Customize your notification settings"
        }
    }
}

struct QuizQuestion {
    let id: String
    var question: String
    let options: [String]
    let helpText: String?
    
    init(id: String, question: String, options: [String], helpText: String? = nil) {
        self.id = id
        self.question = question
        self.options = options
        self.helpText = helpText
    }
}


// MARK: - Onboarding Errors
enum OnboardingError: LocalizedError {
    case userNotFound
    case incompleteData
    case quizNotCompleted
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User session not found. Please try signing in again."
        case .incompleteData:
            return "Please complete all required fields."
        case .quizNotCompleted:
            return "Please complete the setup quiz before proceeding."
        }
    }
}
