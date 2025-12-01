//
//  DashboardViewModel.swift
//  Hallo
//
//  Purpose: Central family oversight hub for daily elderly care tasks and SMS response monitoring
//  Key Features: 
//    • Real-time task completion tracking across all elderly profiles
//    • SMS response monitoring with overdue task identification
//    • Family coordination dashboard with daily progress analytics
//  Dependencies: DatabaseService, AuthenticationService, DataSyncCoordinator
//  
//  Business Context: Primary family interface for monitoring elderly care and SMS engagement
//  Critical Paths: Daily task overview → SMS response tracking → Family alerts → Care coordination
//
//  Created by Claude Code on 2025-07-28
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// Central family dashboard for monitoring daily elderly care tasks and SMS response tracking
///
/// This ViewModel serves as the primary oversight interface for families managing elderly
/// care reminders. It provides real-time visibility into task completion, SMS responses,
/// and care adherence across all elderly family members, enabling proactive family
/// coordination and intervention when needed.
///
/// ## Key Responsibilities:
/// - **Daily Task Oversight**: Real-time monitoring of all scheduled care tasks across elderly profiles
/// - **SMS Response Tracking**: Instant visibility into elderly SMS responses and completion status  
/// - **Overdue Task Management**: Proactive identification and family alerts for missed care tasks
/// - **Family Coordination**: Cross-device synchronization of care status and family notifications
/// - **Progress Analytics**: Weekly trends and completion rate tracking for care optimization
///
/// ## Elderly Care Considerations:
/// - **Non-Intrusive Monitoring**: Observes care without overwhelming elderly users with notifications
/// - **Family Peace of Mind**: Provides clear visibility into elderly adherence and wellbeing
/// - **Timely Intervention**: Enables families to step in when care tasks are missed
/// - **Positive Reinforcement**: Celebrates completion streaks and successful care patterns
///
/// ## Usage Example:
/// ```swift
/// let dashboardViewModel = container.makeDashboardViewModel()
/// // Automatically loads today's tasks and SMS responses
/// let todaysTasks = dashboardViewModel.todaysTasks
/// let overdueCount = dashboardViewModel.overdueTasks.count
/// ```
///
/// - Important: Dashboard updates in real-time as elderly users respond to SMS reminders
/// - Note: Automatically refreshes every minute to ensure current care status visibility
/// - Warning: Overdue task alerts require family intervention to prevent care gaps
@MainActor
final class DashboardViewModel: ObservableObject, AppStateViewModel {
    
    // MARK: - Dashboard State Properties
    
    /// Loading state for dashboard data aggregation
    /// 
    /// This property shows loading during:
    /// - Initial dashboard data loading across all elderly profiles
    /// - Daily task compilation and SMS response correlation
    /// - Analytics calculation and progress trend analysis
    ///
    /// Used by families to understand when dashboard information is being updated.
    @Published var isLoading = false
    
    /// User-friendly error messages for dashboard operation failures
    /// 
    /// This property displays context-aware error messages when:
    /// - Task data loading fails across profiles
    /// - SMS response synchronization encounters issues
    /// - Analytics calculation fails or times out
    ///
    /// Used by families to understand dashboard data reliability issues.
    @Published var errorMessage: String?
    
    /// Timestamp of last successful dashboard data refresh
    /// 
    /// Shows families when dashboard information was last updated.
    /// Updated automatically every minute and manually on pull-to-refresh.
    /// Critical for families to trust dashboard data currency.
    @Published var lastRefresh = Date()
    
    /// Selected profile ID for task filtering
    ///
    /// When set, tasks are filtered to show only those belonging to this profile.
    /// Updated by DashboardView when user selects different profile.
    /// Used to implement profile-specific task display as requested.
    @Published var selectedProfileId: String? = nil

    /// Tracks if user has ever made an explicit profile selection
    /// Used to prevent auto-selecting after user has dereferenced
    private var hasUserSelectedProfile = false

    // MARK: - Family Care Monitoring Properties
    
    /// All care tasks scheduled for the selected date across elderly profiles
    /// 
    /// Compiled from all confirmed elderly profiles, showing:
    /// - Task details with scheduled times
    /// - Associated elderly profile information
    /// - SMS response status and completion tracking
    /// - Overdue status for family intervention alerts
    ///
    /// Used by families to monitor daily care adherence across all elderly members.
    @Published var todaysTasks: [DashboardTask] = []
    
    // REMOVED: profiles property - now managed solely by ProfileViewModel
    // This eliminates duplicate state and race conditions between ViewModels
    
    /// Recent SMS responses from elderly family members (last 10)
    ///
    /// Shows families real-time engagement with care reminders:
    /// - Task completion confirmations (YES, DONE)
    /// - Photo responses for visual proof tasks
    /// - Profile confirmation responses
    /// - Help requests or confusion indicators
    ///
    /// Updated immediately as elderly users respond to SMS reminders.
    @Published var recentResponses: [SMSResponse] = []

    // MARK: - Performance Caching

    /// In-memory cache for completed tasks to reduce redundant Firebase queries
    /// Cached data expires after 5 minutes to ensure freshness while reducing network calls
    private var cachedCompletedTasks: [DashboardTask]?

    /// Timestamp when cache was last populated
    /// Used to determine cache validity and expiration
    private var cacheTimestamp: Date?

    /// Duration in seconds that cached data remains valid (5 minutes)
    /// Balance between performance and real-time updates
    private let cacheValidDuration: TimeInterval = 300
    
    /// Elderly profiles awaiting SMS confirmation from family members
    /// 
    /// These profiles cannot receive task reminders until elderly person
    /// responds YES to SMS confirmation. Shows families which profiles
    /// need follow-up or explanation to complete onboarding.
    @Published var pendingConfirmations: [ElderlyProfile] = []
    
    /// Care tasks that have exceeded their deadline without completion
    /// 
    /// Critical family alert system identifying:
    /// - Medication reminders not acknowledged by elderly users
    /// - Safety check tasks missed beyond acceptable timeframe
    /// - Exercise or social tasks requiring family intervention
    ///
    /// Triggers family notifications and coordination workflows.
    @Published var overdueTasks: [DashboardTask] = []
    
    // MARK: - Family Care Analytics Properties
    
    /// Comprehensive summary of today's care task performance
    /// 
    /// Aggregated metrics across all elderly profiles including:
    /// - Total tasks scheduled vs completed
    /// - Active profile count and confirmation status
    /// - Completion rate for family reassurance
    /// - Overdue task count for intervention priority
    ///
    /// Updated in real-time as elderly users complete tasks via SMS.
    @Published var todaysSummary: DashboardSummary = DashboardSummary()
    
    /// Weekly care adherence trends and family progress tracking
    /// 
    /// Shows families longer-term care patterns including:
    /// - 7-day completion rate trends
    /// - Consistency streaks for positive reinforcement
    /// - Daily completion patterns for routine optimization
    /// - Overall care engagement metrics
    ///
    /// Used by families to understand care routine effectiveness.
    
    // MARK: - Dashboard Navigation Properties
    
    /// Currently selected date for task and response review
    /// 
    /// Allows families to review historical care adherence and SMS responses.
    /// Defaults to today but supports navigation to review past performance
    /// or preview upcoming scheduled care tasks.
    @Published var selectedDate = Date()
    
    /// Controls date picker presentation for historical review
    @Published var showingDatePicker = false
    
    /// Controls notification center presentation
    @Published var showingNotifications = false
    
    /// Pull-to-refresh loading state for manual dashboard updates
    /// 
    /// Shows families when they've initiated a manual refresh of dashboard
    /// data beyond the automatic 60-second refresh cycle.
    @Published var refreshing = false
    
    // MARK: - Quick Action State Properties
    
    /// Controls quick task creation modal for urgent care reminders
    /// 
    /// Enables families to rapidly create medication or safety reminders
    /// without navigating through full task creation workflow.
    @Published var showingQuickAddTask = false
    
    /// Controls profiles overview modal for family member status
    @Published var showingProfilesList = false
    
    /// Controls detailed analytics view for care pattern analysis
    
    // MARK: - Service Dependencies
    
    /// Database service for task and response data aggregation
    private let databaseService: DatabaseServiceProtocol
    
    
    /// Authentication service for family user context and permissions
    private let authService: AuthenticationServiceProtocol
    
    /// Coordinator for real-time task and SMS response synchronization
    private let dataSyncCoordinator: DataSyncCoordinator
    
    /// Logger for dashboard operations tracking and error diagnosis
    private let logger = Logger(subsystem: "com.halloo.app", category: "Dashboard")

    /// ProfileViewModel reference for accessing profiles (single source of truth)
    /// Dashboard reads profiles but does not manage them
    // PHASE 4: Migrating to AppState
    private weak var profileViewModel: ProfileViewModel?  // TODO Phase 5: Remove completely
    weak var appState: AppState?

    /// Computed property to access profiles from ProfileViewModel
    private var profiles: [ElderlyProfile] {
        return profileViewModel?.profiles ?? []
    }

    // MARK: - Internal Dashboard Coordination Properties
    
    /// Combine cancellables for reactive dashboard data coordination
    private var cancellables = Set<AnyCancellable>()
    
    /// Auto-refresh timer for continuous care monitoring
    /// 
    /// Updates dashboard data every 60 seconds to ensure families have
    /// current visibility into elderly care task completion and SMS responses.
    /// Critical for timely family intervention when care tasks are missed.
    private var refreshTimer: Timer?
    
    // MARK: - Family Care Dashboard Status Properties
    
    /// Overall status of today's elderly care task coordination
    /// 
    /// Provides families with immediate understanding of care situation:
    /// - .loading: Dashboard data is being compiled
    /// - .noProfiles: No elderly profiles configured yet
    /// - .noTasksToday: No care tasks scheduled for selected date
    /// - .active: Care tasks in progress, elderly users responding
    /// - .allComplete: All care tasks completed successfully
    /// - .hasOverdue: Critical alert - care tasks missed, family intervention needed
    var dashboardStatus: DashboardStatus {
        if isLoading {
            return .loading
        }
        
        if todaysTasks.isEmpty {
            return profiles.isEmpty ? .noProfiles : .noTasksToday
        }
        
        let completedTasks = todaysTasks.filter { $0.isCompleted }
        let totalTasks = todaysTasks.count
        
        // Priority check: Overdue tasks require immediate family attention
        if !overdueTasks.isEmpty {
            return .hasOverdue
        }
        
        if completedTasks.count == totalTasks {
            return .allComplete
        }
        
        return .active
    }
    
    /// User-friendly status message for family dashboard communication
    /// 
    /// Translates dashboard status into clear, actionable family guidance:
    /// - Progress updates for active care coordination
    /// - Celebration messages for successful care completion
    /// - Urgent alerts for overdue tasks requiring intervention
    /// - Onboarding guidance for new family users
    var statusMessage: String {
        switch dashboardStatus {
        case .loading:
            return "Loading today's tasks..."
        case .noProfiles:
            return "Create your first elderly profile to get started"
        case .noTasksToday:
            return "No tasks scheduled for today"
        case .active:
            let remaining = todaysTasks.filter { !$0.isCompleted }.count
            return "\(remaining) task\(remaining == 1 ? "" : "s") remaining today"
        case .allComplete:
            return "All tasks completed for today! 🎉"
        case .hasOverdue:
            let overdueCount = overdueTasks.count
            return "\(overdueCount) overdue task\(overdueCount == 1 ? "" : "s") need attention"
        }
    }
    
    /// Whether families can create new care tasks for elderly members
    /// 
    /// Checks if any elderly profiles are confirmed and ready to receive
    /// SMS reminders. Used to enable/disable task creation workflows.
    var canAddTask: Bool {
        !profiles.filter { $0.status == .confirmed }.isEmpty
    }
    
    /// Time-appropriate greeting for family dashboard personalization
    /// 
    /// Provides warm, personal touch to family care coordination interface.
    /// Updates based on family member's local time for natural interaction.
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }
    
    /// Tasks that are upcoming and not yet completed for today (filtered by selected profile)
    var todaysUpcomingTasks: [DashboardTask] {
        let profileFilteredTasks = filterTasksBySelectedProfile(todaysTasks)
        return profileFilteredTasks.filter { !$0.isCompleted && !$0.isOverdue }
    }
    
    /// Tasks that have been completed today (filtered by selected profile)
    /// Uses 5-minute in-memory cache to reduce redundant computations
    var todaysCompletedTasks: [DashboardTask] {
        // Check if cache is valid
        if let cached = cachedCompletedTasks,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            // Return cached data filtered by selected profile
            return filterTasksBySelectedProfile(cached)
        }

        // Cache miss - compute fresh data
        let allCompleted = todaysTasks.filter { $0.isCompleted }

        // Update cache with unfiltered completed tasks
        cachedCompletedTasks = allCompleted
        cacheTimestamp = Date()

        // Return profile-filtered results
        return filterTasksBySelectedProfile(allCompleted)
    }
    
    // MARK: - Family Care Dashboard Setup
    
    /// Initializes family dashboard with elderly-care-optimized monitoring and analytics
    /// 
    /// Sets up the complete infrastructure for real-time family oversight of elderly
    /// care tasks, SMS responses, and adherence tracking. Configures automatic refresh
    /// cycles and cross-device synchronization for comprehensive family coordination.
    ///
    /// ## Setup Process:
    /// 1. **Service Integration**: Connects database, analytics, and authentication services
    /// 2. **Real-Time Sync**: Establishes live task and SMS response monitoring
    /// 3. **Auto-Refresh**: Configures 60-second refresh cycle for current care status
    /// 4. **Initial Load**: Loads today's tasks, profiles, and recent SMS responses
    /// 5. **Analytics Setup**: Prepares weekly progress and completion rate tracking
    ///
    /// - Parameter databaseService: Handles task and response data aggregation
    /// - Parameter authService: Provides family user context and permissions
    /// - Parameter dataSyncCoordinator: Synchronizes real-time care data across family devices
    init(
        databaseService: DatabaseServiceProtocol,
        authService: AuthenticationServiceProtocol,
        dataSyncCoordinator: DataSyncCoordinator,
        profileViewModel: ProfileViewModel? = nil
    ) {
        self.databaseService = databaseService
        self.authService = authService
        self.dataSyncCoordinator = dataSyncCoordinator
        self.profileViewModel = profileViewModel

        // Enable real-time family and elderly care data synchronization
        setupDataSync()

        // Configure continuous monitoring for timely family intervention
        setupAutoRefresh()

        // Load initial dashboard data for immediate family visibility
        loadDashboardData()
    }

    /// PHASE 4: Set AppState reference after initialization (preferred method)
    func setAppState(_ appState: AppState) {
        self.appState = appState

        // Auto-select first profile if available immediately
        updateProfileSelection(from: appState.profiles)

        // Subscribe to profile changes from AppState (single source of truth)
        appState.$profiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profiles in
                self?.updateProfileSelection(from: profiles)
            }
            .store(in: &cancellables)

        // Subscribe to task changes from AppState (single source of truth)
        appState.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateTasksFromAppState(tasks: tasks, profiles: appState.profiles)
            }
            .store(in: &cancellables)
    }

    /// DEPRECATED: Set ProfileViewModel reference (use setAppState instead)
    /// Kept for backward compatibility during Phase 4 transition
    func setProfileViewModel(_ profileViewModel: ProfileViewModel) {
        self.profileViewModel = profileViewModel

        // If AppState not set yet, auto-select from ProfileViewModel
        if appState == nil {
            updateProfileSelection(from: profileViewModel.profiles)
        }
    }

    /// Update profile selection and pending confirmations when profiles change
    private func updateProfileSelection(from profiles: [ElderlyProfile]) {
        // Auto-select first profile ONLY on initial load (when user hasn't made a choice yet)
        // Once user explicitly selects or deselects, respect their choice forever
        if self.selectedProfileId == nil && !profiles.isEmpty && !hasUserSelectedProfile {
            self.selectedProfileId = profiles[0].id
            hasUserSelectedProfile = true  // Mark as user-initiated choice
        }

        // Update pending confirmations
        self.pendingConfirmations = profiles.filter { $0.status == .pendingConfirmation }

        // Reload dashboard data to re-filter tasks with new profiles
        if !profiles.isEmpty {
            loadDashboardData()
        } else {
            // Just update UI if no profiles yet
            self.updateDashboardSummary()
        }
    }

    /// Update tasks from AppState (single source of truth)
    /// Called when AppState.tasks changes due to real-time updates
    private func updateTasksFromAppState(tasks: [Task], profiles: [ElderlyProfile]) {
        let calendar = Calendar.current
        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDayStart)!

        // Transform AppState tasks into DashboardTasks for today
        let dashboardTasks = tasks.compactMap { task -> DashboardTask? in
            guard task.status == .active else {
                return nil
            }

            guard let profile = profiles.first(where: { $0.id == task.profileId }) else {
                return nil
            }

            guard profile.status == .confirmed else {
                return nil
            }

            // Check if task is scheduled for selected date
            guard task.isScheduledFor(date: selectedDate) else {
                return nil
            }

            // Filter out tasks completed today - they should not appear in "upcoming habits"
            // For recurring tasks, check if lastCompletedAt is within today's date range
            if let lastCompletedAt = task.lastCompletedAt {
                if lastCompletedAt >= selectedDayStart && lastCompletedAt < selectedDayEnd {
                    // Task was completed today, don't show in upcoming list
                    return nil
                }
            }

            let scheduledTime = task.getScheduledTimeFor(date: selectedDate)

            // Note: SMS responses are not available in this sync path
            // Tasks will show as incomplete until SMS response arrives separately
            return DashboardTask(
                task: task,
                profile: profile,
                scheduledTime: scheduledTime,
                response: nil,  // Will be populated by SMS response handler
                isOverdue: isTaskOverdue(task: task, scheduledTime: scheduledTime)
            )
        }

        self.todaysTasks = dashboardTasks.sorted { $0.scheduledTime < $1.scheduledTime }

        // Invalidate cache when tasks change
        self.cachedCompletedTasks = nil
        self.cacheTimestamp = nil

        // Update dashboard summary and overdue tasks
        self.updateDashboardSummary()
        self.identifyOverdueTasks()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    private func setupDataSync() {
        // NOTE: Profile updates handled by ProfileViewModel
        // Dashboard reactively accesses profiles via computed property
        // No need to subscribe to profile updates here
        
        // Listen for task updates
        dataSyncCoordinator.taskUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTasksData()
            }
            .store(in: &cancellables)
        
        // Listen for SMS responses
        dataSyncCoordinator.smsResponses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.handleSMSResponse(response)
            }
            .store(in: &cancellables)
        
        // Date selection changes
        $selectedDate
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTasksData()
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in
                self?.refreshData()
            }
        }
    }
    
    // MARK: - Dashboard Data Aggregation
    
    /// Loads comprehensive dashboard data for family care oversight
    ///
    /// This method orchestrates the complete data aggregation process that enables
    /// families to monitor elderly care tasks, SMS responses, and adherence patterns.
    /// The process includes parallel loading of tasks, profiles, responses, and analytics
    /// for comprehensive family care coordination.
    ///
    /// ## Process Flow:
    /// 1. **Profile Loading**: Load all elderly profiles with confirmation status
    /// 2. **Task Compilation**: Aggregate today's tasks across all confirmed profiles
    /// 3. **Response Correlation**: Match SMS responses to tasks for completion tracking
    /// 4. **Analytics Calculation**: Generate weekly progress and completion trends
    /// 5. **Status Update**: Update dashboard summary and overdue task identification
    ///
    /// - Important: Loads data in parallel for optimal family dashboard performance
    /// - Note: Automatically identifies overdue tasks requiring family intervention
    /// - Warning: Dashboard accuracy depends on real-time SMS response synchronization
    func loadDashboardData() {
        _Concurrency.Task {
            await loadDashboardDataAsync()
        }
    }
    
    /*
    BUSINESS LOGIC: Parallel Dashboard Data Loading for Family Care Coordination
    
    CONTEXT: Families need immediate, comprehensive visibility into elderly care status.
    Dashboard loading must be fast and reliable to enable timely family intervention
    when care tasks are missed or elderly users need assistance.
    
    DESIGN DECISION: Parallel data loading with task grouping
    - Alternative 1: Sequential loading (rejected - too slow for family urgency)
    - Alternative 2: Background refresh only (rejected - families need immediate data)  
    - Chosen Solution: Parallel loading with immediate UI updates
    
    FAMILY IMPACT: Fast dashboard loading enables real-time family coordination.
    When elderly users complete tasks via SMS, families see updates within seconds,
    building confidence in the care monitoring system.
    
    CARE COORDINATION: Dashboard aggregates data from multiple elderly profiles,
    providing families with unified view of all care responsibilities and enabling
    prioritized intervention for the most critical missed tasks.
    */
    private func loadDashboardDataAsync() async {
        isLoading = true
        errorMessage = nil

        // Load dashboard components in parallel for optimal family experience
        // NOTE: Profiles are loaded by ProfileViewModel, not DashboardViewModel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTodaysTasks() }
            group.addTask { await self.loadRecentResponses() }
        }

        // Data loading complete

        await MainActor.run {
            // Aggregate data for family care coordination
            self.updateDashboardSummary()
            self.identifyOverdueTasks() // Critical for family intervention alerts
            self.lastRefresh = Date()
            self.isLoading = false
        }
    }
    
    // REMOVED: loadProfiles() method - profiles now loaded by ProfileViewModel only
    // DashboardViewModel will receive profile data via ProfileViewModel injection
    private func loadPendingConfirmations(profiles: [ElderlyProfile]) async {
        // Extract pending confirmations from profiles passed from ProfileViewModel
        await MainActor.run {
            self.pendingConfirmations = profiles.filter { $0.status == .pendingConfirmation }

            // Auto-select first profile ONLY on initial load (when user hasn't made a choice yet)
            // Once user explicitly selects or deselects, respect their choice forever
            if self.selectedProfileId == nil && !profiles.isEmpty && !hasUserSelectedProfile {
                self.selectedProfileId = profiles[0].id
                hasUserSelectedProfile = true  // Mark as user-initiated choice
            }
        }
    }
    
    private func loadTodaysTasks() async {
        do {
            guard let userId = authService.currentUser?.uid else { return }

            let startOfDay = Calendar.current.startOfDay(for: selectedDate)
            let _ = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)! // endOfDay for future filtering

            let tasks = try await databaseService.getTasks(for: userId)
            let responses = try await databaseService.getSMSResponses(for: userId, date: selectedDate)

            let dashboardTasks = tasks.compactMap { task -> DashboardTask? in
                guard task.status == .active else {
                    return nil
                }

                guard let profile = profiles.first(where: { $0.id == task.profileId }) else {
                    return nil
                }

                guard profile.status == .confirmed else {
                    return nil
                }

                // Check if task is scheduled for selected date
                if task.isScheduledFor(date: selectedDate) {
                    let taskResponses = responses.filter { $0.taskId == task.id }
                    let latestResponse = taskResponses.max { $0.receivedAt < $1.receivedAt }

                    return DashboardTask(
                        task: task,
                        profile: profile,
                        scheduledTime: task.getScheduledTimeFor(date: selectedDate),
                        response: latestResponse,
                        isOverdue: isTaskOverdue(task: task, scheduledTime: task.getScheduledTimeFor(date: selectedDate))
                    )
                }

                return nil
            }

            await MainActor.run {
                self.todaysTasks = dashboardTasks.sorted { $0.scheduledTime < $1.scheduledTime }

                // Invalidate cache when new data is loaded
                self.cachedCompletedTasks = nil
                self.cacheTimestamp = nil
            }

        } catch {
            await MainActor.run {
                logger.error("Loading today's tasks failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadRecentResponses() async {
        do {
            guard let userId = authService.currentUser?.uid else { return }
            
            let responses = try await databaseService.getRecentSMSResponses(for: userId, limit: 10)
            
            await MainActor.run {
                self.recentResponses = responses
            }
            
        } catch {
            await MainActor.run {
                logger.error("Loading recent responses failed: \(error.localizedDescription)")
            }
        }
    }
    
    
    // MARK: - Data Refresh
    func refreshData() {
        guard !refreshing else { return }
        
        _Concurrency.Task {
            await refreshDataAsync()
        }
    }
    
    private func refreshDataAsync() async {
        await MainActor.run {
            self.refreshing = true
        }
        
        await loadDashboardDataAsync()
        
        await MainActor.run {
            self.refreshing = false
        }
    }
    
    // REMOVED: refreshProfilesData() - profiles refreshed by ProfileViewModel
    // Dashboard will reactively update when ProfileViewModel.profiles changes
    func updatePendingConfirmations(profiles: [ElderlyProfile]) {
        _Concurrency.Task {
            await loadPendingConfirmations(profiles: profiles)
            await MainActor.run {
                self.updateDashboardSummary()
            }
        }
    }
    
    private func refreshTasksData() {
        _Concurrency.Task {
            await loadTodaysTasks()
            await MainActor.run {
                self.updateDashboardSummary()
                self.identifyOverdueTasks()

                // Invalidate cache on manual refresh
                self.invalidateCache()
            }
        }
    }

    /// Manually invalidate the completed tasks cache
    /// Call this when you know data has changed and need fresh computation
    func invalidateCache() {
        cachedCompletedTasks = nil
        cacheTimestamp = nil
    }
    
    // MARK: - Dashboard Updates
    private func updateDashboardSummary() {
        let completedTasks = todaysTasks.filter { $0.isCompleted }
        let totalTasks = todaysTasks.count
        let activeTasks = todaysTasks.filter { !$0.isCompleted && !$0.isOverdue }
        let overdue = overdueTasks.count
        
        todaysSummary = DashboardSummary(
            totalTasks: totalTasks,
            completedTasks: completedTasks.count,
            activeTasks: activeTasks.count,
            overdueTasks: overdue,
            completionRate: totalTasks > 0 ? Double(completedTasks.count) / Double(totalTasks) : 0,
            totalProfiles: profiles.count,
            activeProfiles: profiles.filter { $0.status == .confirmed }.count,
            pendingProfiles: pendingConfirmations.count
        )
    }
    
    private func identifyOverdueTasks() {
        let now = Date()
        
        overdueTasks = todaysTasks.filter { dashboardTask in
            guard !dashboardTask.isCompleted else { return false }
            
            let deadline = dashboardTask.scheduledTime.addingTimeInterval(TimeInterval(dashboardTask.task.deadlineMinutes * 60))
            return now > deadline
        }
    }
    
    private func isTaskOverdue(task: Task, scheduledTime: Date) -> Bool {
        let now = Date()
        let deadline = scheduledTime.addingTimeInterval(TimeInterval(task.deadlineMinutes * 60))
        return now > deadline
    }
    
    // MARK: - SMS Response Handling
    private func handleSMSResponse(_ response: SMSResponse) {
        // Add to recent responses
        if !recentResponses.contains(where: { $0.id == response.id }) {
            recentResponses.insert(response, at: 0)
            if recentResponses.count > 10 {
                recentResponses.removeLast()
            }
        }
        
        // Update corresponding task if it's in today's tasks
        if let taskIndex = todaysTasks.firstIndex(where: { $0.task.id == response.taskId }) {
            todaysTasks[taskIndex].response = response
            updateDashboardSummary()
            identifyOverdueTasks()

            // Invalidate cache when task completion status changes
            invalidateCache()
        }
        
        // Streak updates removed - no longer tracking streaks
        
        // Handle confirmation responses
        // NOTE: Profile confirmation updates now handled by ProfileViewModel
        // Dashboard should observe ProfileViewModel.profiles changes reactively
        if response.isConfirmationResponse,
           let profileId = response.profileId {

            if response.isPositiveConfirmation {
                // ProfileViewModel owns profile updates
                // Dashboard observes changes via computed property
                // Remove from pending confirmations after ProfileViewModel updates
                pendingConfirmations.removeAll { $0.id == profileId }

                updateDashboardSummary()
            }
        }
    }
    
    // MARK: - Family Task Coordination Actions
    
    /// Marks a care task as completed on behalf of elderly family member
    ///
    /// This method allows family members to complete tasks when elderly users
    /// have completed the care activity but haven't responded to SMS, or when
    /// family members directly observe task completion. Creates an SMS response
    /// record for consistency and analytics tracking.
    ///
    /// ## Use Cases:
    /// - Elderly person took medication but didn't respond to SMS reminder
    /// - Family member directly observed task completion during visit
    /// - Caregiver completed task and family member is confirming
    /// - Technical issues prevented elderly SMS response
    ///
    /// - Parameter dashboardTask: The care task to mark as completed
    /// - Important: Creates audit trail showing family member marked completion
    /// - Note: Updates completion statistics and removes from overdue list
    /// - Warning: Should only be used when family has confirmed actual task completion
    func markTaskCompleted(_ dashboardTask: DashboardTask) {
        _Concurrency.Task {
            await markTaskCompletedAsync(dashboardTask)
        }
    }
    
    /*
    BUSINESS LOGIC: Family-Initiated Task Completion for Care Coordination
    
    CONTEXT: Sometimes elderly users complete care tasks but don't respond to SMS
    (phone issues, confusion, forgetting). Families need the ability to mark tasks
    complete to maintain accurate care records and prevent false overdue alerts.
    
    DESIGN DECISION: Create synthetic SMS response with family attribution
    - Alternative 1: Separate completion pathway (rejected - complicates analytics)
    - Alternative 2: No family completion option (rejected - creates false alerts)  
    - Chosen Solution: Attributed SMS response maintains data consistency
    
    FAMILY COORDINATION: Family completion immediately updates dashboard across all
    devices, preventing multiple family members from attempting intervention for
    the same task. Maintains care completion statistics for trend analysis.
    
    AUDIT TRAIL: Clear attribution shows which tasks were family-completed vs
    elderly self-reported, enabling analysis of elderly independence patterns.
    */
    private func markTaskCompletedAsync(_ dashboardTask: DashboardTask) async {
        do {
            // Create synthetic SMS response with clear family attribution
            let response = SMSResponse(
                id: UUID().uuidString,
                taskId: dashboardTask.task.id,
                profileId: dashboardTask.task.profileId,
                userId: dashboardTask.task.userId,
                textResponse: "Marked complete by family member", // Clear audit trail
                photoData: nil,
                isCompleted: true,
                receivedAt: Date(),
                responseType: .text,
                isConfirmationResponse: false,
                isPositiveConfirmation: false,
                responseScore: nil,
                processingNotes: nil
            )
            
            // Persist completion with family synchronization
            try await databaseService.createSMSResponse(response)

            // Create gallery event for task completion
            let galleryEvent = GalleryHistoryEvent.fromSMSResponse(response)
            try await databaseService.createGalleryHistoryEvent(galleryEvent)

            // Update task completion statistics for analytics
            var updatedTask = dashboardTask.task
            updatedTask.completionCount += 1
            updatedTask.lastCompletedAt = Date()

            try await databaseService.updateTask(updatedTask)
            
            await MainActor.run {
                // Update local dashboard state for immediate family feedback
                if let index = self.todaysTasks.firstIndex(where: { $0.task.id == dashboardTask.task.id }) {
                    self.todaysTasks[index].response = response
                    self.todaysTasks[index].task = updatedTask
                }
                
                // Refresh dashboard metrics and remove from overdue list
                self.updateDashboardSummary()
                self.identifyOverdueTasks()
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                logger.error("Marking task completed by family failed: \(error.localizedDescription)")
            }
        }
    }
    
    func sendReminder(for dashboardTask: DashboardTask) {
        _Concurrency.Task {
            await sendReminderAsync(for: dashboardTask)
        }
    }
    
    private func sendReminderAsync(for dashboardTask: DashboardTask) async {
        // This would integrate with SMS service to send a reminder
        // Implementation would depend on SMS service design
    }
    
    // MARK: - Profile Selection
    
    /// Updates the selected profile for task filtering
    ///
    /// This method is called by DashboardView when user taps a profile.
    /// It updates the selectedProfileId and triggers UI refresh to show
    /// only tasks for the selected profile.
    ///
    /// - Parameter profileId: The ID of the selected elderly profile
    func selectProfile(profileId: String?) {
        selectedProfileId = profileId
        hasUserSelectedProfile = true  // Mark that user has made an explicit choice
        // Computed properties will automatically update UI
    }
    
    /// Filters tasks to show only those for the selected profile
    ///
    /// This implements the profile-specific task display requirement.
    /// If no profile is selected, returns empty array (safe default).
    ///
    /// - Parameter tasks: All dashboard tasks to filter
    /// - Returns: Tasks filtered by selected profile
    private func filterTasksBySelectedProfile(_ tasks: [DashboardTask]) -> [DashboardTask] {
        guard let selectedId = selectedProfileId else {
            return [] // No profile selected - show empty (safe default)
        }
        
        return tasks.filter { $0.profile.id == selectedId }
    }
    
    // MARK: - Navigation Actions
    func showProfileDetail(_ profile: ElderlyProfile) {
        // Navigation would be handled by the view
    }
    
    func showTaskDetail(_ task: Task) {
        // Navigation would be handled by the view
    }
    
    // Analytics removed - functionality no longer needed
    
    // MARK: - Date Navigation
    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
    
    func goToToday() {
        selectedDate = Date()
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    var canGoToNextDay: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return selectedDate < tomorrow
    }
    
    // MARK: - Streak Management
    
    // Streak functionality removed - no longer tracking streaks
    
    // Streak reset checking removed - no longer tracking streaks
    
    // MARK: - Quick Actions
    func quickAddMedicationReminder() {
        // This would trigger quick task creation with medication preset
        showingQuickAddTask = true
    }
    
    // Analytics removed - function no longer needed
    
    func quickViewProfiles() {
        showingProfilesList = true
    }
}

// MARK: - Dashboard Models
struct DashboardTask: Identifiable {
    var id: String { task.id }
    var task: Task
    let profile: ElderlyProfile
    let scheduledTime: Date
    var response: SMSResponse?
    let isOverdue: Bool
    
    var isCompleted: Bool {
        response?.isCompleted ?? false
    }
    
    var statusColor: Color {
        if isCompleted {
            return .green
        } else if isOverdue {
            return .red
        } else {
            return .orange
        }
    }
    
    var statusText: String {
        if isCompleted {
            return "Completed"
        } else if isOverdue {
            return "Overdue"
        } else {
            return "Pending"
        }
    }
}

struct DashboardSummary {
    let totalTasks: Int
    let completedTasks: Int
    let activeTasks: Int
    let overdueTasks: Int
    let completionRate: Double
    let totalProfiles: Int
    let activeProfiles: Int
    let pendingProfiles: Int
    
    init() {
        self.totalTasks = 0
        self.completedTasks = 0
        self.activeTasks = 0
        self.overdueTasks = 0
        self.completionRate = 0
        self.totalProfiles = 0
        self.activeProfiles = 0
        self.pendingProfiles = 0
    }
    
    init(totalTasks: Int, completedTasks: Int, activeTasks: Int, overdueTasks: Int, 
         completionRate: Double, totalProfiles: Int, activeProfiles: Int, pendingProfiles: Int) {
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.activeTasks = activeTasks
        self.overdueTasks = overdueTasks
        self.completionRate = completionRate
        self.totalProfiles = totalProfiles
        self.activeProfiles = activeProfiles
        self.pendingProfiles = pendingProfiles
    }
}

struct WeeklyProgress {
    let completionRate: Double
    let totalTasks: Int
    let completedTasks: Int
    let streak: Int
    let dailyCompletion: [Double]
    
    init() {
        self.completionRate = 0
        self.totalTasks = 0
        self.completedTasks = 0
        self.streak = 0
        self.dailyCompletion = Array(repeating: 0, count: 7)
    }
    
    init(completionRate: Double, totalTasks: Int, completedTasks: Int, 
         streak: Int, dailyCompletion: [Double]) {
        self.completionRate = completionRate
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.streak = streak
        self.dailyCompletion = dailyCompletion
    }
}

enum DashboardStatus {
    case loading
    case noProfiles
    case noTasksToday
    case active
    case allComplete
    case hasOverdue
}