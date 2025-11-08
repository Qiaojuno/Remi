//
//  ProfileViewModel.swift
//  Hallo
//
//  Purpose: Manages elderly profile creation and SMS confirmation workflow for family coordination
//  Key Features: 
//    • Elderly profile lifecycle management (create, edit, confirmation)
//    • SMS confirmation workflow with YES/NO response processing
//    • Real-time family synchronization across devices
//  Dependencies: DatabaseService, SMSService, AuthenticationService, DataSyncCoordinator
//  
//  Business Context: Critical bridge between families and elderly users via SMS confirmation
//  Critical Paths: Profile creation → SMS confirmation → Profile activation → Task scheduling readiness
//
//  Created by Claude Code on 2025-07-28
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// Manages elderly profile creation, SMS confirmation, and family coordination workflow
///
/// This ViewModel handles the critical onboarding process for elderly family members,
/// managing their profiles from initial creation through SMS confirmation to active
/// status. It serves as the gateway that determines whether elderly users can receive
/// daily care reminders and task notifications.
///
/// ## Key Responsibilities:
/// - **Profile Lifecycle Management**: Create, edit, and maintain elderly family member profiles
/// - **SMS Confirmation Orchestration**: Send confirmation texts and process YES/NO responses  
/// - **Family Coordination**: Sync profile changes across all family member devices
/// - **Validation & Security**: Ensure profile data integrity and prevent SMS abuse
/// - **Status Tracking**: Monitor confirmation states and profile readiness for task creation
///
/// ## Elderly Care Considerations:
/// - **Simple Confirmation Process**: Clear YES/NO SMS confirmation without complex steps
/// - **Patient Response Handling**: Accommodates delayed responses from elderly users
/// - **Multiple Retry Options**: Allows resending confirmation SMS if needed
/// - **Clear Status Communication**: Shows families exactly where each profile stands
///
/// ## Usage Example:
/// ```swift
/// let profileViewModel = container.makeProfileViewModel()
/// profileViewModel.profileName = "Grandma Rose"
/// profileViewModel.phoneNumber = "+1234567890"
/// profileViewModel.relationship = "Grandmother"
/// await profileViewModel.createProfile() // Sends SMS confirmation automatically
/// ```
///
/// - Important: Profiles must be SMS-confirmed before they can receive task reminders
/// - Note: Maximum 4 profiles per family user to prevent SMS overwhelming
/// - Warning: Phone number changes require re-confirmation via new SMS
@MainActor
final class ProfileViewModel: ObservableObject, AppStateViewModel {
    
    // MARK: - Profile Management Properties
    
    // PHASE 4: MIGRATING to AppState.profiles
    // Computed property that reads from AppState (single source of truth)
    // TODO Phase 5: Update all views to read directly from @EnvironmentObject AppState
    var profiles: [ElderlyProfile] {
        appState?.profiles ?? []
    }
    
    /// Loading state for profile operations (create, update, SMS sending)
    /// 
    /// This property shows loading during:
    /// - Profile creation and database storage
    /// - SMS confirmation message delivery
    /// - Profile updates and family synchronization
    ///
    /// Used by families to provide feedback during profile management operations.
    @Published var isLoading = false
    
    /// User-friendly error messages for profile-related failures
    /// 
    /// This property displays context-aware error messages when:
    /// - Profile creation fails (validation, network, SMS delivery)
    /// - Maximum profile limit is reached (4 per family)
    /// - Phone number conflicts or SMS confirmation issues
    ///
    /// Used by families to understand and resolve profile setup issues.
    @Published var errorMessage: String?
    
    /// Debug information for tracking profile creation flow
    @Published var debugInfo: String = ""
    
    /// Controls profile creation form presentation
    @Published var showingCreateProfile = false
    
    /// Controls profile editing form presentation  
    @Published var showingEditProfile = false
    
    /// Currently selected profile for editing or viewing details
    @Published var selectedProfile: ElderlyProfile?
    
    // MARK: - Profile Creation Form Properties
    
    /// Elderly family member's name as it will appear in SMS reminders
    /// 
    /// Should be the name the elderly person recognizes and responds to.
    /// Examples: "Grandma Rose", "Dad", "Mom Smith", "Uncle Bob"
    /// Used in SMS messages like "Hello Grandma Rose! Time for your medication."
    @Published var profileName = ""
    
    /// Phone number where elderly family member will receive SMS reminders
    /// 
    /// Must be a valid phone number that the elderly person actively uses.
    /// Automatically formatted and validated for SMS delivery compatibility.
    /// This is the primary contact method for all daily care reminders.
    @Published var phoneNumber = ""
    
    /// Relationship to the elderly family member for family context
    /// 
    /// Helps families organize and identify profiles in their dashboard.
    /// Options: Parent, Grandparent, Aunt, Uncle, Other Family Member
    /// Used for UI organization and emergency contact prioritization.
    @Published var relationship = ""
    
    /// Whether this elderly profile should be contacted in emergencies
    /// 
    /// Determines priority order when multiple family members need notification.
    /// Emergency contacts receive immediate alerts for missed critical tasks
    /// like medication reminders or safety checks.
    @Published var isEmergencyContact = false
    
    /// Time zone of the elderly family member for accurate reminder scheduling
    /// 
    /// Ensures SMS reminders are sent at appropriate local times.
    /// Prevents early morning or late night messages that could cause confusion.
    /// Critical for medication timing and daily routine alignment.
    @Published var timeZone = TimeZone.current
    
    /// Additional notes about the elderly family member for care context
    /// 
    /// Used by families to share important information:
    /// - "Prefers calls after 9 AM"
    /// - "Has difficulty with complex instructions"
    /// - "Lives with caregiver on weekdays"
    @Published var notes = ""
    
    // MARK: - Form Validation Properties
    
    /// Validation error for profile name field
    /// 
    /// Shows when name is too short, too long, or inappropriate for elderly SMS.
    /// Helps families create recognizable names that elderly users will understand.
    @Published var nameError: String?
    
    /// Validation error for phone number field
    /// 
    /// Shows when:
    /// - Phone number format is invalid for SMS delivery
    /// - Phone number is already used by another profile
    /// - Number appears to be disconnected or unreachable
    @Published var phoneError: String?
    
    /// Validation error for relationship field
    /// 
    /// Shows when relationship selection is invalid or missing.
    /// Ensures proper family organization and emergency contact setup.
    @Published var relationshipError: String?
    
    /// Track if user has started typing in phone field to control validation display
    @Published var hasStartedTypingPhone = false
    
    // MARK: - SMS Confirmation Tracking Properties
    
    /// Current SMS confirmation status for each elderly profile
    /// 
    /// Tracks the progression of SMS confirmation workflow:
    /// - .pending: Profile created, SMS not yet sent
    /// - .sent: Confirmation SMS delivered to elderly person
    /// - .confirmed: Elderly person replied YES, profile active
    /// - .declined: Elderly person replied NO or STOP
    /// - .failed: SMS delivery failed, needs retry
    ///
    /// Used by families to understand which profiles are ready for task creation.
    @Published var confirmationStatus: [String: ConfirmationStatus] = [:]
    
    /// User-friendly status messages for each profile's confirmation process
    /// 
    /// Provides families with clear feedback about SMS confirmation progress:
    /// - "Confirmation SMS sent! Waiting for response."
    /// - "Confirmed! Ready to receive reminders."
    /// - "Declined. No reminders will be sent."
    ///
    /// Updated in real-time as elderly users respond to SMS confirmations.
    @Published var confirmationMessages: [String: String] = [:]
    
    // MARK: - Service Dependencies
    
    /// Database service for profile persistence and family synchronization
    private let databaseService: DatabaseServiceProtocol
    
    /// SMS service for sending confirmation messages to elderly family members
    private let smsService: SMSServiceProtocol
    
    /// Authentication service for family user context and permissions
    private let authService: AuthenticationServiceProtocol
    
    /// Coordinator for real-time profile sync across family member devices
    private let dataSyncCoordinator: DataSyncCoordinator
    
    /// Public access to data sync coordinator for SwiftUI onReceive publishers
    /// 
    /// Allows views to subscribe to real-time SMS responses and profile updates
    /// during onboarding flow for immediate UI feedback.
    var dataSyncPublisher: DataSyncCoordinator {
        dataSyncCoordinator
    }
    
    /// Logger for profile operations tracking and error diagnosis
    private let logger = Logger(subsystem: "com.halloo.app", category: "Profile")

    /// PHASE 2: AppState reference for write consolidation
    /// - Injected after initialization by ContentView
    /// - Used to update centralized state instead of local @Published arrays
    weak var appState: AppState?

    /// Tracks which profiles have had gallery events created to prevent duplicates
    /// - Key: profileId
    /// - Used to ensure gallery event is only created once per profile, even when
    ///   old SMS confirmations are replayed by the real-time listener
    private var profilesWithGalleryEvents = Set<String>()

    // MARK: - Internal Coordination Properties
    
    /// Combine cancellables for reactive elderly profile coordination
    private var cancellables = Set<AnyCancellable>()
    
    /// Maximum profiles per family user to prevent SMS overwhelming
    /// 
    /// Protects elderly users from receiving too many different reminder sources.
    /// Research shows elderly users respond best to consistent, limited contacts.
    /// This limit ensures families focus on essential elderly family members.
    private let maxProfiles = 4
    
    // MARK: - Family Care Validation Properties
    
    /// Whether the family can create additional elderly profiles
    /// 
    /// Protects both families and elderly users by enforcing the 4-profile limit.
    /// This ensures elderly users don't receive overwhelming numbers of reminders
    /// and families can focus on their most important elderly relationships.
    var canCreateProfile: Bool {
        profiles.count < maxProfiles
    }
    
    /// Whether the profile creation form has valid elderly-appropriate data
    /// 
    /// Validates that:
    /// - Profile name is clear and recognizable to elderly user
    /// - Phone number is valid and deliverable for SMS
    /// - Relationship is properly selected for family organization
    /// - All validation errors are resolved
    var isValidForm: Bool {
        // Simplified validation for SimplifiedProfileCreationView
        // Only require name and phone - relationship defaults to "Family Member"
        // Photo is optional despite the comment saying "required"
        return !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !phoneNumber.isEmpty &&
               phoneNumber != "+1 " && // Must be more than just the prefix
               nameError == nil &&
               phoneError == nil
    }
    
    /// Returns missing requirements for form validation
    var missingRequirements: [String] {
        var missing: [String] = []

        if profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Name")
        }
        if phoneNumber.isEmpty || phoneNumber == "+1 " {
            missing.append("Phone Number")
        }
        // Relationship and photo are optional for SimplifiedProfileCreationView
        // They will be set to defaults if not provided
        if nameError != nil {
            missing.append("Valid Name")
        }
        if phoneError != nil {
            missing.append("Valid Phone Number")
        }

        return missing
    }
    
    /// Profiles that have confirmed SMS consent and can receive task reminders
    /// 
    /// These are elderly family members who responded YES to confirmation SMS.
    /// Only confirmed profiles can receive daily care reminders and task notifications.
    /// Used by TaskViewModel to determine valid profile options for task creation.
    var activeProfiles: [ElderlyProfile] {
        profiles.filter { $0.status == .confirmed }
    }
    
    /// Profiles waiting for SMS confirmation from elderly family members
    /// 
    /// These profiles have been created but the elderly person hasn't yet responded
    /// YES to the confirmation SMS. Families can resend confirmations if needed.
    /// Used to show families which profiles still need elderly user consent.
    var pendingProfiles: [ElderlyProfile] {
        profiles.filter { $0.status == .pendingConfirmation }
    }
    
    /// Available relationship options for elderly family member classification
    /// 
    /// Provides standardized relationship categories that help families organize
    /// their elderly profiles and prioritize emergency contacts appropriately.
    /// Used in profile creation and editing forms.
    var relationshipOptions: [String] {
        ["Parent", "Grandparent", "Aunt", "Uncle", "Other Family Member"]
    }
    
    // MARK: - Elderly Profile Management Setup
    
    /// Initializes profile management with elderly-care-optimized services and SMS coordination
    /// 
    /// Sets up the complete infrastructure for managing elderly family member profiles
    /// from creation through SMS confirmation to active task-ready status. Configures
    /// real-time family synchronization and robust SMS confirmation workflow.
    ///
    /// ## Setup Process:
    /// 1. **Service Integration**: Connects database, SMS, and authentication services
    /// 2. **Family Coordination**: Establishes real-time sync across family devices
    /// 3. **Validation Setup**: Configures elderly-friendly form validation
    /// 4. **Data Loading**: Loads existing profiles with confirmation status
    /// 5. **SMS Monitoring**: Prepares to handle confirmation responses
    ///
    /// - Parameter databaseService: Handles profile persistence and family synchronization
    /// - Parameter smsService: Manages SMS confirmations to elderly family members
    /// - Parameter authService: Provides family user context and permissions
    /// - Parameter dataSyncCoordinator: Synchronizes profile data across family members
    init(
        databaseService: DatabaseServiceProtocol,
        smsService: SMSServiceProtocol,
        authService: AuthenticationServiceProtocol,
        dataSyncCoordinator: DataSyncCoordinator
    ) {
        logger.info("ProfileViewModel.init START")

        self.databaseService = databaseService
        self.smsService = smsService
        self.authService = authService
        self.dataSyncCoordinator = dataSyncCoordinator

        // Configure elderly-appropriate validation
        setupValidation()

        // Enable real-time family and SMS synchronization
        setupDataSync()

        // NOTE: loadProfiles() is called explicitly in ContentView after ViewModel creation
        // to avoid crashes from async work during init
    }
    
    /// Convenience initializer for Canvas previews that skips automatic data loading
    /// 
    /// This initializer prevents the stuck loading state in Canvas previews by skipping
    /// the automatic `loadProfiles()` call during initialization.
    init(
        databaseService: DatabaseServiceProtocol,
        smsService: SMSServiceProtocol,
        authService: AuthenticationServiceProtocol,
        dataSyncCoordinator: DataSyncCoordinator,
        skipAutoLoad: Bool = false
    ) {
        self.databaseService = databaseService
        self.smsService = smsService
        self.authService = authService
        self.dataSyncCoordinator = dataSyncCoordinator

        // Configure elderly-appropriate validation
        setupValidation()

        // Enable real-time family and SMS synchronization
        setupDataSync()

        // Skip automatic loading for Canvas previews
        if !skipAutoLoad {
            loadProfiles()
        }
    }

    deinit {
        print("💀 [ProfileViewModel] DEINIT CALLED - ProfileViewModel is being deallocated!")
        print("   - Cancellables count: \(cancellables.count)")
    }

    // MARK: - AppState Injection (Phase 2)

    /// Sets the AppState reference for write consolidation
    /// Called by ContentView after ProfileViewModel initialization
    func setAppState(_ appState: AppState) {
        self.appState = appState
        print("✅ [ProfileViewModel] AppState reference injected")

        // Populate profilesWithGalleryEvents Set from existing gallery events
        // This prevents duplicate gallery events when app relaunches and SMS listener replays old confirmations
        populateGalleryEventTrackingSet(from: appState.galleryEvents)
    }

    /// Populate the duplicate prevention Set from existing gallery events
    ///
    /// When the app relaunches, the profilesWithGalleryEvents Set is empty (it's not persisted).
    /// This method rebuilds the Set from existing gallery events to prevent duplicates when
    /// the SMS listener replays historical confirmation messages.
    ///
    /// **Called by:**
    /// - setAppState() during ProfileViewModel initialization (may be empty if data not loaded yet)
    /// - ContentView after appState.loadUserData() completes (ensures Set is up-to-date)
    ///
    /// - Parameter existingEvents: Array of gallery events from AppState
    func populateGalleryEventTrackingSet(from existingEvents: [GalleryHistoryEvent]) {
        let profileCreatedEvents = existingEvents.filter { $0.eventType == .profileCreated }
        profilesWithGalleryEvents = Set(profileCreatedEvents.map { $0.profileId })

        print("✅ [ProfileViewModel] Populated gallery event tracking set with \(profilesWithGalleryEvents.count) profile IDs")
        if !profilesWithGalleryEvents.isEmpty {
            print("   Profile IDs with gallery events: \(profilesWithGalleryEvents)")
        }
    }

    // MARK: - Setup Methods
    private func setupValidation() {
        // Name validation
        $profileName
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] name in
                self?.validateName(name)
            }
            .store(in: &cancellables)
        
        // Phone validation
        $phoneNumber
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] phone in
                self?.validatePhoneNumber(phone)
            }
            .store(in: &cancellables)
        
        // Relationship validation
        $relationship
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] relationship in
                self?.validateRelationship(relationship)
            }
            .store(in: &cancellables)
    }
    
    private func setupDataSync() {
        // Listen for profile updates from other family members
        let profileUpdatesCancellable = dataSyncCoordinator.profileUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedProfile in
                print("📩 [ProfileViewModel] Received profile update: \(updatedProfile.id)")
                self?.handleProfileUpdate(updatedProfile)
            }
        cancellables.insert(profileUpdatesCancellable)

        // Listen for SMS confirmation responses
        let smsPublisher = dataSyncCoordinator.smsResponses

        let smsCancellable = smsPublisher
            .compactMap { (response: SMSResponse) -> SMSResponse? in
                // Filter for confirmation responses
                guard response.isConfirmationResponse else {
                    return nil
                }
                return response
            }
            .sink { [weak self] (response: SMSResponse) in
                // Ensure UI updates happen on main thread
                DispatchQueue.main.async {
                    self?.handleConfirmationResponse(response)
                }
            }
        cancellables.insert(smsCancellable)

        // Listen for gallery event updates to keep the duplicate prevention Set in sync
        let galleryCancellable = dataSyncCoordinator.galleryEventUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                // When a new gallery event is created, add its profileId to the Set
                if event.eventType == .profileCreated {
                    self?.profilesWithGalleryEvents.insert(event.profileId)
                    print("🔵 [ProfileViewModel] Added profile \(event.profileId) to gallery event tracking set (now has \(self?.profilesWithGalleryEvents.count ?? 0) profiles)")
                }
            }
        cancellables.insert(galleryCancellable)
    }
    
    // PHASE 4: loadProfiles() is now a no-op - AppState.loadUserData() handles all data loading
    // ContentView calls appState.loadUserData() on authentication
    // Kept as empty method for backward compatibility during transition
    func loadProfiles() {
        // No-op: AppState.loadUserData() is called by ContentView instead
    }
    
    // MARK: - Profile Creation & SMS Confirmation
    
    /// Creates a new elderly profile and initiates SMS confirmation workflow
    ///
    /// This method orchestrates the complete profile creation process that enables
    /// families to add elderly family members to their care network. The process
    /// includes profile validation, database persistence, and automatic SMS confirmation
    /// delivery to the elderly person.
    ///
    /// ## Process Flow:
    /// 1. **Validation**: Ensures profile data is elderly-friendly and valid
    /// 2. **Profile Creation**: Creates profile with pending confirmation status
    /// 3. **Database Persistence**: Saves profile with family synchronization
    /// 4. **SMS Confirmation**: Sends YES/NO confirmation text to elderly person
    /// 5. **Family Notification**: Updates all family members about the new profile
    ///
    /// ## Example:
    /// ```swift
    /// profileViewModel.profileName = "Grandma Rose"
    /// profileViewModel.phoneNumber = "+1234567890"
    /// profileViewModel.relationship = "Grandmother"
    /// await profileViewModel.createProfile()
    /// ```
    ///
    /// - Important: Profile creation automatically sends SMS confirmation to elderly person
    /// - Note: Profile remains inactive until elderly person responds YES to SMS
    /// - Warning: Respects 4-profile limit per family to prevent SMS overwhelming
    func createProfile() {
        _Concurrency.Task {
            await createProfileAsync()
        }
    }
    
    /*
    BUSINESS LOGIC: Profile Creation with SMS Confirmation Workflow
    
    CONTEXT: Families need to onboard elderly family members who may not be tech-savvy.
    The SMS confirmation process must be simple, clear, and respectful of elderly users'
    preferences and capabilities. Failed confirmations are a major user drop-off point.
    
    DESIGN DECISION: Automatic SMS confirmation upon profile creation
    - Alternative 1: Manual confirmation step (rejected - adds friction for families)
    - Alternative 2: Phone call confirmation (rejected - not scalable)  
    - Chosen Solution: Immediate SMS with clear YES/NO instructions
    
    ELDERLY IMPACT: The confirmation SMS uses simple, respectful language that explains
    the purpose clearly. Elderly users understand exactly what they're agreeing to
    and can easily decline with STOP.
    
    FAMILY COORDINATION: Profile creation immediately syncs across all family devices,
    allowing multiple family members to see confirmation status and avoid duplicate
    profile creation attempts.
    */
    func createProfileAsync() async {
        // Step 1: Validate form
        guard isValidForm else {
            await handleValidationError()
            return
        }

        await setLoadingState(true)

        do {
            // Step 2: Check permissions
            let userId = try checkCreationPermissions()

            // Step 3: Generate profile ID
            let e164Phone = phoneNumber.e164PhoneNumber
            let profileId = IDGenerator.profileID(phoneNumber: e164Phone)

            // Step 4: Upload photo (if provided)
            let photoURL = await uploadProfilePhotoIfNeeded(profileId: profileId, userId: userId)

            // Step 5: Build profile object
            let profile = buildProfile(
                profileId: profileId,
                userId: userId,
                phoneNumber: e164Phone,
                photoURL: photoURL
            )

            // Step 6: Persist to database
            try await persistProfile(profile)

            // Step 7: Handle post-creation actions
            await handleProfileCreationSuccess(profile)

        } catch {
            await handleProfileCreationError(error)
        }

        await setLoadingState(false)
    }

    // MARK: - Profile Creation Helper Methods

    private func handleValidationError() async {
        print("❌ VALIDATION FAILED - Exiting createProfileAsync")
        await MainActor.run {
            self.errorMessage = "Missing: \(missingRequirements.joined(separator: ", "))"
        }
    }

    private func setLoadingState(_ isLoading: Bool) async {
        await MainActor.run {
            self.isLoading = isLoading
            if isLoading {
                self.errorMessage = nil
            }
        }
    }

    private func checkCreationPermissions() throws -> String {
        guard let userId = authService.currentUser?.uid else {
            print("❌ [AsyncTask] Authentication check failed - no user ID")
            throw ProfileError.userNotAuthenticated
        }

        // Protective limit: Max 4 profiles per family to prevent SMS overwhelming
        guard canCreateProfile else {
            throw ProfileError.maxProfilesReached
        }

        return userId
    }

    private func uploadProfilePhotoIfNeeded(profileId: String, userId: String) async -> String? {
        guard let photoData = selectedPhotoData else { return nil }

        do {
            return try await databaseService.uploadProfilePhoto(photoData, for: profileId, userId: userId)
        } catch {
            print("❌ [AsyncTask] Failed to upload profile photo - profileId: \(profileId), error: \(error.localizedDescription)")
            // Continue without photo - it will fall back to initial letter
            return nil
        }
    }

    private func buildProfile(profileId: String, userId: String, phoneNumber: String, photoURL: String?) -> ElderlyProfile {
        return ElderlyProfile(
            id: profileId,
            userId: userId,
            name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber,
            relationship: relationship,
            isEmergencyContact: isEmergencyContact,
            timeZone: timeZone.identifier, // Critical for proper reminder timing
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            photoURL: photoURL,
            status: .pendingConfirmation, // Requires SMS confirmation before activation
            createdAt: Date(),
            lastActiveAt: Date()
        )
    }

    private func persistProfile(_ profile: ElderlyProfile) async throws {
        do {
            try await databaseService.createElderlyProfile(profile)
        } catch {
            print("❌ [Database] Failed to save profile - profileId: \(profile.id), error: \(error.localizedDescription)")
            throw error
        }
    }

    private func handleProfileCreationSuccess(_ profile: ElderlyProfile) async {
        // Broadcast profile creation to Dashboard and other family members
        dataSyncCoordinator.broadcastProfileUpdate(profile)

        // Send SMS confirmation immediately (critical step)
        do {
            try await sendConfirmationSMS(for: profile)
        } catch {
            print("❌ [AsyncTask] Failed to send SMS - profileId: \(profile.id), phoneNumber: \(profile.phoneNumber), error: \(error.localizedDescription)")
            // Don't throw - profile created, SMS failure is recoverable
        }

        await MainActor.run {
            // Update AppState
            if let appState = self.appState {
                appState.addProfile(profile)
                print("✅ [ProfileViewModel] Profile added to AppState: \(profile.name)")
            } else {
                // FALLBACK: Keep old behavior if AppState not injected (Phase 1 compatibility)
                print("⚠️ [ProfileViewModel] AppState not available, profile will be added via broadcast")
            }

            // Update confirmation status and reset form
            self.confirmationStatus[profile.id] = .sent
            self.resetForm()
            self.showingCreateProfile = false
        }
    }

    private func handleProfileCreationError(_ error: Error) async {
        print("❌ [AsyncTask] Profile creation failed - errorType: \(String(describing: type(of: error))), error: \(error.localizedDescription)")

        await MainActor.run {
            // Provide family-friendly error context
            self.errorMessage = error.localizedDescription
            logger.error("Creating elderly family member profile failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Profile Editing
    func editProfile(_ profile: ElderlyProfile) {
        selectedProfile = profile
        populateForm(with: profile)
        showingEditProfile = true
    }
    
    func updateProfile() {
        _Concurrency.Task {
            await updateProfileAsync()
        }
    }
    
    private func updateProfileAsync() async {
        guard let profile = selectedProfile, isValidForm else { return }
        
        isLoading = true
        errorMessage = nil

        do {
            let e164Phone = phoneNumber.e164PhoneNumber
            let phoneChanged = e164Phone != profile.phoneNumber

            let updatedProfile = ElderlyProfile(
                id: profile.id,
                userId: profile.userId,
                name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
                phoneNumber: e164Phone,
                relationship: relationship,
                isEmergencyContact: isEmergencyContact,
                timeZone: timeZone.identifier,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                photoURL: profile.photoURL,
                status: phoneChanged ? .pendingConfirmation : profile.status,
                createdAt: profile.createdAt,
                lastActiveAt: Date(),
                confirmedAt: phoneChanged ? nil : profile.confirmedAt
            )
            
            try await databaseService.updateElderlyProfile(updatedProfile)
            
            // Broadcast profile update to Dashboard and other family members
            dataSyncCoordinator.broadcastProfileUpdate(updatedProfile)
            
            // Send new confirmation SMS if phone changed
            if phoneChanged {
                try await sendConfirmationSMS(for: updatedProfile)
                await MainActor.run {
                    self.confirmationStatus[updatedProfile.id] = .sent
                }
            }
            
            await MainActor.run {
                // PHASE 4: AppState is always available - update directly
                self.updateProfile(updatedProfile)

                self.resetForm()
                self.showingEditProfile = false
                self.selectedProfile = nil
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                logger.error("Updating profile failed: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Profile Management
    func deleteProfile(_ profile: ElderlyProfile) {
        _Concurrency.Task {
            await deleteProfileAsync(profile)
        }
    }
    
    private func deleteProfileAsync(_ profile: ElderlyProfile) async {
        // ✅ OPTIMISTIC UI UPDATE: Remove from UI immediately (before async deletion)
        await MainActor.run {
            print("🎬 [ProfileViewModel] Optimistic delete - removing '\(profile.name)' from UI immediately")

            // PHASE 4: AppState is always available - delete directly
            self.deleteProfile(profile.id, profileName: profile.name)

            self.confirmationStatus.removeValue(forKey: profile.id)
            self.confirmationMessages.removeValue(forKey: profile.id)
        }

        // 🔥 Background deletion (5+ seconds for nested data)
        do {
            print("🗑️ [ProfileViewModel] Starting background deletion for '\(profile.name)'...")
            try await databaseService.deleteElderlyProfile(profile.id, userId: profile.userId)
            print("✅ [ProfileViewModel] Background deletion completed for '\(profile.name)'")

        } catch {
            // ❌ ERROR RECOVERY: If deletion fails, restore profile to UI
            await MainActor.run {
                print("❌ [ProfileViewModel] Deletion failed - restoring '\(profile.name)' to UI")

                // PHASE 4: AppState is always available - restore directly
                self.addProfile(profile)  // Re-add the profile

                self.errorMessage = "Failed to delete profile: \(error.localizedDescription)"
                logger.error("Deleting profile failed: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleProfileStatus(_ profile: ElderlyProfile) {
        _Concurrency.Task {
            await toggleProfileStatusAsync(profile)
        }
    }
    
    private func toggleProfileStatusAsync(_ profile: ElderlyProfile) async {
        let newStatus: ProfileStatus = profile.status == .confirmed ? .inactive : .confirmed
        
        let updatedProfile = ElderlyProfile(
            id: profile.id,
            userId: profile.userId,
            name: profile.name,
            phoneNumber: profile.phoneNumber,
            relationship: profile.relationship,
            isEmergencyContact: profile.isEmergencyContact,
            timeZone: profile.timeZone,
            notes: profile.notes,
            photoURL: profile.photoURL,
            status: newStatus,
            createdAt: profile.createdAt,
            lastActiveAt: Date(),
            confirmedAt: profile.confirmedAt
        )
        
        do {
            try await databaseService.updateElderlyProfile(updatedProfile)
            
            // Broadcast profile status change to Dashboard and other family members
            dataSyncCoordinator.broadcastProfileUpdate(updatedProfile)
            
            await MainActor.run {
                // PHASE 4: AppState is always available - update directly
                self.updateProfile(updatedProfile)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                logger.error("Toggling profile status failed: \(error.localizedDescription)")
            }
        }
    }

    /// Restores missing photoURL references for profiles that have photos in Storage
    ///
    /// This utility function checks all profiles for missing photoURL fields and attempts
    /// to restore them by checking if the photo file exists in Firebase Storage.
    /// Useful for recovering from bugs where photoURL was accidentally cleared.
    func restoreMissingProfilePhotos() async {
        guard let userId = authService.currentUser?.uid else {
            print("⚠️ [ProfileViewModel] Cannot restore photos - no authenticated user")
            return
        }

        for profile in profiles {
            // Skip if profile already has a photoURL
            if profile.photoURL != nil && !profile.photoURL!.isEmpty {
                continue
            }

            // Check if photo exists in Storage
            if let photoURL = try? await databaseService.getProfilePhotoURL(for: profile.id, userId: profile.userId) {
                print("✅ [ProfileViewModel] Restored photoURL for '\(profile.name)'")

                // Create updated profile with restored photoURL
                var updatedProfile = profile
                updatedProfile.photoURL = photoURL

                // Update in Firestore
                do {
                    try await databaseService.updateElderlyProfile(updatedProfile)

                    // Update in AppState
                    await MainActor.run {
                        self.updateProfile(updatedProfile)
                    }
                } catch {
                    print("❌ [ProfileViewModel] Failed to restore photoURL for '\(profile.name)': \(error.localizedDescription)")
                }
            }
        }

        print("✅ [ProfileViewModel] Photo restoration check complete")
    }

    /// Refreshes expired or invalid photo URLs for profiles
    ///
    /// This function regenerates download URLs with fresh tokens for profiles that have
    /// photos in Firebase Storage but the URL may have expired or become invalid.
    /// Call this when AsyncImage fails to load a profile photo despite having a photoURL.
    func refreshProfilePhotoURLs() async {
        guard let userId = authService.currentUser?.uid else {
            print("⚠️ [ProfileViewModel] Cannot refresh photos - no authenticated user")
            return
        }

        for profile in profiles {
            // Only refresh if profile has a photoURL (skip profiles without photos)
            guard profile.photoURL != nil && !profile.photoURL!.isEmpty else {
                continue
            }

            // Get fresh download URL from Storage
            if let freshPhotoURL = try? await databaseService.getProfilePhotoURL(for: profile.id, userId: profile.userId) {
                // Only update if URL changed
                if freshPhotoURL != profile.photoURL {
                    print("🔄 [ProfileViewModel] Refreshing photoURL for '\(profile.name)'")
                    print("   Old URL token: \(profile.photoURL?.split(separator: "=").last ?? "none")")
                    print("   New URL token: \(freshPhotoURL.split(separator: "=").last ?? "none")")

                    // CRITICAL: Remove old cached image before updating
                    // This ensures the UI will use the new URL instead of stale cache
                    await MainActor.run {
                        self.appState?.imageCache.removeCachedImage(for: profile.photoURL)
                    }

                    // Create updated profile with fresh photoURL
                    var updatedProfile = profile
                    updatedProfile.photoURL = freshPhotoURL

                    // Update in Firestore
                    do {
                        try await databaseService.updateElderlyProfile(updatedProfile)

                        // Update in AppState and trigger UI refresh
                        await MainActor.run {
                            self.updateProfile(updatedProfile)
                        }

                        // CRITICAL: Pre-load the fresh image into cache
                        // This ensures ProfileImageView immediately shows the updated photo
                        await self.appState?.imageCache.preloadProfileImages([updatedProfile])

                        print("✅ [ProfileViewModel] Refreshed photoURL for '\(profile.name)'")
                    } catch {
                        print("❌ [ProfileViewModel] Failed to refresh photoURL for '\(profile.name)': \(error.localizedDescription)")
                    }
                }
            }
        }

        print("✅ [ProfileViewModel] Photo URL refresh check complete")
    }

    // MARK: - SMS Confirmation Management
    
    /// Resends SMS confirmation to elderly family member when needed
    ///
    /// This method allows families to retry SMS confirmation if the elderly person
    /// didn't receive the initial message, needs time to consider, or experienced
    /// delivery issues. It respects elderly users' response timing while ensuring
    /// families can complete the onboarding process.
    ///
    /// ## Common Use Cases:
    /// - Initial SMS was not delivered due to network issues
    /// - Elderly person deleted the message before reading
    /// - Family needs to explain the purpose before elderly person responds
    /// - Phone was temporarily unavailable during initial send
    ///
    /// - Parameter profile: The elderly profile that needs SMS confirmation retry
    /// - Important: Uses same friendly language as original confirmation
    /// - Note: Updates confirmation status to show families the retry was sent
    func resendConfirmation(for profile: ElderlyProfile) {
        _Concurrency.Task {
            await resendConfirmationAsync(for: profile)
        }
    }
    
    private func resendConfirmationAsync(for profile: ElderlyProfile) async {
        do {
            try await sendConfirmationSMS(for: profile)
            
            await MainActor.run {
                self.confirmationStatus[profile.id] = .sent
                self.confirmationMessages[profile.id] = "Confirmation SMS sent again"
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.confirmationStatus[profile.id] = .failed
                logger.error("Resending confirmation failed: \(error.localizedDescription)")
            }
        }
    }
    
    /*
    BUSINESS LOGIC: SMS Confirmation Message Design for Elderly Users
    
    CONTEXT: Elderly users receive many spam and scam text messages. Our confirmation
    must be clearly legitimate, respectful, and easy to understand. The language must
    build trust while providing clear action steps.
    
    DESIGN DECISION: Warm, personal greeting with clear explanation
    - Alternative 1: Generic business language (rejected - feels impersonal/spammy)
    - Alternative 2: Complex multi-step instructions (rejected - too confusing)  
    - Chosen Solution: Personal greeting + clear purpose + simple YES/STOP options
    
    ELDERLY CONSIDERATIONS: Uses the profile name they recognize, explains the family
    connection clearly, provides two simple response options, and includes a clear
    sender identification to build trust.
    */
    private func sendConfirmationSMS(for profile: ElderlyProfile) async throws {
        // TCPA-COMPLIANT CONSENT MESSAGE
        // Required elements:
        // ✅ Purpose of messages clearly stated
        // ✅ Frequency disclosure ("multiple messages per day")
        // ✅ Opt-out instructions (STOP keyword)
        // ✅ Help keyword (HELP for info)
        // ✅ Message & data rates disclosure
        let message = """
        Hello \(profile.name)! Your family member wants to send you helpful daily reminders via text.

        Reply YES to receive multiple messages per day. Reply STOP to unsubscribe or HELP for info.

        Message & data rates may apply.
        - Remi
        """

        let _ = try await smsService.sendSMS(
            to: profile.phoneNumber,
            message: message,
            profileId: profile.id,
            messageType: .confirmation
        )
    }
    
    // MARK: - Real-Time Family Coordination Handlers
    
    /*
    BUSINESS LOGIC: Real-Time Profile Synchronization Across Family Devices
    
    CONTEXT: Multiple family members may be managing elderly profiles simultaneously.
    Profile updates (especially confirmation status) must sync immediately across all
    devices to prevent duplicate SMS sends and maintain consistent family view.
    
    DESIGN DECISION: Immediate local updates with background database sync
    - Alternative 1: Poll for updates periodically (rejected - delays are confusing)
    - Alternative 2: Full refresh on each change (rejected - poor user experience)  
    - Chosen Solution: Real-time push updates with optimistic local state
    
    FAMILY COORDINATION: When one family member sees a profile get confirmed, all
    other family members see the same status immediately, preventing confusion
    about which profiles are ready for task creation.
    */
    private func handleProfileUpdate(_ updatedProfile: ElderlyProfile) {
        // PHASE 4: AppState handles profile updates via DataSyncCoordinator
        // This handler is redundant now - AppState.handleProfileUpdate() already updates the array
        // Keeping for backward compatibility but making it a no-op except for confirmation status
        print("📩 [ProfileViewModel] Profile update received: \(updatedProfile.name) - AppState handles update")
        updateConfirmationStatuses()
    }
    
    /*
    BUSINESS LOGIC: SMS Confirmation Response Processing
    
    CONTEXT: When elderly users respond YES or NO to confirmation SMS, families need
    immediate feedback about profile readiness. This determines whether task creation
    can proceed and prevents families from sending reminders to non-consenting users.
    
    DESIGN DECISION: Automatic profile activation on positive confirmation
    - Alternative 1: Manual family approval after elderly response (rejected - adds friction)
    - Alternative 2: Time delay before activation (rejected - confuses families)  
    - Chosen Solution: Immediate activation with clear family notification
    
    ELDERLY RESPECT: Negative responses (NO, STOP) are honored immediately and permanently.
    No further SMS reminders will be sent to elderly users who decline.
    */
    private func handleConfirmationResponse(_ response: SMSResponse) {
        guard let profileId = response.profileId else {
            return
        }

        if response.isPositiveConfirmation {
            // ONBOARDING FLOW: Check if this response is for current onboarding profile
            if let onboardingProfile = onboardingProfile,
               onboardingProfile.id == profileId,
               profileOnboardingStep == .confirmationWait {
                // NOW create and save the profile since SMS was confirmed
                var confirmedProfile = onboardingProfile
                confirmedProfile.status = .confirmed
                confirmedProfile.confirmedAt = response.receivedAt
                
                // Persist to database for the first time
                _Concurrency.Task {
                    do {
                        try await self.databaseService.createElderlyProfile(confirmedProfile)
                        
                        await MainActor.run {
                            // PHASE 4: Add to AppState (single source of truth)
                            self.addProfile(confirmedProfile)

                            self.confirmationStatus[profileId] = .confirmed
                            self.confirmationMessages[profileId] = "Confirmed! Ready to receive reminders."

                            // Create gallery history event for profile creation
                            self.createGalleryEventForProfile(confirmedProfile, profileSlot: 0)
                            
                            // Advance onboarding flow to success step
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.profileOnboardingStep = .onboardingSuccess
                            }
                        }
                        
                        // Broadcast profile creation to Dashboard and family members
                        self.dataSyncCoordinator.broadcastProfileUpdate(confirmedProfile)
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                // Handle existing profile confirmation (not onboarding)
                // NOTE: profileId from webhook is actually the phone number (fromPhone)
                // So we need to match by phoneNumber, not by document ID
                if let index = profiles.firstIndex(where: { $0.phoneNumber == profileId }) {
                    var updatedProfile = profiles[index]
                    updatedProfile.status = .confirmed
                    updatedProfile.confirmedAt = response.receivedAt

                    // PHASE 4: Update via AppState (single source of truth)
                    self.updateProfile(updatedProfile)

                    confirmationStatus[updatedProfile.id] = .confirmed
                    confirmationMessages[updatedProfile.id] = "Confirmed! Ready to receive reminders."

                    // Create gallery history event for profile creation
                    createGalleryEventForProfile(updatedProfile, profileSlot: index)

                    // Persist confirmation status for family synchronization
                    _Concurrency.Task {
                        try? await databaseService.updateElderlyProfile(updatedProfile)
                        // Broadcast profile status update to Dashboard and family members
                        self.dataSyncCoordinator.broadcastProfileUpdate(updatedProfile)
                    }
                }
            }
        } else {
            // Honor elderly user's decline - no reminders will be sent
            confirmationStatus[profileId] = .declined
            confirmationMessages[profileId] = "Declined. No reminders will be sent."

            // ONBOARDING FLOW: Handle decline during onboarding
            if let onboardingProfile = onboardingProfile,
               onboardingProfile.id == profileId,
               profileOnboardingStep == .confirmationWait {
                // Stay on confirmation wait but update UI to show decline
                // User can retry or cancel onboarding
            }

            // TCPA COMPLIANCE: Handle STOP keyword (opt-out)
            handleStopKeyword(for: profileId, response: response)
        }
    }

    /*
    BUSINESS LOGIC: STOP Keyword Handler (TCPA Compliance)

    CONTEXT: When elderly users text STOP, QUIT, UNSUBSCRIBE, or similar keywords,
    federal TCPA regulations require immediate cessation of all SMS communication.
    This protects elderly users from unwanted messages and ensures legal compliance.

    DESIGN DECISION: Automatic opt-out with permanent record keeping
    - Alternative 1: Confirm opt-out with family first (rejected - violates TCPA)
    - Alternative 2: Temporary pause with re-subscription prompt (rejected - illegal)
    - Chosen Solution: Immediate permanent opt-out with audit trail

    LEGAL COMPLIANCE: This handler ensures:
    - Opt-out processed within 1 minute (TCPA requirement)
    - All future SMS blocked automatically
    - Audit trail maintained (date, method, keyword used)
    - Family notified to prevent confusion

    ELDERLY RESPECT: Once someone says STOP, we respect that decision permanently.
    Re-subscription requires explicit new consent through proper opt-in flow.
    */
    private func handleStopKeyword(for profileId: String, response: SMSResponse) {
        // Check if response contains STOP keywords
        let upperMessage = response.textResponse?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stopKeywords = ["STOP", "UNSUBSCRIBE", "CANCEL", "END", "QUIT", "STOPALL", "REVOKE", "OPTOUT"]

        guard stopKeywords.contains(upperMessage) else { return }

        print("🛑 [ProfileViewModel] STOP keyword detected: '\(upperMessage)' from profile \(profileId)")

        // Find and update profile
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            print("❌ [ProfileViewModel] Profile not found for STOP handler: \(profileId)")
            return
        }

        var updatedProfile = profiles[index]

        // Mark as opted out
        updatedProfile.optOutOfSMS(method: "STOP_KEYWORD")

        // PHASE 4: Update via AppState (optimistic UI)
        self.updateProfile(updatedProfile)
        confirmationStatus[profileId] = .declined
        confirmationMessages[profileId] = "⚠️ Opted out via STOP keyword. No SMS will be sent."

        print("🛑 [ProfileViewModel] Profile opted out: \(updatedProfile.name) (\(updatedProfile.phoneNumber))")

        // Persist to Firestore
        _Concurrency.Task {
            do {
                try await databaseService.updateElderlyProfile(updatedProfile)
                print("✅ [ProfileViewModel] Opt-out saved to Firestore")

                // Broadcast update to family members
                dataSyncCoordinator.broadcastProfileUpdate(updatedProfile)

                // TODO: Send push notification to family
                // "Grandma Rose has opted out of SMS reminders. Please contact them directly."

            } catch {
                await MainActor.run {
                    print("❌ [ProfileViewModel] Failed to save opt-out: \(error)")
                    errorMessage = "Failed to process opt-out: \(error.localizedDescription)"
                }
            }
        }
    }

    /*
    BUSINESS LOGIC: Re-subscription Handler (Opt-In After Opt-Out)

    CONTEXT: If an elderly user accidentally opted out or changed their mind,
    families can request re-subscription. However, TCPA requires explicit new consent.

    DESIGN DECISION: Send new opt-in SMS requiring YES response
    - Alternative 1: Automatically re-enable (rejected - violates TCPA)
    - Alternative 2: Allow family to re-enable directly (rejected - illegal)
    - Chosen Solution: Send fresh consent SMS, require explicit YES reply

    LEGAL COMPLIANCE: New consent must be:
    - Explicitly requested from elderly user
    - Clearly worded with opt-out instructions
    - Documented with timestamp and method
    */
    func requestResubscription(for profile: ElderlyProfile) async throws {
        guard profile.smsOptedOut else {
            throw NSError(domain: "ProfileViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Profile is not opted out"
            ])
        }

        print("📱 [ProfileViewModel] Requesting re-subscription for \(profile.name)")

        // Send new opt-in request SMS
        let message = """
        Hello \(profile.name)! Your family would like to resume sending you helpful daily reminders via text.

        Reply YES to start receiving reminders again, or STOP to stay unsubscribed.

        Message & data rates may apply.
        - Remi
        """

        _ = try await smsService.sendSMS(
            to: profile.phoneNumber,
            message: message,
            profileId: profile.id,
            messageType: .confirmation
        )

        // Update UI
        await MainActor.run {
            confirmationStatus[profile.id] = .pending
            confirmationMessages[profile.id] = "Re-subscription request sent. Waiting for YES reply..."
        }

        print("✅ [ProfileViewModel] Re-subscription SMS sent to \(profile.phoneNumber)")
    }

    // MARK: - Validation Methods
    private func validateName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            nameError = nil
        } else if trimmedName.count < 2 {
            nameError = "Name must be at least 2 characters"
        } else if trimmedName.count > 50 {
            nameError = "Name must be less than 50 characters"
        } else {
            nameError = nil
        }
    }
    
    private func validatePhoneNumber(_ phone: String) {
        // Mark that user has started typing if they've gone beyond the default "+1 "
        if phone.count > 3 {
            hasStartedTypingPhone = true
        }

        // Only show validation errors after user has started typing
        if !hasStartedTypingPhone {
            phoneError = nil
        } else if phone == "+1 " || phone.isEmpty {
            phoneError = nil // Don't show error for empty state
        } else if !phone.isValidPhoneNumber {
            phoneError = "Please enter a valid phone number"
        } else if profiles.contains(where: { $0.phoneNumber == phone.e164PhoneNumber && $0.id != selectedProfile?.id }) {
            phoneError = "This phone number is already in use"
        } else {
            phoneError = nil
        }
    }
    
    private func validateRelationship(_ relationship: String) {
        // Allow any string for relationship - no validation rules
        relationshipError = nil
    }
    
    // MARK: - Form Management
    private func populateForm(with profile: ElderlyProfile) {
        profileName = profile.name
        phoneNumber = profile.phoneNumber
        relationship = profile.relationship
        isEmergencyContact = profile.isEmergencyContact
        timeZone = TimeZone(identifier: profile.timeZone) ?? TimeZone.current
        notes = profile.notes
    }
    
    func resetForm() {
        profileName = ""
        phoneNumber = "+1 "
        relationship = ""
        isEmergencyContact = false
        timeZone = TimeZone.current
        notes = ""
        nameError = nil
        phoneError = nil
        relationshipError = nil
        hasStartedTypingPhone = false
        selectedPhotoData = nil
        debugInfo = ""
    }
    
    private func updateConfirmationStatuses() {
        for profile in profiles {
            switch profile.status {
            case .pendingConfirmation:
                if confirmationStatus[profile.id] == nil {
                    confirmationStatus[profile.id] = .pending
                }
            case .confirmed:
                confirmationStatus[profile.id] = .confirmed
            case .inactive:
                confirmationStatus[profile.id] = .inactive
            }
        }
    }
    
    // MARK: - UI Actions
    func startCreateProfile() {
        resetForm()
        showingCreateProfile = true
    }
    
    func cancelCreateProfile() {
        resetForm()
        showingCreateProfile = false
    }
    
    func cancelEditProfile() {
        resetForm()
        showingEditProfile = false
        selectedProfile = nil
    }
    
    // MARK: - Profile Onboarding Flow Properties (6-Step Flow)
    
    /// Current step in the profile onboarding workflow
    /// 
    /// Tracks progression through the 6-step profile creation and SMS confirmation process:
    /// - .newProfileForm: Step 1 - Basic profile information collection
    /// - .profileComplete: Step 2 - Profile summary with member counting
    /// - .smsIntroduction: Step 3 - SMS test introduction and "Send Hello" trigger
    /// - .confirmationWait: Step 4 - Real-time SMS confirmation waiting
    /// - .onboardingSuccess: Step 5 - Confirmation success display
    /// - .firstHabit: Step 6 - Transition to habit creation
    @Published var profileOnboardingStep: ProfileOnboardingStep = .newProfileForm
    
    /// Controls the 6-step profile onboarding flow presentation
    /// 
    /// When true, displays the complete profile onboarding flow instead of basic creation.
    /// Replaces the simple CreateProfileView with sophisticated multi-step process.
    @Published var showingProfileOnboarding = false
    @Published var shouldDismissOnboarding = false
    
    /// Currently created profile during onboarding flow (before SMS confirmation)
    /// 
    /// Holds the profile data during the onboarding process. Profile is saved to database
    /// but remains in pendingConfirmation status until SMS is sent and confirmed.
    @Published var onboardingProfile: ElderlyProfile?
    
    /// Member number for the profile being created
    /// 
    /// Dynamically calculated based on existing profiles count + 1.
    /// Updates when profiles are added/deleted to maintain sequential numbering.
    var memberNumber: Int {
        return profiles.count + 1
    }
    
    /// Photo upload state for profile onboarding
    /// 
    /// Tracks whether user has selected a photo during profile creation.
    /// Future implementation will handle camera/photo library integration.
    @Published var hasSelectedPhoto = false
    
    /// Selected photo data for profile (placeholder for future implementation)
    /// 
    /// Will store UIImage data when photo upload functionality is implemented.
    /// Currently used to track photo selection state in onboarding flow.
    @Published var selectedPhotoData: Data?
    
    // MARK: - Profile Onboarding Flow Actions
    
    /// Starts the 6-step profile onboarding flow
    /// 
    /// Initializes the onboarding state and presents the multi-step profile creation process.
    /// Replaces the simple profile creation with comprehensive onboarding experience.
    func startProfileOnboarding() {
        resetForm()
        profileOnboardingStep = .newProfileForm
        onboardingProfile = nil
        hasSelectedPhoto = false
        selectedPhotoData = nil
        showingProfileOnboarding = true
    }
    
    /// Advances to the next step in the profile onboarding flow
    /// 
    /// Handles step-specific logic and validation before proceeding to next step.
    /// Each step may have different requirements and side effects.
    func nextOnboardingStep() {
        switch profileOnboardingStep {
        case .newProfileForm:
            // Just validate form and move to next step - don't create profile yet
            guard isValidForm else { return }
            profileOnboardingStep = .profileComplete
        case .profileComplete:
            // Create temporary profile data for SMS - don't add to database yet
            createTemporaryProfileForSMS()
        case .smsIntroduction:
            // SMS will be sent when user taps "Send Hello 👋"
            sendOnboardingSMS()
        case .confirmationWait:
            profileOnboardingStep = .onboardingSuccess
        case .onboardingSuccess:
            profileOnboardingStep = .firstHabit
        case .firstHabit:
            // Navigate to task creation (handled by parent view)
            completeProfileOnboarding()
        }
    }
    
    /// Goes back to the previous step in onboarding flow
    /// 
    /// Allows users to correct information or reconsider profile creation.
    /// Some steps may not allow backward navigation for data integrity.
    func previousOnboardingStep() {
        switch profileOnboardingStep {
        case .newProfileForm:
            // Can't go back from first step - cancel entire flow
            cancelProfileOnboarding()
        case .profileComplete:
            profileOnboardingStep = .newProfileForm
        case .smsIntroduction:
            profileOnboardingStep = .profileComplete
        case .confirmationWait:
            // Don't allow going back once SMS is sent
            break
        case .onboardingSuccess:
            // Don't allow going back once confirmed
            break
        case .firstHabit:
            profileOnboardingStep = .onboardingSuccess
        }
    }
    
    /// Cancels the entire profile onboarding flow
    /// 
    /// Cleans up any partially created profile data and resets onboarding state.
    /// If profile was already created, it should be deleted from database.
    func cancelProfileOnboarding() {
        print("🔙 BACK: Cancelling profile onboarding from step: \(profileOnboardingStep)")
        // Clean up partially created profile if it exists
        if let profile = onboardingProfile {
            deleteProfile(profile)
        }
        
        resetOnboardingState()
        showingProfileOnboarding = false
        shouldDismissOnboarding = true // Trigger presentation dismissal
        print("🔙 BACK: showingProfileOnboarding set to false, dismissal triggered")
    }
    
    /// Completes the profile onboarding flow successfully
    /// 
    /// Finalizes profile creation and prepares for transition to main app flow.
    /// Profile should be confirmed and ready for task assignment.
    func completeProfileOnboarding() {
        resetOnboardingState()
        showingProfileOnboarding = false
        shouldDismissOnboarding = true // Trigger presentation dismissal
        // Parent view should handle navigation to task creation
    }
    
    /// Creates profile during onboarding without immediately sending SMS
    /// 
    /// Modified version of createProfile() that delays SMS sending until Step 3.
    /// Profile is created in pendingConfirmation status and stored for SMS sending later.
    
    /// Sends SMS confirmation during onboarding flow (Step 3)
    /// 
    /// Sends the "Hello 👋" SMS when user explicitly triggers it in Step 3.
    /// This separates profile creation from SMS sending for better user control.
    func sendOnboardingSMS() {
        guard let profile = onboardingProfile else { return }
        
        _Concurrency.Task {
            await sendOnboardingSMSAsync(for: profile)
        }
    }
    
    /// Creates temporary profile data for SMS sending without database persistence
    /// 
    /// Creates profile object for SMS confirmation but doesn't save to database
    /// or add to profiles array until SMS confirmation is received.
    private func createTemporaryProfileForSMS() {
        guard isValidForm else { return }
        
        guard let userId = authService.currentUser?.uid else {
            errorMessage = "Authentication required"
            return
        }
        
        guard canCreateProfile else {
            errorMessage = "Maximum profiles reached"
            return
        }

        let e164Phone = phoneNumber.e164PhoneNumber

        // Create profile object but don't persist yet
        let profile = ElderlyProfile(
            id: IDGenerator.profileID(phoneNumber: e164Phone),
            userId: userId,
            name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: e164Phone,
            relationship: relationship,
            isEmergencyContact: isEmergencyContact,
            timeZone: timeZone.identifier,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .pendingConfirmation,
            createdAt: Date(),
            lastActiveAt: Date()
        )
        
        // Store temporarily for SMS and UI display
        onboardingProfile = profile
        
        // Move to SMS introduction step
        profileOnboardingStep = .smsIntroduction
    }
    
    /// Resets all onboarding-specific state
    /// 
    /// Cleans up onboarding flow state while preserving general profile management state.
    /// Called when onboarding is completed or cancelled.
    private func resetOnboardingState() {
        profileOnboardingStep = .newProfileForm
        onboardingProfile = nil
        hasSelectedPhoto = false
        selectedPhotoData = nil
    }
    
    // MARK: - Private Onboarding Implementation Methods
    
    
    /// Async implementation of SMS sending during onboarding Step 3
    /// 
    /// Sends the confirmation SMS when user explicitly triggers "Send Hello 👋".
    /// Updates confirmation status and advances to confirmation wait step.
    private func sendOnboardingSMSAsync(for profile: ElderlyProfile) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Send the confirmation SMS (reuse existing SMS sending logic)
            try await sendConfirmationSMS(for: profile)
            
            await MainActor.run {
                self.confirmationStatus[profile.id] = .sent
                self.confirmationMessages[profile.id] = "Hello SMS sent! Waiting for response."
                
                // Move to next step (Confirmation Wait)
                self.profileOnboardingStep = .confirmationWait
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.confirmationStatus[profile.id] = .failed
                logger.error("Sending onboarding SMS failed: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Gallery History Event Creation
    
    /// Creates a gallery history event when a profile is confirmed
    ///
    /// This method creates a gallery event to track profile creation in the gallery history.
    /// Called when elderly users confirm their profile via SMS response.
    ///
    /// **Important:** Uses Set-based tracking to prevent duplicate gallery entries when
    /// old SMS confirmations are replayed by the real-time listener on app launch.
    ///
    /// - Parameter profile: The confirmed elderly profile
    /// - Parameter profileSlot: The slot index for consistent color assignment
    private func createGalleryEventForProfile(_ profile: ElderlyProfile, profileSlot: Int) {
        guard let userId = authService.currentUser?.uid else { return }

        // Check if gallery event already created for this profile
        if profilesWithGalleryEvents.contains(profile.id) {
            print("ℹ️ [ProfileViewModel] Gallery event already created for profile \(profile.name) - skipping duplicate")
            return
        }

        // Create gallery history event for profile creation
        let galleryEvent = GalleryHistoryEvent.fromProfileCreation(
            userId: userId,
            profile: profile,
            profileSlot: profileSlot
        )

        // Save gallery event to database
        _Concurrency.Task {
            do {
                try await self.databaseService.createGalleryHistoryEvent(galleryEvent)

                // Mark this profile as having a gallery event
                _ = await MainActor.run {
                    self.profilesWithGalleryEvents.insert(profile.id)
                }

                // Broadcast gallery event update to gallery views
                self.dataSyncCoordinator.broadcastGalleryEventUpdate(galleryEvent)

                print("✅ [ProfileViewModel] Created gallery event for profile \(profile.name)")

            } catch {
                // Log error but don't interrupt profile confirmation flow
                logger.error("Creating gallery history event for profile failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Models
enum ConfirmationStatus {
    case pending
    case sent
    case confirmed
    case declined
    case failed
    case expired
    case inactive
    
    var displayText: String {
        switch self {
        case .pending:
            return "Confirmation pending"
        case .sent:
            return "Confirmation sent"
        case .confirmed:
            return "Confirmed ✓"
        case .declined:
            return "Declined"
        case .failed:
            return "Failed to send"
        case .expired:
            return "Confirmation expired"
        case .inactive:
            return "Inactive"
        }
    }
    
    var color: Color {
        switch self {
        case .pending, .sent:
            return .orange
        case .confirmed:
            return .green
        case .declined, .failed, .expired:
            return .red
        case .inactive:
            return .gray
        }
    }
}

// MARK: - Profile Onboarding Step Enum
/// Defines the 6-step profile onboarding workflow progression
/// 
/// Each step represents a distinct phase in the profile creation and SMS confirmation process.
/// The flow is designed to be linear with controlled backward navigation in early steps.
enum ProfileOnboardingStep: String, CaseIterable {
    case newProfileForm = "newProfileForm"           // Step 1: Basic profile information form
    case profileComplete = "profileComplete"         // Step 2: Profile summary with member counting
    case smsIntroduction = "smsIntroduction"         // Step 3: SMS test introduction and "Send Hello" trigger
    case confirmationWait = "confirmationWait"       // Step 4: Real-time SMS confirmation waiting
    case onboardingSuccess = "onboardingSuccess"     // Step 5: Confirmation success display
    case firstHabit = "firstHabit"                   // Step 6: Transition to habit creation
    
    /// User-friendly display name for each onboarding step
    var displayName: String {
        switch self {
        case .newProfileForm:
            return "New Profile"
        case .profileComplete:
            return "Profile Complete"
        case .smsIntroduction:
            return "Onboard Your Member"
        case .confirmationWait:
            return "Waiting for Confirmation"
        case .onboardingSuccess:
            return "Onboarding Complete"
        case .firstHabit:
            return "Create a New Habit"
        }
    }
    
    /// Step subtitle for user guidance
    var subtitle: String {
        switch self {
        case .newProfileForm:
            return "Who are you setting this up for?"
        case .profileComplete:
            return "Let's add your first habit now :)"
        case .smsIntroduction:
            return "Send them an SMS and see if they receive it"
        case .confirmationWait:
            return "Ask them to reply the text with Ok!"
        case .onboardingSuccess:
            return "Lets Create Their First Habit."
        case .firstHabit:
            return "Lets Create Their First Habit :)"
        }
    }
    
    /// Progress indicator (0.0 to 1.0) for each step
    var progress: Double {
        switch self {
        case .newProfileForm:
            return 1.0 / 6.0  // Step 1 of 6
        case .profileComplete:
            return 2.0 / 6.0  // Step 2 of 6
        case .smsIntroduction:
            return 3.0 / 6.0  // Step 3 of 6
        case .confirmationWait:
            return 4.0 / 6.0  // Step 4 of 6
        case .onboardingSuccess:
            return 5.0 / 6.0  // Step 5 of 6
        case .firstHabit:
            return 6.0 / 6.0  // Step 6 of 6 (Complete)
        }
    }
    
    /// Whether this step allows backward navigation
    var canGoBack: Bool {
        switch self {
        case .newProfileForm:
            return false  // First step - can only cancel
        case .profileComplete, .smsIntroduction:
            return true   // Allow editing profile information
        case .confirmationWait, .onboardingSuccess:
            return false  // No going back after SMS is sent
        case .firstHabit:
            return true   // Can return to success screen
        }
    }
    
    /// Whether the Next button should be enabled by default
    var nextButtonEnabled: Bool {
        switch self {
        case .newProfileForm:
            return false  // Requires form validation
        case .profileComplete, .smsIntroduction, .onboardingSuccess, .firstHabit:
            return true   // Can proceed immediately
        case .confirmationWait:
            return false  // Requires SMS confirmation
        }
    }
}

// MARK: - Profile Errors
enum ProfileError: LocalizedError {
    case userNotAuthenticated
    case maxProfilesReached
    case duplicatePhoneNumber
    case invalidPhoneNumber
    case profileNotFound
    case confirmationFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "Please sign in to manage profiles"
        case .maxProfilesReached:
            return "You can only create up to 4 profiles"
        case .duplicatePhoneNumber:
            return "This phone number is already in use"
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .profileNotFound:
            return "Profile not found"
        case .confirmationFailed:
            return "Failed to send confirmation SMS"
        }
    }
}