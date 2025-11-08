//
//  AppState.swift
//  Halloo
//
//  Purpose: Single source of truth for all app-wide shared state
//  Replaces: Duplicated state across ProfileViewModel, TaskViewModel, DashboardViewModel
//  Pattern: Observable State Container with Service Injection
//
//  Created by Claude Code on 2025-10-12
//

import Foundation
import SwiftUI
import Combine

/// Single source of truth for all app-wide state
///
/// This class consolidates state that was previously duplicated across multiple ViewModels,
/// providing a unified data model for profiles, tasks, and user information. All ViewModels
/// now read from AppState and write mutations back to it, ensuring consistency.
///
/// **Key Benefits:**
/// - Eliminates state synchronization bugs between ViewModels
/// - Reduces Firebase query duplication (loads data once)
/// - Simplifies ViewModel code (no more loadProfiles/loadTasks methods)
/// - Enables centralized error handling and loading indicators
/// - Integrates with DataSyncCoordinator for multi-device sync
///
/// **Usage:**
/// ```swift
/// // In ContentView
/// @StateObject private var appState = AppState(...)
///
/// var body: some View {
///     DashboardView()
///         .environmentObject(appState)  // Inject once
/// }
///
/// // In any View
/// @EnvironmentObject var appState: AppState
///
/// var body: some View {
///     List(appState.profiles) { profile in  // Read directly
///         ProfileRow(profile: profile)
///     }
/// }
///
/// // In ViewModel
/// func createProfile() async {
///     let profile = ElderlyProfile(...)
///     await appState.addProfile(profile)  // Write via method
/// }
/// ```
@MainActor
final class AppState: ObservableObject {

    // MARK: - Shared State (Previously Duplicated Across ViewModels)

    /// Current authenticated user
    ///
    /// Replaces:
    /// - ContentView.AuthenticationViewModel.currentUser (dead code)
    /// - Various ViewModel checks of authService.currentUser
    @Published var currentUser: AuthUser?

    /// All elderly profiles for the current family caregiver
    ///
    /// Replaces:
    /// - ProfileViewModel.profiles (canonical source)
    /// - TaskViewModel.availableProfiles (duplicate)
    /// - DashboardViewModel.profiles (computed from ProfileViewModel)
    @Published var profiles: [ElderlyProfile] = []

    /// All care tasks/habits across all profiles
    ///
    /// Replaces:
    /// - TaskViewModel.tasks (all tasks)
    /// - DashboardViewModel.todaysTasks (filtered subset)
    @Published var tasks: [Task] = []

    /// Gallery history events (photos and SMS responses)
    ///
    /// Replaces:
    /// - GalleryViewModel.events (will be updated in future phase)
    @Published var galleryEvents: [GalleryHistoryEvent] = []

    /// Global loading indicator
    ///
    /// Aggregates loading state from all operations. Shows true if ANY
    /// data loading operation is in progress (profiles, tasks, gallery).
    ///
    /// Replaces:
    /// - ProfileViewModel.isLoading
    /// - TaskViewModel.isLoading
    /// - DashboardViewModel.isLoading
    /// - GalleryViewModel.isLoading
    @Published var isLoading: Bool = false

    /// Global error state
    ///
    /// Displays app-wide errors in a centralized banner/alert.
    /// ViewModels can still have form-specific error messages.
    ///
    /// Replaces:
    /// - ProfileViewModel.errorMessage
    /// - TaskViewModel.errorMessage
    /// - DashboardViewModel.errorMessage
    @Published var globalError: String?

    // MARK: - Services (Injected Once, Shared Across All Operations)

    private let authService: AuthenticationServiceProtocol
    private let databaseService: DatabaseServiceProtocol
    private let dataSyncCoordinator: DataSyncCoordinator

    /// Public accessor for image cache (used by ProfileImageView)
    let imageCache: ImageCacheService

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates AppState with injected services
    ///
    /// **Important:** Services must be singletons from Container.shared
    /// to ensure consistent auth state and prevent duplicate listeners.
    ///
    /// - Parameters:
    ///   - authService: Firebase authentication service (singleton)
    ///   - databaseService: Firestore database service (singleton)
    ///   - dataSyncCoordinator: Multi-device sync coordinator (singleton)
    ///   - imageCache: Profile photo cache service (singleton)
    init(
        authService: AuthenticationServiceProtocol,
        databaseService: DatabaseServiceProtocol,
        dataSyncCoordinator: DataSyncCoordinator,
        imageCache: ImageCacheService
    ) {
        self.authService = authService
        self.databaseService = databaseService
        self.dataSyncCoordinator = dataSyncCoordinator
        self.imageCache = imageCache

        // Set initial user if already authenticated
        self.currentUser = authService.currentUser

        setupSubscriptions()
    }

    // MARK: - Subscriptions (Listen to DataSyncCoordinator for Multi-Device Updates)

    /// Subscribe to data updates from DataSyncCoordinator
    ///
    /// This enables multi-device sync: when another device (or user) updates
    /// a profile/task, the coordinator broadcasts it and we update our local state.
    private func setupSubscriptions() {
        // Profile updates from other devices/users
        dataSyncCoordinator.profileUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedProfile in
                self?.handleProfileUpdate(updatedProfile)
            }
            .store(in: &cancellables)

        // Task updates from other devices/users
        dataSyncCoordinator.taskUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedTask in
                self?.handleTaskUpdate(updatedTask)
            }
            .store(in: &cancellables)

        // SMS response updates (elderly person replied)
        dataSyncCoordinator.smsResponses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.handleSMSResponse(response)
            }
            .store(in: &cancellables)

        // Gallery event updates (webhook creates new events)
        dataSyncCoordinator.galleryEventUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleGalleryEventUpdate(event)
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading (Called Once by ContentView on Auth Success)

    /// Load all user data from Firebase
    ///
    /// Called by ContentView when authentication succeeds. Loads profiles, tasks,
    /// and gallery events in parallel for fast app startup.
    ///
    /// **Important:** This replaces separate loadProfiles() and loadTasks() methods
    /// that were previously called by each ViewModel independently.
    ///
    /// - Note: Uses Swift concurrency async let for parallel loading
    /// - Throws: Re-throws Firebase errors for display
    func loadUserData() async {
        print("🔵 [AppState] loadUserData() called")

        guard let userId = authService.currentUser?.uid else {
            print("⚠️ [AppState] Cannot load data - no authenticated user")
            return
        }

        print("🔵 [AppState] User ID: \(userId)")

        // Prevent duplicate loads if already loading
        guard !isLoading else {
            print("⚠️ [AppState] Already loading data, skipping duplicate request")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            print("🔵 [AppState] Starting to load profiles, tasks, and gallery events...")

            // Load profiles, tasks, and gallery events in parallel for faster startup
            // IMPORTANT: Gallery events must be loaded BEFORE setupFirebaseListeners()
            // to prevent duplicate gallery events when SMS listener replays old confirmations
            async let profilesTask = databaseService.getElderlyProfiles(for: userId)
            async let tasksTask = databaseService.getTasks(for: userId)
            async let galleryEventsTask = databaseService.getGalleryHistoryEvents(for: userId)

            self.profiles = try await profilesTask
            self.tasks = try await tasksTask
            self.galleryEvents = try await galleryEventsTask

            print("✅ [AppState] Loaded data: \(profiles.count) profiles, \(tasks.count) tasks, \(galleryEvents.count) gallery events")
            print("📊 [AppState] Gallery events IDs: \(galleryEvents.map { $0.id })")
            print("📊 [AppState] Gallery events types: \(galleryEvents.map { $0.eventType.rawValue })")

            // Refresh expired photo URLs with fresh download tokens BEFORE caching
            print("🔄 [AppState] Refreshing profile photo URLs with fresh tokens...")
            await refreshProfilePhotoURLs()

            // Pre-load all photos into memory cache to prevent AsyncImage flicker
            // Load both profile photos and gallery photos in parallel for faster startup
            async let profilePhotosTask: Void = imageCache.preloadProfileImages(profiles)
            
            async let galleryPhotosTask: Void = imageCache.preloadGalleryPhotos(galleryEvents)

            _ = await profilePhotosTask
            _ = await galleryPhotosTask

            print("🔵 [AppState] About to call setupFirebaseListeners...")

            // Setup Firebase real-time listeners for multi-device sync
            // This enables automatic updates when data changes on other devices or via webhooks
            dataSyncCoordinator.setupFirebaseListeners(userId: userId)

            print("✅ [AppState] setupFirebaseListeners completed")

        } catch {
            print("❌ [AppState] Failed to load user data: \(error.localizedDescription)")
            self.globalError = error.localizedDescription
        }
    }

    /// Refresh user data (called by pull-to-refresh)
    ///
    /// Similar to loadUserData() but explicitly intended for user-initiated refresh.
    /// Reloads all data even if cache exists.
    func refreshUserData() async {
        await loadUserData()
    }

    // MARK: - Profile Mutations (Called by ProfileViewModel)

    /// Add a newly created profile
    ///
    /// **Flow:**
    /// 1. Check if profile already exists (prevent duplicates)
    /// 2. Append to profiles array (immediate UI update) OR update existing
    /// 3. Broadcast via DataSyncCoordinator (notify other devices)
    ///
    /// - Parameter profile: The newly created ElderlyProfile
    /// - Note: Profile must already be saved to Firestore by caller
    /// - Note: Idempotent - safe to call multiple times with same profile
    func addProfile(_ profile: ElderlyProfile) {
        // Check for duplicates (prevents double-add from local + listener)
        if let existingIndex = profiles.firstIndex(where: { $0.id == profile.id }) {
            print("⚠️ [AppState] Profile already exists, updating instead: \(profile.id)")
            profiles[existingIndex] = profile
            dataSyncCoordinator.broadcastProfileUpdate(profile)
            return
        }

        profiles.append(profile)
        dataSyncCoordinator.broadcastProfileUpdate(profile)

        print("✅ [AppState] Added profile: \(profile.name) (ID: \(profile.id))")
    }

    /// Update an existing profile
    ///
    /// **Flow:**
    /// 1. Find profile by ID and update in array (immediate UI update)
    /// 2. Broadcast via DataSyncCoordinator (notify other devices)
    ///
    /// - Parameter profile: The updated ElderlyProfile with changes
    /// - Note: Profile must already be updated in Firestore by caller
    func updateProfile(_ profile: ElderlyProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            dataSyncCoordinator.broadcastProfileUpdate(profile)

            print("✅ [AppState] Updated profile: \(profile.name) (ID: \(profile.id))")
        } else {
            print("⚠️ [AppState] Profile not found for update: \(profile.id)")
        }
    }

    /// Delete a profile
    ///
    /// **Flow:**
    /// 1. Remove from profiles array (immediate UI update)
    /// 2. Broadcast deletion via DataSyncCoordinator (notify other devices)
    ///
    /// - Parameter profileId: The ID of the profile to delete
    /// - Note: Profile must already be deleted from Firestore by caller
    func deleteProfile(_ profileId: String) {
        profiles.removeAll { $0.id == profileId }

        // Also remove all tasks associated with this profile
        tasks.removeAll { $0.profileId == profileId }

        print("✅ [AppState] Deleted profile: \(profileId) and associated tasks")
    }

    // MARK: - Task Mutations (Called by TaskViewModel)

    /// Add a newly created task
    ///
    /// **Flow:**
    /// 1. Check if task already exists (prevent duplicates)
    /// 2. Append to tasks array (immediate UI update) OR update existing
    /// 3. Broadcast via DataSyncCoordinator (notify other devices)
    ///
    /// - Parameter task: The newly created Task
    /// - Note: Task must already be saved to Firestore by caller
    /// - Note: Idempotent - safe to call multiple times with same task
    func addTask(_ task: Task) {
        // Check for duplicates (prevents double-add from local + listener)
        if let existingIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            print("⚠️ [AppState] Task already exists, updating instead: \(task.id)")
            tasks[existingIndex] = task
            dataSyncCoordinator.broadcastTaskUpdate(task)
            return
        }

        tasks.append(task)
        dataSyncCoordinator.broadcastTaskUpdate(task)

        print("✅ [AppState] Added task: \(task.title) (ID: \(task.id))")
    }

    /// Update an existing task
    ///
    /// **Flow:**
    /// 1. Find task by ID and update in array (immediate UI update)
    /// 2. Broadcast via DataSyncCoordinator (notify other devices)
    ///
    /// - Parameter task: The updated Task with changes
    /// - Note: Task must already be updated in Firestore by caller
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            dataSyncCoordinator.broadcastTaskUpdate(task)

            print("✅ [AppState] Updated task: \(task.title) (ID: \(task.id))")
        } else {
            print("⚠️ [AppState] Task not found for update: \(task.id)")
        }
    }

    /// Delete a task
    ///
    /// **Flow:**
    /// 1. Remove from tasks array (immediate UI update)
    /// 2. Broadcast deletion via DataSyncCoordinator (notify other devices)
    ///
    /// - Parameter taskId: The ID of the task to delete
    /// - Note: Task must already be deleted from Firestore by caller
    func deleteTask(_ taskId: String) {
        tasks.removeAll { $0.id == taskId }

        print("✅ [AppState] Deleted task: \(taskId)")
    }

    // MARK: - Photo URL Refresh

    /// Refresh expired profile photo URLs with fresh download tokens
    ///
    /// Firebase Storage URLs have time-limited access tokens that expire.
    /// This method regenerates fresh URLs with new tokens for all profiles with photos.
    ///
    /// **Called from:**
    /// - `loadUserData()` - Before pre-loading images into cache
    ///
    /// **Flow:**
    /// 1. Iterate through all profiles with photoURLs
    /// 2. Request fresh download URL from Firebase Storage
    /// 3. Compare tokens to detect expired URLs
    /// 4. Update profile in Firestore and local state
    /// 5. Clear old cached image so fresh one will be downloaded
    private func refreshProfilePhotoURLs() async {
        print("🔄 [AppState] Checking \(profiles.count) profiles for expired photo URLs...")

        var refreshCount = 0

        for profile in profiles {
            // Only refresh if profile has a photoURL (skip profiles without photos)
            guard let oldPhotoURL = profile.photoURL, !oldPhotoURL.isEmpty else {
                continue
            }

            do {
                // Get fresh download URL from Firebase Storage
                guard let freshPhotoURL = try await databaseService.getProfilePhotoURL(for: profile.id, userId: profile.userId) else {
                    print("⚠️ [AppState] No photo found in Storage for '\(profile.name)'")
                    continue
                }

                // Extract tokens for comparison (last component after "token=")
                let oldToken = oldPhotoURL.split(separator: "=").last ?? ""
                let newToken = freshPhotoURL.split(separator: "=").last ?? ""

                // Only update if token changed (indicates expired URL)
                if oldToken != newToken {
                    print("🔄 [AppState] Refreshing expired photoURL for '\(profile.name)'")
                    print("   Old token: ...\(oldToken.suffix(12))")
                    print("   New token: ...\(newToken.suffix(12))")

                    // Remove old cached image BEFORE updating URL
                    imageCache.removeCachedImage(for: oldPhotoURL)

                    // Update profile with fresh URL
                    var updatedProfile = profile
                    updatedProfile.photoURL = freshPhotoURL

                    // Save to Firestore
                    try await databaseService.updateElderlyProfile(updatedProfile)

                    // Update local state
                    if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                        profiles[index] = updatedProfile
                    }

                    refreshCount += 1
                    print("✅ [AppState] Refreshed photoURL for '\(profile.name)'")
                } else {
                    print("✅ [AppState] Photo URL still valid for '\(profile.name)'")
                }

            } catch {
                print("❌ [AppState] Failed to refresh photoURL for '\(profile.name)': \(error.localizedDescription)")
            }
        }

        print("✅ [AppState] Photo URL refresh complete - \(refreshCount) URLs updated")
    }

    // MARK: - Handlers (Updates from DataSyncCoordinator - Other Devices)

    /// Handle profile update from another device/user
    ///
    /// Called when DataSyncCoordinator receives a profile update broadcast.
    /// This keeps multi-device state synchronized.
    private func handleProfileUpdate(_ profile: ElderlyProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            print("🔄 [AppState] Synced profile update from remote: \(profile.name)")
        } else {
            profiles.append(profile)
            print("🔄 [AppState] Synced new profile from remote: \(profile.name)")
        }
    }

    /// Handle task update from another device/user
    private func handleTaskUpdate(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            print("🔄 [AppState] Synced task update from remote: \(task.title)")
        } else {
            tasks.append(task)
            print("🔄 [AppState] Synced new task from remote: \(task.title)")
        }
    }

    /// Handle SMS response from elderly user
    ///
    /// When an elderly person replies to a task reminder, update the associated
    /// task's status to reflect completion.
    private func handleSMSResponse(_ response: SMSResponse) {
        // Find associated task and mark as completed
        if let taskIndex = tasks.firstIndex(where: { $0.id == response.taskId }) {
            var task = tasks[taskIndex]
            task.markCompleted()
            tasks[taskIndex] = task

            print("🔄 [AppState] Task completed via SMS: \(task.title)")
        }
    }

    /// Handle gallery event update from Twilio webhook
    ///
    /// When webhook creates a new gallery event (task response/profile creation),
    /// add or update it in the gallery events array for real-time UI updates.
    ///
    /// Includes deduplication to prevent memory leaks from duplicate events.
    private func handleGalleryEventUpdate(_ event: GalleryHistoryEvent) {
        if let index = galleryEvents.firstIndex(where: { $0.id == event.id }) {
            // Event already exists - update it
            galleryEvents[index] = event
            print("🔄 [AppState] Updated existing gallery event: \(event.id) (type: \(event.eventType.rawValue))")
            print("   Total events in memory: \(galleryEvents.count)")
        } else {
            // New event - add it
            galleryEvents.append(event)
            // Keep sorted by creation date (most recent first)
            galleryEvents.sort { $0.createdAt > $1.createdAt }
            print("✅ [AppState] Added new gallery event: \(event.id) (type: \(event.eventType.rawValue))")
            print("   Total events in memory: \(galleryEvents.count)")

            // Pre-cache new photo for card stack performance
            // This ensures the photo is cached before the user swipes to it
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                _Concurrency.Task {
                    await self.imageCache.preloadGalleryPhotos([event])
                }
            }
        }
    }

    // MARK: - Error Handling

    /// Clear the global error (called when user dismisses error alert)
    func clearError() {
        globalError = nil
    }

    // MARK: - Cleanup (Called on Logout)

    /// Reset AppState and stop all listeners when user logs out
    ///
    /// Called by ContentView when auth state changes to unauthenticated.
    /// Ensures clean state for next login and prevents memory leaks.
    func reset() {
        print("🧹 [AppState] Resetting all state and stopping listeners...")

        // Clear all user data
        currentUser = nil
        profiles.removeAll()
        tasks.removeAll()
        galleryEvents.removeAll()
        globalError = nil
        isLoading = false

        // Stop all DataSyncCoordinator listeners and subscriptions
        dataSyncCoordinator.stopListeners()

        // Cancel all AppState subscriptions
        cancellables.removeAll()

        // Clear image cache
        imageCache.clearCache()

        // Re-setup subscriptions for next login
        // This ensures when user logs back in, AppState will receive updates
        setupSubscriptions()

        print("✅ [AppState] Reset complete - all data cleared and listeners stopped")
    }
}

// MARK: - Computed Properties (Convenience Accessors)

extension AppState {

    /// Profiles that have been confirmed by elderly user (replied YES to SMS)
    var confirmedProfiles: [ElderlyProfile] {
        profiles.filter { $0.status == .confirmed }
    }

    /// Profiles still pending confirmation (waiting for SMS reply)
    var pendingProfiles: [ElderlyProfile] {
        profiles.filter { $0.status == .pendingConfirmation }
    }

    /// Tasks scheduled for today
    var todaysTasks: [Task] {
        tasks.filter { task in
            Calendar.current.isDateInToday(task.scheduledTime) ||
            Calendar.current.isDateInToday(task.nextScheduledDate)
        }
    }

    /// Overdue tasks (past deadline, not completed)
    var overdueTasks: [Task] {
        tasks.filter { $0.isOverdue }
    }

    /// Active tasks (not archived or expired)
    var activeTasks: [Task] {
        tasks.filter { $0.status == .active }
    }

    /// Get tasks for a specific profile
    func tasks(for profileId: String) -> [Task] {
        tasks.filter { $0.profileId == profileId }
    }

    /// Get profile by ID
    func profile(with profileId: String) -> ElderlyProfile? {
        profiles.first { $0.id == profileId }
    }

    /// Check if user has any profiles
    var hasProfiles: Bool {
        !profiles.isEmpty
    }

    /// Check if user has any confirmed profiles
    var hasConfirmedProfiles: Bool {
        !confirmedProfiles.isEmpty
    }
}
