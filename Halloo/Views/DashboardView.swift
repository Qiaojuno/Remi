import SwiftUI

/**
 * Gallery presentation data for fullScreenCover
 */
struct GalleryPresentationData: Identifiable {
    let id = UUID()
    let event: GalleryHistoryEvent
    let index: Int
    let total: Int
}

/**
 * DASHBOARD VIEW - Main Home Screen for Elderly Care Coordination
 *
 * PURPOSE: This is the primary interface families use to coordinate elderly care.
 * Shows today's tasks for selected elderly family member, allows creating new habits,
 *  * and provides quick access to profile management.
 *
 * KEY BUSINESS LOGIC:
 * - Families can manage up to 4 elderly profiles
 * - Tasks are filtered by selected profile (not "show all")
 * - Only today's tasks are displayed (upcoming vs completed)
 * - Profile-specific task creation with preselected family member
 *
 * NAVIGATION: Custom pill-shaped bottom nav (home active, gallery inactive)
 * SHEETS: ProfileCreationView and TaskCreationView with proper ViewModel injection
 */
struct DashboardView: View {

    // MARK: - Environment & Dependencies
    /// Dependency injection container providing access to all app services
    /// (DatabaseService, AuthenticationService, NotificationService, etc.)
    @Environment(\.container) private var container

    /// Scroll lock state from ContentView (disables vertical scroll during horizontal swipe)
    @Environment(\.isScrollDisabled) private var isScrollDisabled

    // PHASE 3: Single source of truth for all shared state
    /// Centralized app state containing profiles, tasks, and user data
    @EnvironmentObject private var appState: AppState

    /// Reactive data source for dashboard content (profiles, tasks, filtering logic)
    /// Uses @Published properties to automatically update UI when data changes
    @EnvironmentObject private var viewModel: DashboardViewModel

    /// Profile management for onboarding flow - shared across Dashboard and ProfileCreation
    /// Fixes ViewModel instance isolation by using same instance for profile creation
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    // MARK: - Navigation State
    /// Tab selection binding from parent ContentView for floating pill navigation
    @Binding var selectedTab: Int

    /// Controls whether to show header (false when rendered in ContentView's layered architecture)
    var showHeader: Bool = true

    /// Bindings for create actions (lifted to ContentView for proper presentation context)
    @Binding var showingCreateActionSheet: Bool
    @Binding var showingDirectOnboarding: Bool
    @Binding var showingTaskCreation: Bool

    // MARK: - UI State Management
    /// Tracks which elderly profile is currently selected (0-3 max)
    /// IMPORTANT: This drives task filtering - only selected profile's tasks show
    @State private var selectedProfileIndex: Int = 0

    /// Controls upcoming section expand/collapse state
    /// When collapsed: shows summary message, when expanded: shows task list or confirmation
    @State private var isUpcomingExpanded: Bool = false

    /// Controls GalleryDetailView presentation for completed task viewing
    @State private var selectedTaskForGalleryDetail: GalleryPresentationData?
    
    /// Tracks all gallery events for today's completed tasks for navigation
    @State private var todaysGalleryEvents: [GalleryHistoryEvent] = []
    
    /// Tracks the current top card in the card stack to show its task details
    @State private var currentTopCardEvent: GalleryHistoryEvent?
    
    /// Current index in the gallery events array
    @State private var currentGalleryIndex: Int = 0
    
    /// Current total events count for navigation
    @State private var currentTotalEvents: Int = 0

    var body: some View {
        // Show dashboard content directly - presentation handled by ContentView
        dashboardContent
    }
    
    private var dashboardContent: some View {
        /*
         * RESPONSIVE LAYOUT STRUCTURE:
         * GeometryReader provides actual screen dimensions for responsive design
         * Uses 5% screen padding and proportional sizing for different devices
         */
        GeometryReader { geometry in
            ZStack {
                /*
                 * MAIN SCROLLABLE CONTENT AREA:
                 * Contains all dashboard sections in vertical flow
                 * Background: Light gray (#f9f9f9) for card contrast
                 */
                VStack(spacing: 10) { // Reduced spacing between cards by half

                    // 🏠 HEADER: App branding + account access (conditionally rendered)
                    if showHeader {
                        headerSection
                            .padding(.bottom, 3.33) // Increase spacing by 1/3 (10 → 13.33)
                    }

                    // ✅ COMPLETED: Interactive card stack showing task evidence
                    // Replaces detailed view system with swipeable playing card stack
                    cardStackSection
                        .padding(.top, showHeader ? 0 : 100) // Add top padding when header is hidden (static header height)
                        .padding(.bottom, 24) // Clean spacing to upcoming section

                    Spacer()
                }
                .padding(.horizontal, geometry.size.width * 0.04) // Match GalleryView (96% width)
                .background(Color(hex: "f9f9f9")) // Light gray app background

                // Upcoming tasks card - fixed at bottom above StandardTabBar
                VStack {
                    Spacer()
                    upcomingSection
                        .padding(.horizontal, geometry.size.width * 0.04)
                        .padding(.bottom, 60) // Position above StandardTabBar
                }
                .allowsHitTesting(true)
            }
        }
        .onAppear {
            /*
             * DATA LOADING & PROFILE SELECTION:
             * 1. Connect DashboardViewModel to ProfileViewModel (single source of truth)
             * 2. Load dashboard data and auto-select first profile for task filtering
             * 3. Sync UI selection state with ViewModel selection state
             */
            viewModel.setProfileViewModel(profileViewModel)

            // PHASE 3: Sync selectedProfileIndex with ViewModel's selectedProfileId
            // Read from appState (single source of truth)
            if let selectedId = viewModel.selectedProfileId,
               let index = appState.profiles.firstIndex(where: { $0.id == selectedId }) {
                selectedProfileIndex = index
            } else {
                print("⚠️ [DashboardView] Could not sync profile selection - profiles may not be loaded yet")
            }

            loadData()
        }
        .onChange(of: viewModel.selectedProfileId) { oldProfileId, newProfileId in
            // PHASE 3: Sync selectedProfileIndex when ViewModel auto-selects a profile
            // Read from appState (single source of truth)
            if let newId = newProfileId,
               let index = appState.profiles.firstIndex(where: { $0.id == newId }) {
                selectedProfileIndex = index
            }
        }
        /*
         * 📱 GALLERY DETAIL VIEW:
         * Full-screen detailed view of completed task gallery events
         * Presents GalleryDetailView when "view" button tapped on completed task
         */
        .fullScreenCover(item: $selectedTaskForGalleryDetail, onDismiss: {
            // Reset when dismissed
            todaysGalleryEvents = []
            currentGalleryIndex = 0
            currentTotalEvents = 0
        }) { galleryData in
            GalleryDetailView(
                event: galleryData.event,
                selectedTab: $selectedTab,
                currentIndex: galleryData.index,
                totalEvents: galleryData.total,
                onPrevious: { navigateToPreviousTask() },
                onNext: { navigateToNextTask() }
            )
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        }
    }
    
    // MARK: - Helper Methods
    private func navigateToPreviousTask() {
        guard currentGalleryIndex > 0 else {
            return
        }

        let newIndex = currentGalleryIndex - 1
        let newEvent = todaysGalleryEvents[newIndex]

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentGalleryIndex = newIndex
            selectedTaskForGalleryDetail = GalleryPresentationData(event: newEvent, index: newIndex, total: todaysGalleryEvents.count)
        }
    }

    private func navigateToNextTask() {
        guard currentGalleryIndex < todaysGalleryEvents.count - 1 else {
            return
        }

        let newIndex = currentGalleryIndex + 1
        let newEvent = todaysGalleryEvents[newIndex]

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentGalleryIndex = newIndex
            selectedTaskForGalleryDetail = GalleryPresentationData(event: newEvent, index: newIndex, total: todaysGalleryEvents.count)
        }
    }
    
    private func loadTodaysGalleryEvents() async {
        do {
            let authService = container.resolve(AuthenticationServiceProtocol.self)
            guard let userId = authService.currentUser?.uid else { return }
            
            let databaseService = container.resolve(DatabaseServiceProtocol.self)
            let allEvents = try await databaseService.getGalleryHistoryEvents(for: userId)
            
            // Get task IDs from today's completed tasks IN ORDER
            let todaysTasks = viewModel.todaysCompletedTasks
            let todaysTaskIds = todaysTasks.map { $0.task.id }

            // Create a map of task ID to gallery event
            var taskEventMap: [String: GalleryHistoryEvent] = [:]
            for event in allEvents {
                switch event.eventData {
                case .taskResponse(let data):
                    if let taskId = data.taskId {
                        if todaysTaskIds.contains(taskId) {
                            // Only keep the first event for each task (avoid duplicates)
                            if taskEventMap[taskId] == nil {
                                taskEventMap[taskId] = event
                            }
                        }
                    }
                case .profileCreated(_):
                    break // Skip profile events
                }
            }

            // Build the gallery events array in the same order as completed tasks
            var orderedEvents: [GalleryHistoryEvent] = []
            for task in todaysTasks {
                if let event = taskEventMap[task.task.id] {
                    orderedEvents.append(event)
                }
            }

            await MainActor.run {
                todaysGalleryEvents = orderedEvents
            }
        } catch {
            print("Error loading today's gallery events: \(error)")
        }
    }
    
    private func findGalleryEventForTask(_ task: Task) async -> GalleryHistoryEvent? {
        do {
            let authService = container.resolve(AuthenticationServiceProtocol.self)
            guard let userId = authService.currentUser?.uid else {
                return nil
            }
            
            // Get gallery events from database
            let databaseService = container.resolve(DatabaseServiceProtocol.self)
            let galleryEvents = try await databaseService.getGalleryHistoryEvents(for: userId)
            
            // Find the gallery event that corresponds to this task
            return galleryEvents.first { event in
                switch event.eventData {
                case .taskResponse(let data):
                    return data.taskId == task.id
                case .profileCreated(_):
                    return false
                }
            }
        } catch {
            print("Error finding gallery event for task: \(error)")
            return nil
        }
    }
    
    // MARK: - 🏠 Header Section
    /**
     * APP HEADER: Brand identity and account access
     * 
     * LAYOUT: Left-aligned logo, right-aligned profile button
     * TYPOGRAPHY: Custom Inter font with exact Figma specifications
     * PURPOSE: Establishes app identity and provides settings access
     */
    private var headerSection: some View {
        SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
    }
    
    
    
    // MARK: - ⏰ Upcoming Section

    /**
     * TODAY'S PENDING TASKS: What needs to be done today
     * 
     * CRITICAL FILTERING LOGIC:
     * - Only shows tasks for currently selected elderly profile
     * - Only shows today's tasks (not future days)
     * - Only shows pending tasks (not completed ones)
     * 
     * PURPOSE: Gives families clear visibility into what care tasks
     * are scheduled for today and still need completion
     * 
     * UI BEHAVIOR:
     * - No "view" buttons (tasks aren't completed yet)
     * - Each row shows profile photo, name, task title, and time
     * - Time format: 12-hour ("9AM", "2PM") for easy reading
     */
    // MARK: - 👥 Profiles Section
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Title
            Text("PROFILES")
                .font(.system(size: 15, weight: .bold))
                .tracking(-1)
                .foregroundColor(Color(hex: "9f9f9f"))
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)

            // PHASE 3: Profile circles - Reading from AppState (single source of truth)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(appState.profiles.enumerated()), id: \.element.id) { index, profile in
                        Button(action: {
                            selectedProfileIndex = index
                            // Update DashboardViewModel's selected profile to trigger task filtering
                            viewModel.selectProfile(profileId: profile.id)
                        }) {
                            ProfileImageView.custom(
                                profile: profile,
                                profileSlot: index,
                                isSelected: selectedProfile?.id == profile.id,
                                size: 44
                            )
                        }
                    }

                    // Add Profile Button
                    Button(action: {
                        showingDirectOnboarding = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "5f5f5f"))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }

    private var upcomingSection: some View {
        /*
         * TASK LIST: Profile-filtered, today-only pending tasks
         * Data source: viewModel.todaysUpcomingTasks (automatically filtered)
         * White card background for clarity and grouping
         * FIXED AT BOTTOM: Expands downward with internal scrolling
         */
        let maxExpandedHeight = UIScreen.main.bounds.height * 0.20 // 20% of screen height

        return VStack(spacing: 0) {
            // Collapsible header with dynamic message and chevron (at top)
            HStack(alignment: .center, spacing: 12) {
                // Party popper emoji - always visible
                Text("🎉")
                    .font(.system(size: 28))

                // Dynamic header text
                if viewModel.todaysUpcomingTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All messages received!")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)

                        if !isUpcomingExpanded {
                            Text("0 tasks left")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.black)
                        }
                    }
                } else {
                    Text("\(viewModel.todaysUpcomingTasks.count) upcoming")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "9f9f9f"))
                    .rotationEffect(.degrees(isUpcomingExpanded ? 90 : -90))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white) // Header background
            .contentShape(Rectangle()) // Make entire header tappable
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                    isUpcomingExpanded.toggle()
                }
            }

            // Expandable content with animation (rendered after header so it expands DOWNWARD)
            if isUpcomingExpanded {
                VStack(spacing: 0) {
                    if viewModel.todaysUpcomingTasks.isEmpty {
                        // Show confirmation message when no tasks and expanded
                        HStack {
                            Spacer()
                            Text("All tasks completed today!")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(hex: "9f9f9f"))
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else {
                        // Internal ScrollView for task list with max height
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.todaysUpcomingTasks.enumerated()), id: \.offset) { index, task in
                                    TaskRowView(
                                        task: task.task,
                                        profile: task.profile,
                                        showViewButton: false, // No view button for pending tasks
                                        onViewButtonTapped: nil
                                    )
                                    .padding(.horizontal, 12)  // Match card title alignment
                                    .padding(.vertical, 12)
                                    .background(Color.white) // Each task has white background

                                    if index < viewModel.todaysUpcomingTasks.count - 1 {
                                        Divider()
                                            .overlay(Color(hex: "f8f3f3"))
                                            .padding(.horizontal, 24)  // Shorter lines aligned with tasks
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: maxExpandedHeight - 60) // Reserve space for header
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            Color.white // Solid white background to block gradient
                .cornerRadius(12)
        )
        .cornerRadius(12) // Consistent rounded corners
        .shadow(color: Color(hex: "6f6f6f").opacity(0.125), radius: 6, x: 0, y: -2) // Subtle shadow pointing upward
        .fixedSize(horizontal: false, vertical: true) // Size to content, don't expand unnecessarily
    }
    
    // MARK: - ✅ Card Stack Section
    /**
     * INTERACTIVE CARD STACK: Playing card style display of completed tasks
     * 
     * REPLACES: Old completedTasksSection with detailed view system
     * 
     * FEATURES:
     * - Shows max 3 cards in random fan arrangement
     * - Each card displays either photo or SMS evidence (never both)
     * - Swipe left/right to cycle through completed tasks
     * - Task title displays under stack and changes with current card
     * - Placeholder card when no completed tasks exist
     * 
     * DATA TRANSFORMATION:
     * - Converts DashboardTask with SMSResponse into separate CardData
     * - Splits ResponseType.both into individual photo and SMS cards
     * - Maintains chronological order (most recent first)
     */
    private var cardStackSection: some View {
        // CARD STACK - Full width for proper centering
        CardStackView(
            events: completedTaskEvents,
            currentTopEvent: $currentTopCardEvent,
            imageCache: appState.imageCache
        )
        .padding(.top, 20)  // Only top padding to avoid double padding with task details
        .offset(y: 8)  // Move down slightly
        .frame(maxWidth: .infinity) // Allow full width for internal centering
    }
    
    // MARK: - Card Stack Data Conversion
    /// Today's completed task gallery events from AppState (single source of truth)
    /// Filters appState.galleryEvents to show only task responses from today
    private var completedTaskEvents: [GalleryHistoryEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return appState.galleryEvents.filter { event in
            // Only show task response events (not profile creation)
            guard event.eventType == .taskResponse else { return false }

            // Only show events from today
            let eventDate = calendar.startOfDay(for: event.createdAt)
            guard eventDate == today else { return false }

            // Filter by selected profile if one is selected
            if let selectedProfile = selectedProfile {
                return event.profileId == selectedProfile.id
            }

            return true
        }
        .sorted { $0.createdAt > $1.createdAt } // Most recent first
    }
    
    // MARK: - ✅ OLD Completed Tasks Section (REPLACED BY CARD STACK)
    /**
     * TODAY'S FINISHED TASKS: What has been accomplished today
     * 
     * CRITICAL FILTERING LOGIC:
     * - Only shows tasks for currently selected elderly profile447
     * - Only shows today's tasks (not previous days)
     * - Only shows completed tasks (with completion evidence)
     * 
     * PURPOSE: Provides families with reassurance that care tasks
     * have been completed and allows reviewing completion evidence
     * 
     * UI BEHAVIOR:
     * - Shows "view" buttons for reviewing completion details
     * - Buttons lead to photos/SMS responses from elderly person
     * - Same TaskRowView component as upcoming but with viewing enabled
     * 
     * COMPLETION EVIDENCE:
     * - Photos taken by elderly person showing task completion
     * - SMS responses confirming task completion
     * - Timestamp and location data (if available)
     */
    private var completedTasksSection: some View {
        /*
         * COMPLETED TASK LIST: Profile-filtered, today-only completed tasks
         * Data source: viewModel.todaysCompletedTasks (automatically filtered)
         * 
         * KEY DIFFERENCE FROM UPCOMING:
         * - showViewButton: true enables reviewing completion evidence
         * - Families can see photos, SMS responses, timestamps
         * - Provides peace of mind that care tasks were actually completed
         */
        VStack(spacing: 0) {
                // Section title inside card
                HStack {
                    Text("COMPLETED TASKS")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(Color(hex: "9f9f9f"))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Spacer()
                }
                
                // Task rows or Complete message
                if viewModel.todaysCompletedTasks.isEmpty {
                    // Show Complete message when no completed tasks
                    HStack {
                        Spacer()
                        Text("Empty!")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(Array(viewModel.todaysCompletedTasks.enumerated()), id: \.element.task.id) { rowIndex, task in
                        TaskRowView(
                            task: task.task,
                            profile: task.profile,
                            showViewButton: true, // IMPORTANT: Enables viewing completion evidence
                            onViewButtonTapped: {
                                guard selectedTaskForGalleryDetail == nil else { return }

                                let taskIndex = rowIndex

                                _Concurrency.Task {
                                    // Always reload today's gallery events to ensure we have all of them
                                    await loadTodaysGalleryEvents()

                                    // The gallery events are now guaranteed to be in the same order as completed tasks
                                    if taskIndex < todaysGalleryEvents.count {
                                        await MainActor.run {
                                            let galleryEvent = todaysGalleryEvents[taskIndex]
                                            let totalEventsCount = todaysGalleryEvents.count

                                            // Set both values BEFORE presenting to ensure proper navigation state
                                            currentGalleryIndex = taskIndex
                                            currentTotalEvents = totalEventsCount

                                            // Disable animation when presenting
                                            var transaction = Transaction()
                                            transaction.disablesAnimations = true
                                            withTransaction(transaction) {
                                                selectedTaskForGalleryDetail = GalleryPresentationData(event: galleryEvent, index: taskIndex, total: totalEventsCount)
                                            }
                                        }
                                    } else {
                                        print("❌ [DashboardView] Gallery event index out of bounds")
                                    }
                                }
                            }
                        )
                        .id(task.task.id) // Force unique identity for each row
                        .padding(.horizontal, 12)  // Match card title alignment
                        .padding(.vertical, 12)
                        .background(Color.white) // Each task has white background
                        
                        if rowIndex < viewModel.todaysCompletedTasks.count - 1 {
                            Divider()
                                .overlay(Color(hex: "f8f3f3"))
                                .padding(.horizontal, 24)  // Shorter lines aligned with tasks
                        }
                    }
                }
        }
        .background(Color.white) // Card background for grouping
        .cornerRadius(12) // Consistent rounded appearance
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        // No bottom padding - this is the last content section
    }
    
    
    // MARK: - 🔧 Helper Properties & Methods
    
    /**
     * SELECTED PROFILE ACCESSOR: Safe access to currently selected elderly profile
     * 
     * PURPOSE: Provides the ElderlyProfile object for the currently selected index
     * Used for preselecting profile in TaskCreationView and safety checks
     *
     * PHASE 3: Reads from AppState (single source of truth)
     * SAFETY: Returns nil if selectedProfileIndex is out of bounds
     * This prevents crashes when profiles are loading or being modified
     */
    private var selectedProfile: ElderlyProfile? {
        // PHASE 3: Use AppState as single source of truth
        guard selectedProfileIndex < appState.profiles.count else { return nil }
        return appState.profiles[selectedProfileIndex]
    }
    
    /**
     * DATA LOADING: Initialize dashboard data and set default profile selection
     * 
     * BUSINESS LOGIC:
     * 1. Load all dashboard data (profiles, tasks, etc.) from ViewModel
     * 2. Auto-select first profile (index 0) for immediate task filtering
     * 3. This ensures families see relevant tasks immediately upon app launch
     * 
     * CALLED: On view appearance (.onAppear)
     * TIMING: Critical to call selectProfile after profiles are loaded
     */
    private func loadData() {
        /*
         * Load dashboard data from ViewModel
         * This triggers network calls to fetch profiles, tasks, etc.
         * Auto-selection now happens in DashboardViewModel after profiles are loaded
         */
        viewModel.loadDashboardData()
    }
    
    /**
     * DEPRECATED: Task loading method no longer needed
     * 
     * LEGACY NOTE: This method previously handled manual task loading
     * Now handled automatically by profile tap gesture and ViewModel filtering
     * 
     * CURRENT APPROACH:
     * - Profile tap updates selectedProfileIndex
     * - Profile tap calls viewModel.selectProfile()
     * - ViewModel automatically filters @Published task properties
     * - UI updates reactively via @Published property changes
     */
    private func loadTasksForSelectedProfile() {
        // This method is now handled by profile tap gesture
        // ViewModel automatically filters tasks based on selectedProfileId
    }
}

// MARK: - ProfileImageView Components Moved to /Views/Components/ProfileImageView.swift
// This eliminates duplicate code and provides unified ProfileImageView component

// MARK: - Task Row View Component
struct TaskRowView: View {
    let task: Task
    let profile: ElderlyProfile?
    let showViewButton: Bool
    let onViewButtonTapped: (() -> Void)?

    // PHASE 3: Need appState for profile slot calculation
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    init(
        task: Task,
        profile: ElderlyProfile?,
        showViewButton: Bool,
        onViewButtonTapped: (() -> Void)? = nil
    ) {
        self.task = task
        self.profile = profile
        self.showViewButton = showViewButton
        self.onViewButtonTapped = onViewButtonTapped
    }

    // PHASE 3: Calculate profile slot index based on position in AppState
    private var profileSlot: Int {
        guard let profile = profile else { return 0 }
        return appState.profiles.firstIndex(where: { $0.id == profile.id }) ?? 0
    }

    var body: some View {
        HStack(spacing: 16) {
            // Profile Image - Use unified ProfileImageView component
            if let profile = profile {
                ProfileImageView.custom(
                    profile: profile,
                    profileSlot: profileSlot,
                    isSelected: false, // Tasks don't have selection state
                    size: 32
                )
            }
            
            // Task Details
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.name ?? "")
                    .font(.system(size: 16, weight: .heavy))  // System font with heavy weight
                    .tracking(-0.25)  // Half of original -0.5 offset
                    .foregroundColor(.black)

                HStack(spacing: 4) {
                    Text(task.title)
                        .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                        .fontWeight(.regular)
                        .tracking(-0.5)  // Less tight tracking
                        .foregroundColor(.black)

                    Text("•")
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))

                    Text(DateFormatters.formatTime(task.scheduledTime))
                        .font(.custom("Inter", size: 13))  // Smaller for hierarchy
                        .fontWeight(.regular)
                        .tracking(-0.5)  // Less tight tracking
                        .foregroundColor(.black)
                }
            }
            
            Spacer()
            
            // View Button (only for completed tasks)
            if showViewButton {
                Button(action: {
                    onViewButtonTapped?()
                }) {
                    Text("view")
                        .font(.custom("Inter", size: 13))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "28ADFF"))  // Rich blue like continue buttons
                        .cornerRadius(8)
                }
                .frame(height: 28)
            }
        }
    }
}

// MARK: - Views now in dedicated files
// ProfileCreationView -> ProfileViews.swift
// TaskCreationView -> TaskViews.swift

// MARK: - Preview Support
#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // SIMPLE FALLBACK PREVIEW (if comprehensive fails)
            VStack {
                Text("DashboardView Canvas Preview")
                    .font(.headline)
                Text("Canvas loading...")
                    .foregroundColor(.gray)
            }
            .previewDisplayName("📱 Simple Fallback")
            
            // COMPREHENSIVE DASHBOARD LAYOUT PREVIEW
            PreviewDashboardWrapper()
                .previewDisplayName("📱 Complete Dashboard Layout")
            
            // INDIVIDUAL SECTION PREVIEWS FOR EASY EDITING
            // Updated Header Section Preview - Uses shared component
            PreviewHeaderWrapper()
                .previewDisplayName("🏠 Header Section - UPDATED")
            
            PreviewProfilesSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("👥 Profiles Section")
            
            
            PreviewUpcomingSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("⏰ Upcoming Section")
            
            PreviewCompletedTasksSection()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("✅ Completed Tasks Section")
            
            PreviewBottomNavigation()
                .padding()
                .background(Color(hex: "f9f9f9"))
                .previewDisplayName("🧭 Bottom Navigation")
        }
    }
}

// MARK: - Organized Preview Components

// SharedHeaderSection moved to /Views/Components/SharedHeaderSection.swift

struct PreviewProfilesSection: View {
    // Move static data outside body to avoid Canvas issues
    private let mockProfiles = [
        ("👴🏻", "Grandpa Joe", Color(hex: "B9E3FF"), true),   // Show all outlines
        ("👵🏽", "Grandma Maria", Color.red.opacity(0.6), true),  // Show all outlines
        ("👴🏿", "Uncle Robert", Color.green.opacity(0.6), true)   // Show all outlines
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // White Card with Profiles - title inside card
            VStack(alignment: .leading, spacing: 12) {
                // Section Title inside the card
                Text("PROFILES:")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(Color(hex: "9f9f9f"))
                
                // Profile circles
                HStack(spacing: 12) {
                    ForEach(Array(mockProfiles.enumerated()), id: \.offset) { index, profile in
                        ZStack {
                            profile.2.opacity(0.2)  // Use profile's color as background
                            Text(profile.0)
                                .font(.system(size: 20))
                        }
                        .frame(width: 44, height: 44) // ~44pt diameter
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(profile.2, lineWidth: profile.3 ? 2 : 2)  // All have 2px for preview
                        )
                    }
                    
                    // Add Profile Button - Figma specs
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "5f5f5f"))
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Dark gray shadow
        }
    }
}


struct PreviewUpcomingSection: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel

    var upcomingTasks: [DashboardTask] {
        dashboardViewModel.todaysTasks.filter { !$0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent
        }
        .padding(.horizontal, 23)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tasksList
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }

    private var header: some View {
        HStack {
            Text("UPCOMING")
                .font(.system(size: 15, weight: .bold))
                .tracking(-1)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Spacer()
        }
    }

    @ViewBuilder
    private var tasksList: some View {
        if upcomingTasks.isEmpty {
            VStack(spacing: 8) {
                Text("No upcoming tasks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Text("Create a habit to get started")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ForEach(Array(upcomingTasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 16) {
                            // Profile Image - 32pt diameter
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                )

                            // Task Details
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.profile.name)
                                    .font(.system(size: 16, weight: .heavy))
                                    .tracking(-0.25)
                                    .foregroundColor(.black)

                                HStack(spacing: 4) {
                                    Text(task.task.title)
                                        .font(.custom("Inter", size: 13))
                                        .fontWeight(.regular)
                                        .foregroundColor(.black)

                                    Text("•")
                                        .font(.custom("Inter", size: 14))
                                        .foregroundColor(.secondary)

                                    Text(DateFormatters.formatTime(task.scheduledTime))
                                        .font(.custom("Inter", size: 13))
                                        .fontWeight(.regular)
                                        .foregroundColor(.black)
                                }
                            }

                            Spacer()

                            // Checkmark Button
                            Button(action: {
                                // Mark task as complete
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.black)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)

                        if index < upcomingTasks.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.2))
                                .padding(.horizontal, 32)
                        }
                    }
        }
    }
}

struct PreviewCompletedTasksSection: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel

    var completedTasks: [DashboardTask] {
        dashboardViewModel.todaysTasks.filter { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            cardContent
        }
        .padding(.horizontal, 23)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            header
            tasksList
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }

    private var header: some View {
        HStack {
            Text("COMPLETED TASKS")
                .font(.system(size: 15, weight: .bold))
                .tracking(-1)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Spacer()
        }
    }

    @ViewBuilder
    private var tasksList: some View {
        if completedTasks.isEmpty {
            // Empty state
            VStack(spacing: 8) {
                Text("No completed tasks yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Text("Complete a task to see it here")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ForEach(Array(completedTasks.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: 16) {
                    // Profile Image - 32pt diameter
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        )

                    // Task Details
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.profile.name)
                            .font(.system(size: 16, weight: .heavy))
                            .tracking(-0.25)
                            .foregroundColor(.black)

                        HStack(spacing: 4) {
                            Text(task.task.title)
                                .font(.custom("Inter", size: 13))
                                .fontWeight(.regular)
                                .foregroundColor(.black)

                            Text("•")
                                .font(.custom("Inter", size: 14))
                                .foregroundColor(.secondary)

                            Text(DateFormatters.formatTime(task.scheduledTime))
                                .font(.custom("Inter", size: 13))
                                .fontWeight(.regular)
                                .foregroundColor(.black)
                        }
                    }

                    Spacer()

                    // View Button
                    Button(action: {}) {
                        Text("view")
                            .font(.custom("Inter", size: 13))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "B9E3FF"))
                            .cornerRadius(8)
                    }
                    .frame(height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if index < completedTasks.count - 1 {
                    Divider()
                        .padding(.horizontal, 32)
                        .background(Color.gray.opacity(0.2))
                }
            }
        }
    }
}

struct PreviewBottomNavigation: View {
    var body: some View {
        // Pill-shaped navigation - exact specs
        HStack(spacing: 20) {
            // Home Tab (Active)
            VStack(spacing: 4) {
                Image(systemName: "house.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                
                Text("home")
                    .font(.custom("Inter", size: 10))
                    .foregroundColor(.black)
            }
            
            // Gallery Tab (Inactive)
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                
                Text("gallery")
                    .font(.custom("Inter", size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 94, height: 43.19)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 21.595)
                .stroke(Color(hex: "e0e0e0"), lineWidth: 1)
        )
        .padding(.trailing, 10)
        .padding(.bottom, 20)
    }
}

// MARK: - Preview Wrapper Structs
private struct PreviewDashboardWrapper: View {
    @State private var selectedProfileIndex: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section - Use shared header component
                    SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
                    
                    // Profiles Section  
                    PreviewProfilesSection()
                        .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                        .padding(.top, 8)
                    
                    
                    // Upcoming Section
                    PreviewUpcomingSection()
                        .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                        .padding(.top, 20)
                    
                    // Completed Tasks Section
                    PreviewCompletedTasksSection()
                        .padding(.horizontal, geometry.size.width * 0.04) // Add horizontal padding
                        .padding(.top, 20)
                    
                    // Bottom spacing for navigation
                    Spacer(minLength: 100)
                }
            }
            .background(Color(hex: "f9f9f9"))
            .overlay(
                // Bottom Navigation Overlay
                PreviewBottomNavigation()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            )
        }
        .inject(container: Container.shared)
    }
}

private struct PreviewHeaderWrapper: View {
    @State private var selectedProfileIndex: Int = 0

    var body: some View {
        SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
            .background(Color(hex: "f9f9f9"))
            .inject(container: Container.shared)
    }
}

#endif
