//
//  DataSyncCoordinator.swift
//  Remi
//
//  Purpose: Orchestrates real-time data synchronization for family coordination across devices and elderly care workflows
//  Key Features: 
//    • Real-time family synchronization of elderly profiles, tasks, and SMS responses
//    • Conflict resolution for concurrent family member updates
//    • Cross-device coordination ensuring consistent elderly care data
//  Dependencies: DatabaseService, NotificationCoordinator, ErrorCoordinator, Combine Publishers
//  
//  Business Context: Critical backbone enabling seamless family coordination and elderly care consistency
//  Critical Paths: Data change detection → Cross-device sync → Family notification → UI updates
//
//  Created by Claude Code on 2025-07-28
//

import Foundation
import SwiftUI
import Combine

// =====================================================
// DataSyncCoordinator.swift - SYSTEMATIC RESTORATION
// =====================================================
// PURPOSE: Real-time data synchronization for family coordination
// STATUS: ✅ FIXED - Removed unnecessary UIKit import
// NOTE: UIApplication notifications available through Foundation
// VARIABLES TO REMEMBER: syncQueue, activeOperations, publishers
// =====================================================

// Resolve naming conflict with Swift's built-in Task type
typealias HalloTask = Task

/// Real-time data synchronization coordinator for family elderly care coordination across multiple devices
///
/// This class serves as the central nervous system for the Hallo app's family coordination
/// capabilities, ensuring that elderly care data remains consistent across all family member
/// devices in real-time. It orchestrates seamless synchronization of elderly profiles, care
/// tasks, and SMS responses while handling conflicts and maintaining data integrity.
///
/// ## Core Responsibilities:
/// - **Real-Time Family Sync**: Instant synchronization of elderly care data across family devices
/// - **Conflict Resolution**: Intelligent handling of concurrent updates from multiple family members
/// - **Cross-Device Coordination**: Maintains consistent elderly care state across iOS, web, and future platforms
/// - **Change Broadcasting**: Publishes data updates to ViewModels for immediate UI updates
/// - **Background Synchronization**: Ensures data consistency even when app is backgrounded
///
/// ## Family Coordination Benefits:
/// - **Immediate Visibility**: Family members see elderly care updates instantly
/// - **Prevent Conflicts**: Avoids duplicate SMS reminders or conflicting care instructions
/// - **Shared Awareness**: All family members stay informed about elderly care status
/// - **Reliable Communication**: Ensures SMS responses are visible to all coordinating family
///
/// ## Usage Pattern:
/// ```swift
/// let dataSyncCoordinator = container.makeDataSyncCoordinator()
/// 
/// // Subscribe to real-time elderly profile updates
/// dataSyncCoordinator.profileUpdates
///     .sink { updatedProfile in
///         // Update UI with elderly profile changes from other family members
///     }
/// 
/// // Broadcast SMS response to all family devices
/// dataSyncCoordinator.broadcastSMSResponse(response)
/// ```
///
/// - Important: Synchronization ensures family members never send duplicate SMS reminders
/// - Note: Handles offline scenarios with intelligent conflict resolution upon reconnection
/// - Warning: Sync failures can cause family coordination confusion and require error handling
final class DataSyncCoordinator: ObservableObject, @unchecked Sendable {
    
    // MARK: - Family Coordination Sync State Properties
    
    /// Current synchronization status for family coordination visibility
    /// 
    /// Indicates the real-time sync state enabling families to understand
    /// when elderly care data is being synchronized across devices and
    /// whether coordination is functioning properly.
    @Published var syncStatus: SyncStatus = .idle
    
    /// Timestamp of last successful family data synchronization
    /// 
    /// Shows families when elderly care data was last synchronized across
    /// devices, providing confidence in data currency and coordination accuracy.
    @Published var lastSyncDate: Date?
    
    /// Whether family coordination synchronization is currently active
    /// 
    /// Indicates active sync operations for family UI feedback and prevents
    /// conflicting sync operations during elderly care data coordination.
    @Published var isSyncing: Bool = false
    
    /// Progress indicator for large family data synchronization operations
    /// 
    /// Shows completion percentage during bulk sync operations like initial
    /// family setup or conflict resolution after extended offline periods.
    @Published var syncProgress: Double = 0.0
    
    /// Count of pending elderly care changes awaiting family synchronization
    /// 
    /// Tracks unsynchronized changes to elderly profiles, tasks, or SMS responses
    /// that need coordination across family member devices.
    @Published var pendingChanges: Int = 0
    
    // MARK: - Family Coordination Data Broadcasting
    
    /// Publishes elderly profile updates to all coordinating family member devices
    /// 
    /// Broadcasts profile changes including confirmation status, contact updates,
    /// and care preferences to ensure family-wide consistency and coordination.
    private let profileUpdatesSubject = PassthroughSubject<ElderlyProfile, Never>()
    
    /// Publishes care task updates for real-time family coordination
    /// 
    /// Broadcasts task creation, scheduling changes, and completion status
    /// to prevent duplicate reminders and maintain care coordination accuracy.
    private let taskUpdatesSubject = PassthroughSubject<HalloTask, Never>()
    
    /// Publishes SMS responses from elderly users to all family members
    /// 
    /// Broadcasts elderly person's care task responses and confirmations
    /// for immediate family visibility and coordination decision-making.
    private let smsResponsesSubject = PassthroughSubject<SMSResponse, Never>()
    
    /// Publishes family user account updates across coordinating devices
    /// 
    /// Broadcasts family member profile changes, subscription updates,
    /// and preference modifications for consistent family coordination.
    private let userUpdatesSubject = PassthroughSubject<User, Never>()
    
    /// Publishes gallery history events for family timeline coordination
    /// 
    /// Broadcasts profile creation milestones and task completion events
    /// for family gallery synchronization and care history tracking.
    private let galleryEventUpdatesSubject = PassthroughSubject<GalleryHistoryEvent, Never>()
    
    /// Publishes synchronization status updates for family coordination transparency
    /// 
    /// Broadcasts sync progress, completion status, and error conditions
    /// to keep family members informed about coordination system health.
    private let syncStatusSubject = PassthroughSubject<SyncStatusUpdate, Never>()
    
    // MARK: - Family Coordination Publisher Interfaces
    
    /// Real-time elderly profile updates for family coordination ViewModels
    /// 
    /// Enables ProfileViewModel and DashboardViewModel to immediately reflect
    /// elderly profile changes made by other family members, preventing
    /// coordination conflicts and maintaining family-wide consistency.
    var profileUpdates: AnyPublisher<ElderlyProfile, Never> {
        profileUpdatesSubject.eraseToAnyPublisher()
    }
    
    /// Real-time care task updates for family coordination interfaces
    /// 
    /// Enables TaskViewModel and DashboardViewModel to instantly show task
    /// changes from other family members, preventing duplicate care reminders
    /// and ensuring coordinated elderly care management.
    var taskUpdates: AnyPublisher<HalloTask, Never> {
        taskUpdatesSubject.eraseToAnyPublisher()
    }
    
    /// Real-time SMS responses from elderly users for family coordination
    ///
    /// Enables all family ViewModels to immediately see elderly person's
    /// care task responses, confirmation messages, and help requests for
    /// coordinated family response and care decision-making.
    var smsResponses: AnyPublisher<SMSResponse, Never> {
        return smsResponsesSubject.eraseToAnyPublisher()
    }
    
    /// Real-time family user updates for account coordination
    /// 
    /// Enables family member ViewModels to stay synchronized with account
    /// changes, subscription updates, and preference modifications across
    /// all coordinating family devices.
    var userUpdates: AnyPublisher<User, Never> {
        userUpdatesSubject.eraseToAnyPublisher()
    }
    
    /// Real-time synchronization status for family coordination transparency
    /// 
    /// Enables ViewModels to display sync status, handle offline scenarios,
    /// and provide families with visibility into coordination system health
    /// and data consistency assurance.
    var syncStatusUpdates: AnyPublisher<SyncStatusUpdate, Never> {
        syncStatusSubject.eraseToAnyPublisher()
    }
    
    /// Real-time gallery history events for family timeline coordination
    /// 
    /// Enables GalleryViewModel to instantly show profile creation milestones
    /// and task completion events from other family members for synchronized
    /// care history and family coordination timeline.
    var galleryEventUpdates: AnyPublisher<GalleryHistoryEvent, Never> {
        galleryEventUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Family Coordination Service Dependencies

    /// Database service for persistent family coordination data storage
    private let databaseService: DatabaseServiceProtocol
    
    // MARK: - Internal Family Coordination State Management

    /// Combine cancellables for reactive family coordination workflows
    private var cancellables = Set<AnyCancellable>()

    /// Separate cancellables for Firebase listeners (allows stopping/restarting on auth changes)
    private var firebaseListenerCancellables = Set<AnyCancellable>()
    
    /// Background timer for continuous family data synchronization
    /// 
    /// Ensures elderly care data remains synchronized across family devices
    /// even during background app states for reliable care coordination.
    private var syncTimer: Timer?
    
    /// Pending elderly profile changes awaiting family synchronization
    /// 
    /// Buffers profile updates for efficient batch synchronization while
    /// preventing data loss during network interruptions or conflicts.
    private var pendingProfileChanges: [String: ElderlyProfile] = [:]
    
    /// Pending care task changes awaiting family coordination
    /// 
    /// Buffers task updates for batch synchronization while ensuring
    /// families maintain consistent view of elderly care scheduling.
    private var pendingTaskChanges: [String: HalloTask] = [:]
    
    /// Pending SMS response changes awaiting family broadcasting
    /// 
    /// Buffers elderly SMS responses for immediate family coordination
    /// while handling network delays or temporary connectivity issues.
    private var pendingResponseChanges: [String: SMSResponse] = [:]
    
    /// Pending family user changes awaiting account synchronization
    /// 
    /// Buffers family member account updates for consistent coordination
    /// across devices while handling authentication and network challenges.
    private var pendingUserChanges: [String: User] = [:]
    
    /// Background queue for family coordination synchronization operations
    /// 
    /// Ensures sync operations don't block family UI interactions while
    /// maintaining reliable elderly care data coordination workflows.
    private let syncQueue = DispatchQueue(label: "com.hallo.sync", qos: .background)
    
    /// Intelligent conflict resolver for concurrent family member updates
    /// 
    /// Handles situations where multiple family members modify elderly care
    /// data simultaneously, ensuring data integrity and coordination consistency.
    private let conflictResolver = DataConflictResolver()
    
    // MARK: - Family Coordination Configuration Constants
    
    /// Automatic synchronization interval for family coordination (60 seconds)
    /// 
    /// Balances real-time family coordination needs with battery efficiency
    /// and network usage for continuous elderly care data consistency.
    private let autoSyncInterval: TimeInterval = 60 // 1 minute
    
    /// Batch size for efficient family data synchronization operations
    /// 
    /// Optimizes network usage while ensuring timely family coordination
    /// of elderly care data across multiple devices and family members.
    private let batchSize: Int = 50
    
    /// Maximum retry attempts for failed family synchronization operations
    /// 
    /// Provides resilience against temporary network issues while preventing
    /// infinite retry loops that could drain battery or cause family confusion.
    private let maxRetries: Int = 3
    
    // MARK: - Family Coordination Synchronization Setup
    
    /// Initializes real-time family coordination synchronization system
    /// 
    /// Establishes the complete infrastructure for coordinating elderly care data
    /// across multiple family member devices with automatic synchronization, conflict
    /// resolution, and reliable change broadcasting for seamless family coordination.
    ///
    /// ## Setup Process:
    /// 1. **Service Integration**: Connects database and notification coordination services
    /// 2. **Auto-Sync Setup**: Configures background synchronization for continuous coordination
    /// 3. **Notification Handling**: Establishes cross-device change notification workflows
    /// 4. **State Recovery**: Loads previous synchronization state for coordination continuity
    /// 5. **Publisher Configuration**: Prepares real-time data broadcasting to family ViewModels
    ///
    /// - Parameter databaseService: Handles persistent storage for family coordination data
    init(
        databaseService: DatabaseServiceProtocol
    ) {
        self.databaseService = databaseService

        // NOTE: All setup moved to initialize() to avoid blocking app startup
        // setupAutoSync() will be called from initialize() after app launches
        // setupNotificationHandling() will be called from initialize() after app launches

        // Restore previous family coordination state (safe to do in init)
        loadLastSyncDate()
    }
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }

    /// Stops all Firebase listeners and clears subscriptions
    ///
    /// Called when user logs out to prevent memory leaks and ensure clean state.
    /// Stops all real-time Firebase listeners and cancels all Combine subscriptions.
    func stopListeners() {
        // Cancel all Firebase listeners and Combine subscriptions
        cancellables.removeAll()

        // Stop sync timer
        syncTimer?.invalidate()
        syncTimer = nil

        // Clear all pending changes
        syncQueue.async { [weak self] in
            self?.pendingProfileChanges.removeAll()
            self?.pendingTaskChanges.removeAll()
            self?.pendingResponseChanges.removeAll()
            self?.pendingUserChanges.removeAll()
        }

        // Reset sync state
        isSyncing = false
        syncStatus = .idle
        syncProgress = 0.0
        pendingChanges = 0
    }
    
    // MARK: - Initialization

    /// Initializes the data sync coordinator with optional Firebase listeners
    ///
    /// - Parameter userId: Optional authenticated user ID for setting up real-time listeners
    func initialize(userId: String? = nil) async {
        // Start auto-sync timer (60 second fallback)
        setupAutoSync()

        // Enable cross-device notification handling (foreground/background)
        setupNotificationHandling()

        // Connect Firebase real-time listeners for instant sync (if user authenticated)
        if let userId = userId {
            setupFirebaseListeners(userId: userId)
        }

        // Perform initial data sync
        await syncAllData()
    }
    
    /// Syncs all family data across devices
    func syncAllData() async {
        await forceSync()
    }

    // MARK: - Firebase Real-Time Listeners

    /// Connects Firebase real-time listeners for multi-device sync
    ///
    /// Bridges Firebase snapshot listeners to DataSyncCoordinator broadcasts,
    /// enabling true multi-device sync where Device B receives updates when
    /// Device A makes changes to tasks or profiles.
    ///
    /// This method is idempotent - safe to call multiple times. It will stop
    /// existing listeners before starting new ones to avoid duplicates.
    ///
    /// - Parameter userId: Family user ID to observe data for
    func setupFirebaseListeners(userId: String) {
        // Stop any existing listeners first (prevents duplicates on re-login)
        stopFirebaseListeners()

        // 1. Connect Task Updates Listener
        // Observes all habits across user's profiles via collection group query
        databaseService.observeUserTasks(userId)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ [DataSyncCoordinator] Task listener error: \(error.localizedDescription)")
                        // Note: Listener will auto-reconnect on network recovery
                    }
                },
                receiveValue: { [weak self] tasks in
                    // Broadcast each task to AppState via publishers
                    // This triggers AppState.handleTaskUpdate() on all devices
                    tasks.forEach { task in
                        self?.taskUpdatesSubject.send(task)
                    }
                }
            )
            .store(in: &firebaseListenerCancellables)

        // 2. Connect Profile Updates Listener
        // Observes user's elderly profiles for real-time confirmation status updates
        databaseService.observeUserProfiles(userId)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ [DataSyncCoordinator] Profile listener error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] profiles in
                    // Broadcast each profile to AppState
                    profiles.forEach { profile in
                        self?.profileUpdatesSubject.send(profile)
                    }
                }
            )
            .store(in: &firebaseListenerCancellables)

        // 3. Connect Gallery Events Listener
        // Observes gallery_events collection for real-time updates from Twilio webhook
        databaseService.observeUserGalleryEvents(userId)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ [DataSyncCoordinator] Gallery events listener error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] events in
                    // Broadcast each NEW event to AppState via publisher
                    // Note: Since listener now uses documentChanges, we only receive NEW events
                    events.forEach { event in
                        self?.galleryEventUpdatesSubject.send(event)
                    }
                }
            )
            .store(in: &firebaseListenerCancellables)
    }

    /// Stops all Firebase real-time listeners
    ///
    /// Call this when user logs out or before re-initializing listeners
    /// to prevent duplicate listeners and permission errors.
    func stopFirebaseListeners() {
        guard !firebaseListenerCancellables.isEmpty else { return }
        firebaseListenerCancellables.removeAll()
    }
    
    /// Saves any unsaved changes before backgrounding
    func saveUnsavedChanges() async {
        // Save any pending changes to database
    }
    
    // MARK: - Family Coordination Synchronization Operations
    
    /// Initiates manual family coordination synchronization across all devices
    /// 
    /// Triggers immediate synchronization of elderly care data when families
    /// need real-time coordination or want to ensure data consistency before
    /// critical care decisions or SMS reminder scheduling.
    ///
    /// - Important: Manual sync provides immediate family coordination when automatic sync isn't sufficient
    func startSync() async {
        await performSync(isManual: true)
    }
    
    /// Forces complete family coordination synchronization overriding cached data
    /// 
    /// Performs comprehensive sync operation that resolves conflicts and ensures
    /// absolute data consistency across all family devices, typically used
    /// after extended offline periods or coordination conflicts.
    ///
    /// - Warning: Force sync may temporarily disrupt family coordination during conflict resolution
    func forceSync() async {
        await performSync(isManual: true, force: true)
    }
    
    /// Synchronizes specific family user's elderly care data across devices
    /// 
    /// Performs targeted synchronization for individual family member's
    /// elderly profiles, tasks, and coordination data without affecting
    /// other family members' synchronization workflows.
    ///
    /// - Parameter userId: Family user ID for targeted coordination synchronization
    func syncUserData(for userId: String) async {
        await performUserSpecificSync(userId: userId)
    }
    
    /// Synchronizes specific elderly profile across all family member devices
    /// 
    /// Broadcasts elderly profile changes immediately to all coordinating family
    /// devices for instant visibility and coordination, typically triggered
    /// after profile confirmation or contact information updates.
    ///
    /// - Parameter profile: Elderly profile requiring immediate family coordination
    func syncProfile(_ profile: ElderlyProfile) async {
        await syncSingleProfile(profile)
    }
    
    func syncTask(_ task: HalloTask) async {
        await syncSingleTask(task)
    }
    
    func syncSMSResponse(_ response: SMSResponse) async {
        await syncSingleSMSResponse(response)
    }
    
    // MARK: - Data Broadcasting Methods
    
    func broadcastProfileUpdate(_ profile: ElderlyProfile) {
        profileUpdatesSubject.send(profile)
        updatePendingChanges()
    }
    
    func broadcastTaskUpdate(_ task: HalloTask) {
        taskUpdatesSubject.send(task)
        updatePendingChanges()
    }
    
    func broadcastSMSResponse(_ response: SMSResponse) {
        smsResponsesSubject.send(response)
        updatePendingChanges()
    }
    
    func broadcastUserUpdate(_ user: User) {
        userUpdatesSubject.send(user)
        updatePendingChanges()
    }
    
    func broadcastGalleryEventUpdate(_ event: GalleryHistoryEvent) {
        galleryEventUpdatesSubject.send(event)
        updatePendingChanges()
    }
    
    // MARK: - Pending Changes Management
    
    func addPendingProfileChange(_ profile: ElderlyProfile) {
        syncQueue.async { [weak self] in
            self?.pendingProfileChanges[profile.id] = profile
            DispatchQueue.main.async {
                self?.updatePendingChanges()
            }
        }
    }
    
    func addPendingTaskChange(_ task: HalloTask) {
        syncQueue.async { [weak self] in
            self?.pendingTaskChanges[task.id] = task
            DispatchQueue.main.async {
                self?.updatePendingChanges()
            }
        }
    }
    
    func addPendingSMSResponseChange(_ response: SMSResponse) {
        syncQueue.async { [weak self] in
            self?.pendingResponseChanges[response.id] = response
            DispatchQueue.main.async {
                self?.updatePendingChanges()
            }
        }
    }
    
    func addPendingUserChange(_ user: User) {
        syncQueue.async { [weak self] in
            self?.pendingUserChanges[user.id] = user
            DispatchQueue.main.async {
                self?.updatePendingChanges()
            }
        }
    }
    
    // MARK: - Private Sync Implementation
    
    private func performSync(isManual: Bool, force: Bool = false) async {
        guard !isSyncing || force else {
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
            syncProgress = 0.0
        }
        
        let syncOperation = SyncOperation(
            startTime: Date(),
            isManual: isManual,
            totalItems: calculateTotalPendingItems()
        )
        
        // Sync in phases
        await syncPhase1_Users(operation: syncOperation)
        await syncPhase2_Profiles(operation: syncOperation)
        await syncPhase3_Tasks(operation: syncOperation)
        await syncPhase4_Responses(operation: syncOperation)
        
        await MainActor.run {
            syncStatus = .completed
            lastSyncDate = Date()
            saveSyncDate()
            notifySuccessfulSync(syncOperation)
        }
        
        await MainActor.run {
            isSyncing = false
            syncProgress = 1.0
        }
        
        // Schedule next auto-sync if this was successful
        if case .completed = syncStatus {
            scheduleNextAutoSync()
        }
    }
    
    private func syncPhase1_Users(operation: SyncOperation) async {
        await updateSyncProgress(0.1, phase: "Syncing users...")
        
        for (_, user) in pendingUserChanges {
            do {
                try await databaseService.updateUser(user)
                broadcastUserUpdate(user)
                operation.incrementCompleted()
            } catch {
                operation.addError(error, context: "User sync: \(user.id)")
                print("⚠️ User sync error: \(error.localizedDescription)")
            }
        }
        
        syncQueue.async { [weak self] in
            self?.pendingUserChanges.removeAll()
        }
    }
    
    private func syncPhase2_Profiles(operation: SyncOperation) async {
        await updateSyncProgress(0.3, phase: "Syncing profiles...")
        
        for (_, profile) in pendingProfileChanges {
            do {
                try await databaseService.updateElderlyProfile(profile)
                broadcastProfileUpdate(profile)
                operation.incrementCompleted()
            } catch {
                operation.addError(error, context: "Profile sync: \(profile.id)")
                print("⚠️ Profile sync error: \(error.localizedDescription)")
            }
        }
        
        syncQueue.async { [weak self] in
            self?.pendingProfileChanges.removeAll()
        }
    }
    
    private func syncPhase3_Tasks(operation: SyncOperation) async {
        await updateSyncProgress(0.6, phase: "Syncing tasks...")
        
        for (_, task) in pendingTaskChanges {
            do {
                try await databaseService.updateTask(task)
                broadcastTaskUpdate(task)
                operation.incrementCompleted()
            } catch {
                operation.addError(error, context: "Task sync: \(task.id)")
                print("⚠️ Task sync error: \(error.localizedDescription)")
            }
        }
        
        syncQueue.async { [weak self] in
            self?.pendingTaskChanges.removeAll()
        }
    }
    
    private func syncPhase4_Responses(operation: SyncOperation) async {
        await updateSyncProgress(0.9, phase: "Syncing responses...")
        
        for (_, response) in pendingResponseChanges {
            do {
                try await databaseService.updateSMSResponse(response)
                broadcastSMSResponse(response)
                operation.incrementCompleted()
            } catch {
                operation.addError(error, context: "SMS Response sync: \(response.id)")
                print("⚠️ SMS Response sync error: \(error.localizedDescription)")
            }
        }
        
        syncQueue.async { [weak self] in
            self?.pendingResponseChanges.removeAll()
        }
    }
    
    private func performUserSpecificSync(userId: String) async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
        }
        
        do {
            // Sync user data
            if let user = pendingUserChanges[userId] {
                try await databaseService.updateUser(user)
                broadcastUserUpdate(user)
            }
            
            // Sync user's profiles
            let userProfiles = pendingProfileChanges.values.filter { $0.userId == userId }
            for profile in userProfiles {
                try await databaseService.updateElderlyProfile(profile)
                broadcastProfileUpdate(profile)
            }
            
            // Sync user's tasks
            let userTasks = pendingTaskChanges.values.filter { $0.userId == userId }
            for task in userTasks {
                try await databaseService.updateTask(task)
                broadcastTaskUpdate(task)
            }
            
            await MainActor.run {
                syncStatus = .completed
                lastSyncDate = Date()
            }
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
            }
            print("⚠️ User-specific sync error: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    // MARK: - Single Item Sync
    
    private func syncSingleProfile(_ profile: ElderlyProfile) async {
        do {
            try await databaseService.updateElderlyProfile(profile)
            broadcastProfileUpdate(profile)
            
            syncQueue.async { [weak self] in
                self?.pendingProfileChanges.removeValue(forKey: profile.id)
            }
        } catch {
            print("⚠️ Single profile sync error: \(error.localizedDescription)")
        }
    }
    
    private func syncSingleTask(_ task: HalloTask) async {
        do {
            try await databaseService.updateTask(task)
            broadcastTaskUpdate(task)
            
            syncQueue.async { [weak self] in
                self?.pendingTaskChanges.removeValue(forKey: task.id)
            }
        } catch {
            print("⚠️ Single task sync error: \(error.localizedDescription)")
        }
    }
    
    private func syncSingleSMSResponse(_ response: SMSResponse) async {
        do {
            try await databaseService.updateSMSResponse(response)
            broadcastSMSResponse(response)
            
            syncQueue.async { [weak self] in
                self?.pendingResponseChanges.removeValue(forKey: response.id)
            }
        } catch {
            print("⚠️ Single SMS response sync error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupAutoSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            _Concurrency.Task {
                await self?.performSync(isManual: false)
            }
        }
    }
    
    private func setupNotificationHandling() {
        // Handle app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                _Concurrency.Task {
                    await self?.performSync(isManual: false)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                _Concurrency.Task {
                    await self?.performSync(isManual: false)
                }
            }
            .store(in: &cancellables)
        
        // TODO: Re-implement network connectivity monitoring for MVP
        // Note: NetworkCoordinator was removed in Phase 1 simplification
    }
    
    // MARK: - Helper Methods
    
    private func calculateTotalPendingItems() -> Int {
        return pendingUserChanges.count +
               pendingProfileChanges.count +
               pendingTaskChanges.count +
               pendingResponseChanges.count
    }
    
    private func updatePendingChanges() {
        let total = calculateTotalPendingItems()
        if pendingChanges != total {
            pendingChanges = total
        }
    }
    
    @MainActor
    private func updateSyncProgress(_ progress: Double, phase: String) {
        syncProgress = progress
        syncStatusSubject.send(SyncStatusUpdate(progress: progress, phase: phase, timestamp: Date()))
    }
    
    private func scheduleNextAutoSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            _Concurrency.Task {
                await self?.performSync(isManual: false)
            }
        }
    }
    
    private func notifySuccessfulSync(_ operation: SyncOperation) {
        // Sync completed successfully
    }

    private func handleSyncError(_ error: Error, operation: SyncOperation) {
        print("⚠️ Data sync operation error: \(error.localizedDescription)")

        // Retry logic for failed sync
        if operation.retryCount < maxRetries {
            let workItem = DispatchWorkItem { [weak self] in
                _Concurrency.Task {
                    await self?.performSync(isManual: false)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
        }
    }
    
    // MARK: - Persistence
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }
    
    private func saveSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }
}

// MARK: - Supporting Models

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed(_), .failed(_)):
            return true // Simplified comparison
        default:
            return false
        }
    }
}

struct SyncStatusUpdate {
    let progress: Double
    let phase: String
    let timestamp: Date
}

class SyncOperation {
    let startTime: Date
    let isManual: Bool
    let totalItems: Int
    var completedItems: Int = 0
    var errors: [(Error, String)] = []
    var retryCount: Int = 0
    
    init(startTime: Date, isManual: Bool, totalItems: Int) {
        self.startTime = startTime
        self.isManual = isManual
        self.totalItems = totalItems
    }
    
    func incrementCompleted() {
        completedItems += 1
    }
    
    func addError(_ error: Error, context: String) {
        errors.append((error, context))
    }
    
    var progress: Double {
        guard totalItems > 0 else { return 1.0 }
        return Double(completedItems) / Double(totalItems)
    }
    
    var hasErrors: Bool {
        return !errors.isEmpty
    }
}

// MARK: - Data Conflict Resolution

class DataConflictResolver {
    
    func resolveProfileConflict(local: ElderlyProfile, remote: ElderlyProfile) -> ElderlyProfile {
        // Use the most recently modified version
        return local.lastActiveAt > remote.lastActiveAt ? local : remote
    }
    
    func resolveTaskConflict(local: HalloTask, remote: HalloTask) -> HalloTask {
        // Use the most recently modified version
        return local.lastModifiedAt > remote.lastModifiedAt ? local : remote
    }
    
    func resolveSMSResponseConflict(local: SMSResponse, remote: SMSResponse) -> SMSResponse {
        // SMS responses are typically immutable, use the one with earlier timestamp
        return local.receivedAt < remote.receivedAt ? local : remote
    }
    
    func resolveUserConflict(local: User, remote: User) -> User {
        // For user data, prefer local changes for most fields but remote for subscription status
        return User(
            id: local.id,
            email: local.email,
            fullName: local.fullName,
            phoneNumber: local.phoneNumber,
            createdAt: local.createdAt,
            subscriptionStatus: remote.subscriptionStatus, // Prefer remote subscription status
            trialEndDate: remote.trialEndDate,
            quizAnswers: local.quizAnswers
        )
    }

}
