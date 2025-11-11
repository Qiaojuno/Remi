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
    /// - .signUp: Account creation with family context
    /// - .quiz: Care needs assessment and elderly preference gathering
    /// - .preferences: Notification and communication setup
    /// - .complete: Onboarding finished, ready for elderly profile creation
    @Published var currentStep: OnboardingStep = .signUp
    
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
    
    /// Whether onboarding workflow has been successfully completed
    /// 
    /// Determines if family can proceed to elderly profile creation.
    /// Updated when all onboarding steps are finished and user preferences saved.
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
    /// - .signUp: Requires valid account creation form completion
    /// - .step1WhoFor: Always ready after selection
    /// - .step2Connection: Always ready after selection
    /// - .step3NameRelationship: Always ready after name and relationship entered
    /// - .step4MemoryVision: Requires selected moments
    /// - .step5EmotionalHook: Requires emotional value selection
    /// - .step6Paywall: Always can proceed after selecting plan
    /// - .preferences: Always ready (optional configuration step)
    /// - .complete: Cannot proceed further (terminal step)
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .step1WhoFor:
            return true
        case .step2Connection:
            return true
        case .step3NameRelationship:
            return true
        case .step4MemoryVision:
            return !selectedMoments.isEmpty
        case .step5EmotionalHook:
            return !emotionalValue.isEmpty
        case .saveYourProgress:
            return authService.currentUser != nil // Can proceed after auth
        case .step6Paywall:
            return true // Always can proceed after selecting plan
        case .profileSetupConfirmation:
            return true
        case .signUp:
            return isValidSignUpForm
        case .preferences:
            return true
        case .complete:
            return false
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
    /// Excludes the complete step from calculation as it's a terminal state.
    /// Used for progress bars and completion indicators.
    var progressPercentage: Double {
        let totalSteps = Double(OnboardingStep.allCases.count - 1) // Exclude complete step
        let currentStepIndex = Double(OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0)
        return currentStepIndex / totalSteps
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
    /// Start the quiz flow from welcome screen
    func startQuiz() {
        currentStep = .step1WhoFor
        print("🚀 startQuiz: Starting quiz flow from welcome screen")
    }

    func nextStep() {
        guard canProceed else { return }

        switch currentStep {
        case .welcome:
            // New flow: "Let's get started" button calls startQuiz() directly
            startQuiz()
        case .step1WhoFor:
            currentStep = .step2Connection
            print("🧪 nextStep: Advanced from step 1 to step 2 (Connection)")
        case .step2Connection:
            currentStep = .step3NameRelationship
            print("🧪 nextStep: Advanced from step 2 to step 3 (Name & Relationship)")
        case .step3NameRelationship:
            currentStep = .step4MemoryVision
            print("🧪 nextStep: Advanced from step 3 to step 4 (Memory Vision)")
        case .step4MemoryVision:
            currentStep = .step5EmotionalHook
            print("🧪 nextStep: Advanced from step 4 to step 5 (Emotional Hook)")
        case .step5EmotionalHook:
            currentStep = .saveYourProgress
            print("🧪 nextStep: Advanced from step 5 to Save Your Progress (auth gate)")
        case .saveYourProgress:
            // After auth, proceed to paywall
            currentStep = .step6Paywall
            print("🧪 nextStep: Advanced from Save Your Progress to paywall")
        case .step6Paywall:
            currentStep = .profileSetupConfirmation
            print("🧪 nextStep: Advanced from step 6 to profile setup confirmation")
        case .profileSetupConfirmation:
            currentStep = .preferences
            print("🧪 nextStep: Advanced from profile setup confirmation to preferences")
        case .signUp:
            // Deprecated flow - redirect to quiz
            startQuiz()
        case .preferences:
            // Show CreateProfileView - don't auto-complete
            print("🧪 nextStep: Reached preferences step - should show CreateProfileView")
            break
        case .complete:
            break
        }
    }


    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .step1WhoFor:
            currentStep = .welcome
        case .step2Connection:
            currentStep = .step1WhoFor
        case .step3NameRelationship:
            currentStep = .step2Connection
        case .step4MemoryVision:
            currentStep = .step3NameRelationship
        case .step5EmotionalHook:
            currentStep = .step4MemoryVision
        case .saveYourProgress:
            currentStep = .step5EmotionalHook
        case .step6Paywall:
            currentStep = .saveYourProgress
        case .profileSetupConfirmation:
            currentStep = .step6Paywall
        case .signUp:
            currentStep = .welcome
        case .preferences:
            currentStep = .profileSetupConfirmation
        case .complete:
            currentStep = .preferences
        }
    }
    
    func skipToEnd() {
        currentStep = .complete
        isComplete = true
    }
    
    /// Handle successful authentication and navigation logic
    func handleSuccessfulAuthentication(authResult: AuthResult) async {
        print("🔐 handleSuccessfulAuthentication called for UID: \(authResult.uid)")

        do {
            print("📊 Checking if user exists in database...")

            // Add small delay to ensure Firestore is ready after auth
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Check if user exists in database
            let existingUser = try await databaseService.getUser(authResult.uid)
            print("✅ Database check completed. User found: \(existingUser != nil)")

            if let user = existingUser {
                print("👤 Existing user found. Onboarding complete: \(user.isOnboardingComplete)")

                // Existing user - check if onboarding complete
                if user.isOnboardingComplete {
                    // Already completed onboarding - go to dashboard
                    print("✅ User already completed onboarding, navigating to dashboard")
                    await MainActor.run {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            isComplete = true
                        }
                    }
                } else {
                    // Existing user but incomplete onboarding - continue the flow
                    print("📝 User has incomplete onboarding, continuing quiz flow")
                    // Don't set isComplete - let them continue through the flow
                    // The quiz data is already saved in SaveYourProgressView
                }
            } else {
                // New user signing in during onboarding flow - create User record
                print("🆕 New user detected during onboarding, creating user document...")
                let newUser = User(
                    id: authResult.uid,
                    email: authResult.email ?? "",
                    fullName: authResult.displayName ?? "",
                    phoneNumber: "",
                    createdAt: Date(),
                    isOnboardingComplete: false, // ❌ Still in onboarding (quiz → paywall remaining)
                    subscriptionStatus: .trial,
                    trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                    quizAnswers: userAnswers, // Save quiz answers collected so far
                    profileCount: 0,
                    taskCount: 0,
                    updatedAt: Date(),
                    lastSyncTimestamp: nil
                )
                try? await databaseService.createUser(newUser)
                print("✅ New user document created with incomplete onboarding")

                // Don't set isComplete - let them continue to paywall
            }

            print("🎉 handleSuccessfulAuthentication completed successfully")
        } catch {
            print("❌ Error in handleSuccessfulAuthentication: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")

            await MainActor.run {
                errorMessage = "Failed to complete sign in: \(error.localizedDescription)"
                logger.error("Post-authentication user check failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Profile Setup Actions

    /// Navigate to profile setup after quiz completion
    func proceedToProfileSetup() {
        // Move to preferences step (CreateProfileView)
        currentStep = .preferences
    }

    /// Skip profile setup and go to main app
    func skipProfileSetup() {
        // Mark onboarding as complete and go to main app
        currentStep = .complete
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
                isOnboardingComplete: false, // Requires quiz completion
                subscriptionStatus: .trial, // Full feature access for evaluation
                trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
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
    BUSINESS LOGIC: Onboarding Completion with Elderly Care Personalization
    
    CONTEXT: Families have provided their care context through the assessment quiz.
    This information must be permanently stored to inform all future care
    recommendations, SMS templates, and family coordination features.
    
    DESIGN DECISION: Store quiz answers with user profile for persistent personalization
    - Alternative 1: Separate quiz results table (rejected - adds complexity)
    - Alternative 2: Recalculate preferences each time (rejected - poor performance)  
    - Chosen Solution: Embed quiz answers in user profile for fast access
    
    FAMILY READINESS: Onboarding completion unlocks elderly profile creation,
    SMS confirmation workflow, and care task scheduling. Families are now
    prepared to begin coordinating elderly care with proper context.
    
    PERSONALIZATION: Quiz answers inform default reminder types, SMS language
    style, and care priority recommendations throughout the app experience.
    */
    private func completeOnboarding() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let currentUser = authService.currentUser else {
                throw OnboardingError.userNotFound
            }
            
            // Update user profile with completed onboarding and elderly care personalization
            let updatedUser = User(
                id: currentUser.uid,
                email: email,
                fullName: fullName,
                phoneNumber: phoneNumber,
                createdAt: Date(),
                isOnboardingComplete: true, // Unlocks elderly profile creation
                subscriptionStatus: .trial, // Maintains trial access
                trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                quizAnswers: userAnswers, // Permanent personalization data
                profileCount: 0,
                taskCount: 0,
                updatedAt: Date(),
                lastSyncTimestamp: nil
            )
            
            // Persist family profile with elderly care context
            try await databaseService.updateUser(updatedUser)
            
            // Complete onboarding workflow - ready for elderly care coordination
            currentStep = .complete
            isComplete = true
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Completing onboarding failed: \(error.localizedDescription)")
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

    /// Mark user's onboarding as complete in Firestore after profile creation
    func markOnboardingComplete() async {
        do {
            guard let currentUser = authService.currentUser else {
                print("❌ Cannot mark onboarding complete - no current user")
                return
            }

            // Fetch current user data from database
            guard let user = try await databaseService.getUser(currentUser.uid) else {
                print("❌ Cannot mark onboarding complete - user not found in database")
                return
            }

            // Update user with onboarding complete flag and quiz answers
            let updatedUser = User(
                id: user.id,
                email: user.email,
                fullName: user.fullName,
                phoneNumber: user.phoneNumber,
                createdAt: user.createdAt,
                isOnboardingComplete: true,
                subscriptionStatus: user.subscriptionStatus,
                trialEndDate: user.trialEndDate,
                quizAnswers: userAnswers.isEmpty ? user.quizAnswers : userAnswers,
                profileCount: user.profileCount,
                taskCount: user.taskCount,
                updatedAt: Date(),
                lastSyncTimestamp: user.lastSyncTimestamp
            )

            try await databaseService.updateUser(updatedUser)

            await MainActor.run {
                isComplete = true
                print("✅ User onboarding marked as complete in Firestore")
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                logger.error("Marking onboarding complete failed: \(error.localizedDescription)")
            }
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
        withAnimation(.easeInOut(duration: 0.3)) {
            progress = progressPercentage
        }
    }
    
    // MARK: - Sign In Alternative
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        do {
            let authResult = try await authService.signInWithApple()

            // Delegate to handleSuccessfulAuthentication for consistent logic
            await handleSuccessfulAuthentication(authResult: authResult)

        } catch {
            errorMessage = error.localizedDescription
            logger.error("Apple Sign In failed: \(error.localizedDescription)")
        }

        isLoading = false
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            let authResult = try await authService.signInWithGoogle()

            // Delegate to handleSuccessfulAuthentication for consistent logic
            await handleSuccessfulAuthentication(authResult: authResult)

        } catch {
            errorMessage = error.localizedDescription
            logger.error("Google Sign In failed: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - Onboarding Models
enum OnboardingStep: String, CaseIterable {
    case welcome = "welcome"
    case step1WhoFor = "step1WhoFor"
    case step2Connection = "step2Connection"
    case step3NameRelationship = "step3NameRelationship"
    case step4MemoryVision = "step4MemoryVision"
    case step5EmotionalHook = "step5EmotionalHook"
    case saveYourProgress = "saveYourProgress"  // Auth gate before paywall
    case step6Paywall = "step6Paywall"
    case profileSetupConfirmation = "profileSetupConfirmation"
    case signUp = "signUp"  // Deprecated - kept for backwards compatibility
    case preferences = "preferences"  // Deprecated
    case complete = "complete"

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Remi"
        case .step1WhoFor:
            return "Who For"
        case .step2Connection:
            return "Connection"
        case .step3NameRelationship:
            return "About Them"
        case .step4MemoryVision:
            return "Memory Vision"
        case .step5EmotionalHook:
            return "Emotional Hook"
        case .saveYourProgress:
            return "Save Your Progress"
        case .step6Paywall:
            return "Choose Your Plan"
        case .profileSetupConfirmation:
            return "Profile Setup"
        case .signUp:
            return "Create Account"
        case .preferences:
            return "Preferences"
        case .complete:
            return "You're all set!"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "Create reminders for anyone you love"
        case .step1WhoFor:
            return "Who are you downloading Remi for?"
        case .step2Connection:
            return "How often do you think about them?"
        case .step3NameRelationship:
            return "Tell us about them"
        case .step4MemoryVision:
            return "Select moments to capture"
        case .step5EmotionalHook:
            return "What would these moments mean to you?"
        case .saveYourProgress:
            return "Create an account to save your personalized reminders"
        case .step6Paywall:
            return "Start your personalized memory plan"
        case .profileSetupConfirmation:
            return "Ready to create your first profile?"
        case .signUp:
            return "Create your account to get started"
        case .preferences:
            return "Customize your notification settings"
        case .complete:
            return "Start creating profiles for your elderly family members"
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
