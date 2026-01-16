import SwiftUI
import UIKit

/**
 * HABITS VIEW - Habit Management Screen
 *
 * PURPOSE: Allows users to view and manage all scheduled habits across all profiles.
 * Provides filtering by days of the week and swipe-to-delete functionality.
 *
 * KEY FEATURES:
 * - Reuses profile selection from Dashboard for consistency
 * - Week selector for filtering habits by scheduled days
 * - Swipe-to-delete with day-specific deletion capability
 * - Maintains same design language as rest of app
 *
 * NAVIGATION: Accessed via middle tab (bookmark icon) in floating pill navigation
 */
struct HabitsView: View {

    // MARK: - Environment & Dependencies
    @Environment(\.container) private var container
    @Environment(\.isScrollDisabled) private var isScrollDisabled
    @Environment(\.isDragging) private var isDragging

    // PHASE 3: Single source of truth for all shared state
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: DashboardViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    // MARK: - Navigation State
    @Binding var selectedTab: Int

    /// Binding to ContentView's create action sheet state
    @Binding var showingCreateActionSheet: Bool

    /// Controls whether to show header (false when rendered in ContentView's layered architecture)
    var showHeader: Bool = true

    // MARK: - UI State Management
    @State private var selectedProfileIndex: Int = 0

    /// Controls TaskCreationView conditional presentation with profile preselection
    @State private var showingTaskCreation = false

    /// Controls direct ProfileOnboardingFlow presentation
    @State private var showingDirectOnboarding = false

    /// Controls delete confirmation alert for habits
    @State private var showingDeleteConfirmation = false
    @State private var habitToDelete: Task?

    /// Controls delete confirmation alert for profiles
    @State private var showingProfileDeleteConfirmation = false

    /// Track habits pending deletion (waiting for user confirmation)
    @State private var habitsPendingDeletion: Set<String> = []

    /// Track locally deleted habit IDs for optimistic UI updates
    @State private var locallyDeletedHabitIds: Set<String> = []

    /// Delete button cooldown to prevent accidental taps
    @State private var isDeleteButtonCoolingDown = false

    /// Persistent TaskViewModel instance (prevents recreation on re-render)
    @State private var taskViewModel: TaskViewModel?

    /// Force view refresh when tasks change
    @State private var refreshID = UUID()

    /// Controls image picker for profile photo update
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?

    // MARK: - Initialization
    init(selectedTab: Binding<Int>, showingCreateActionSheet: Binding<Bool>, showHeader: Bool = true) {
        self._selectedTab = selectedTab
        self._showingCreateActionSheet = showingCreateActionSheet
        self.showHeader = showHeader
    }

    var body: some View {
        // Show habits view as main content
        habitsContent
            .onAppear {
                // Initialize TaskViewModel once
                if taskViewModel == nil {
                    taskViewModel = container.makeTaskViewModel()
                    // Load all tasks for the authenticated user
                    taskViewModel?.loadTasks()
                }
            }
            .onChange(of: taskViewModel?.tasks.count) { oldCount, newCount in
                // Force view refresh by updating a local state
                refreshID = UUID()
            }
            .id(refreshID) // Force refresh when refreshID changes
            .overlay(
                // NEW: Habit Creation Card (replaces full-screen TaskCreationView)
                Group {
                    if let taskVM = taskViewModel {
                        HabitCreationCard(
                            isPresented: $showingTaskCreation,
                            preselectedProfileId: selectedProfile?.id,
                            onDismiss: {
                                showingTaskCreation = false
                            }
                        )
                        .environmentObject(appState)
                        .environmentObject(profileViewModel)
                        .environmentObject(taskVM)
                    }
                }
            )
            .overlay(
                // Profile Creation Card (replaces full-screen SimplifiedProfileCreationView)
                ProfileCreationCard(
                    isPresented: $showingDirectOnboarding,
                    onDismiss: {
                        showingDirectOnboarding = false
                    }
                )
                .environmentObject(appState)
                .environmentObject(profileViewModel)
            )
    }
    
    private var habitsContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: 0) { // Use explicit Spacers for precise control

                        // 🏠 HEADER: App branding + account access (conditionally rendered)
                        if showHeader {
                            headerSection
                                .padding(.horizontal, geometry.size.width * 0.04)

                            Spacer()
                                .frame(height: 10)
                        }

                        // Empty state when no profiles exist
                        if appState.profiles.isEmpty {
                            emptyStateNoProfiles
                                .padding(.top, showHeader ? 20 : 120)
                        } else {
                            // 👤 PROFILE CARD: Selected profile info with edit capability
                            if let profile = selectedProfile {
                                profileCardSection(profile: profile)
                                    .padding(.horizontal, geometry.size.width * 0.04)
                                    .padding(.top, showHeader ? 0 : 100) // Add top padding when header is hidden (static header height)
                            }

                            // 📅 WEEK OVERVIEW: Visual day-by-day habit slots
                            Spacer()
                                .frame(height: 16)

                            weekOverviewSection
                                .padding(.horizontal, geometry.size.width * 0.04)

                            // 📋 HABITS LIST
                            Spacer()
                                .frame(height: 24)

                            // Individual habit cards
                            if profileHabits.isEmpty {
                                // Empty state
                                emptyStateNoHabits
                                    .padding(.horizontal, geometry.size.width * 0.04)
                            } else {
                                ForEach(profileHabits, id: \.id) { habit in
                                    HabitCardView(
                                        habit: habit,
                                        profile: getProfileForHabit(habit),
                                        onTap: {
                                            HapticFeedback.light()
                                            deleteHabit(habit: habit)
                                        }
                                    )
                                    .padding(.horizontal, geometry.size.width * 0.04)

                                    // Spacing between habit cards
                                    Spacer()
                                        .frame(height: 3)
                                }
                            }

                            // Spacing before delete button
                            Spacer()
                                .frame(height: 16)

                            // Delete profile button as its own card
                            deleteProfileButtonCard
                                .padding(.horizontal, geometry.size.width * 0.04)
                        }

                        // Bottom padding to prevent content from hiding behind navigation
                        Spacer(minLength: 100)
                    }
                }
                .scrollDisabled(isScrollDisabled)
                .background(Color(hex: "f9f9f9")) // Light gray app background
            }
        }
        .onAppear {
            // PHASE 3: Sync selectedProfileIndex with ViewModel's selectedProfileId when view appears
            if let selectedId = viewModel.selectedProfileId,
               let index = appState.profiles.firstIndex(where: { $0.id == selectedId }) {
                selectedProfileIndex = index
            }

            // Trigger initial cooldown if user is already on Habits tab
            if selectedTab == 2 {
                withAnimation {
                    isDeleteButtonCoolingDown = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isDeleteButtonCoolingDown = false
                    }
                }
            }

            loadData()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Start delete button cooldown when switching TO Habits tab (index 2)
            if newValue == 2 {
                withAnimation {
                    isDeleteButtonCoolingDown = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isDeleteButtonCoolingDown = false
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedProfileId) { oldProfileId, newProfileId in
            // PHASE 3: Sync selectedProfileIndex when ViewModel auto-selects a profile
            if let newId = newProfileId,
               let index = appState.profiles.firstIndex(where: { $0.id == newId }) {
                selectedProfileIndex = index
            }
        }
        .alert("Delete Habit", isPresented: $showingDeleteConfirmation, presenting: habitToDelete) { habit in
            Button("Cancel", role: .cancel) {
                // Remove from pending deletion if user cancels
                habitsPendingDeletion.remove(habit.id)
                habitToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteHabit()
            }
        } message: { habit in
            Text("Are you sure you want to delete '\(habit.title)'?")
        }
    }
    
    // MARK: - 🏠 Header Section
    private var headerSection: some View {
        SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
    }

    // MARK: - 👤 Profile Card Section
    private func profileCardSection(profile: ElderlyProfile) -> some View {
        HStack(spacing: 16) {
            // Profile Image
            if let profileSlot = appState.profiles.firstIndex(where: { $0.id == profile.id }) {
                ProfileImageView.custom(
                    profile: profile,
                    profileSlot: profileSlot,
                    isSelected: false,
                    size: 60
                )
            }

            // Profile Name
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(AppFonts.poppinsMedium(size: 18))
                    .foregroundColor(.black)

                Text(profile.relationship)
                    .font(.custom("Inter", size: 14))
                    .foregroundColor(Color(hex: "9f9f9f"))
            }

            Spacer()

            // Edit Button (small circle with pen icon)
            Button(action: {
                HapticFeedback.light()
                showingImagePicker = true
            }) {
                Circle()
                    .fill(Color(hex: "f0f0f0"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    )
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                // Upload new profile image
                _Concurrency.Task {
                    await updateProfilePhoto(profile: profile, image: image)
                }
            }
        }
    }


    // MARK: - 🌟 Empty State - No Profiles
    /// Displayed when user has not created any profiles yet
    /// Guides user to create their first profile with arrow pointing to + button
    private var emptyStateNoProfiles: some View {
        VStack(spacing: 16) {
            Spacer()

            // Light blue circle with grandpa emoji (matching create flow)
            ZStack {
                Circle()
                    .fill(Color(hex: "B9E3FF"))
                    .frame(width: 120, height: 120)

                Text("👴")
                    .font(.system(size: 60))
            }

            // Bold headline
            Text("Create your first profile")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            // Subtext
            Text("Add a loved one to start sending reminders")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "9f9f9f"))
                .multilineTextAlignment(.center)

            // Create button pill
            Button(action: {
                HapticFeedback.medium()
                showingCreateActionSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Create")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
    }

    // MARK: - 📅 Week Overview Section
    /// Visual day-by-day view showing habit slots for each day of the week
    /// Features vertical connecting line with circles at each habit
    private var weekOverviewSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: Vertical line (circles will be overlaid)
            Rectangle()
                .fill(Color(hex: "D0D0D0"))
                .frame(width: 2)
                .frame(maxWidth: 30)

            // Right column: Day cards
            VStack(spacing: 12) {
                ForEach(Array(weekDaysOrdered.enumerated()), id: \.element) { index, weekday in
                    DayOverviewCardWithPositionReporting(
                        weekday: weekday,
                        habits: habitsForDay(weekday),
                        colorScheme: dayColorSchemes[index],
                        maxSlots: 3
                    )
                }
            }
        }
        .coordinateSpace(name: "weekOverview")
        .overlayPreferenceValue(HabitSlotPositionKey.self) { positions in
            GeometryReader { geo in
                // Position circles at exact Y positions of habits
                ForEach(positions, id: \.id) { position in
                    HabitTypeCircle(isPhoto: position.isPhoto)
                        .position(x: 15, y: position.yCenter)
                }
            }
        }
    }

    /// Days of the week ordered Monday-first
    private var weekDaysOrdered: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    /// Color schemes for each day (vibrant palettes)
    private var dayColorSchemes: [DayColorScheme] {
        [
            DayColorScheme(background: Color(hex: "E85B5B"), text: Color(hex: "8B1A1A"), slot: Color(hex: "D44A4A")),  // Monday - Red
            DayColorScheme(background: Color(hex: "5BBF5B"), text: Color(hex: "1A5C1A"), slot: Color(hex: "4AAE4A")),  // Tuesday - Green
            DayColorScheme(background: Color(hex: "F5D662"), text: Color(hex: "8B7A1A"), slot: Color(hex: "E0C350")),  // Wednesday - Yellow
            DayColorScheme(background: Color(hex: "7BC9E8"), text: Color(hex: "1A5A7A"), slot: Color(hex: "6AB8D7")),  // Thursday - Light Blue
            DayColorScheme(background: Color(hex: "F5A055"), text: Color(hex: "8B4A1A"), slot: Color(hex: "E08F44")),  // Friday - Orange
            DayColorScheme(background: Color(hex: "4A6BE8"), text: Color(hex: "1A2A6B"), slot: Color(hex: "3A5AD5")),  // Saturday - Dark Blue
            DayColorScheme(background: Color(hex: "A57EE8"), text: Color(hex: "4A2D6B"), slot: Color(hex: "946DD5"))   // Sunday - Purple
        ]
    }

    /// Get habits scheduled for a specific day
    private func habitsForDay(_ weekday: Weekday) -> [Task] {
        profileHabits.filter { habit in
            switch habit.frequency {
            case .daily:
                return true
            case .weekdays:
                return weekday != .saturday && weekday != .sunday
            case .custom:
                return habit.customDays.contains(weekday)
            case .weekly:
                // Check if the scheduled day matches
                let calendar = Calendar.current
                let scheduledWeekday = calendar.component(.weekday, from: habit.scheduledTime)
                return Weekday.from(weekday: scheduledWeekday) == weekday
            case .once:
                // Check if the one-time task is on this day
                let calendar = Calendar.current
                let taskWeekday = calendar.component(.weekday, from: habit.nextScheduledDate)
                return Weekday.from(weekday: taskWeekday) == weekday
            }
        }
    }

    // MARK: - 📋 Empty State - No Habits
    /// Displayed when no habits exist for the selected profile
    private var emptyStateNoHabits: some View {
        VStack(spacing: 12) {
            Text("No habits created yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "9f9f9f"))
                .padding(.vertical, 40)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(10)
    }

    // MARK: - 🗑️ Delete Profile Button Card
    /// Delete profile button as standalone pill
    private var deleteProfileButtonCard: some View {
        Button(action: {
            guard !isDeleteButtonCoolingDown else {
                return
            }

            HapticFeedback.medium()
            showingProfileDeleteConfirmation = true
        }) {
            Text("Delete Profile")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .background(Color(hex: "DC3545"))
        .clipShape(Capsule())
        .disabled(isDeleteButtonCoolingDown)
        .alert("Delete Profile", isPresented: $showingProfileDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                confirmDeleteProfile()
            }
        } message: {
            if let profile = selectedProfile {
                let habitCount = profileHabits.count
                Text("Are you sure you want to delete '\(profile.name)' and all \(habitCount) associated habit\(habitCount == 1 ? "" : "s")? This action cannot be undone.")
            } else {
                Text("No profile selected.")
            }
        }
    }
    
    // MARK: - Computed Properties

    /// PHASE 3: Selected profile accessor - Use AppState as single source of truth
    private var selectedProfile: ElderlyProfile? {
        guard selectedProfileIndex < appState.profiles.count else { return nil }
        return appState.profiles[selectedProfileIndex]
    }
    
    /// All habits for the selected profile
    private var profileHabits: [Task] {
        let allTasks = appState.tasks

        return allTasks.filter { habit in
            // Exclude locally deleted habits for optimistic UI
            guard !locallyDeletedHabitIds.contains(habit.id) else { return false }

            // Filter by selected profile
            guard let selectedProfileId = viewModel.selectedProfileId else { return false }
            return habit.profileId == selectedProfileId
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() {
        viewModel.loadDashboardData()
    }

    /// Upload new profile photo and update profile
    private func updateProfilePhoto(profile: ElderlyProfile, image: UIImage) async {
        // Convert UIImage to JPEG data (strip EXIF for privacy)
        guard let imageData = image.jpegDataWithoutEXIF(compressionQuality: 0.8) else {
            return
        }

        do {
            // Upload photo to Firebase Storage
            let databaseService = container.resolve(DatabaseServiceProtocol.self)
            let photoURL = try await databaseService.uploadProfilePhoto(imageData, for: profile.id, userId: profile.userId)

            // Update profile with new photo URL
            var updatedProfile = profile
            updatedProfile.photoURL = photoURL

            // Save to Firestore
            try await databaseService.updateElderlyProfile(updatedProfile)

            // Update AppState and clear old cached image
            await MainActor.run {
                appState.imageCache.removeCachedImage(for: profile.photoURL)
                appState.updateProfile(updatedProfile)
            }

            // Pre-load new image into cache
            await appState.imageCache.preloadProfileImages([updatedProfile])

            // Reset selected image
            await MainActor.run {
                selectedImage = nil
            }

        } catch {
            print("❌ [HabitsView] Failed to update profile photo: \(error.localizedDescription)")
        }
    }

    private func getProfileForHabit(_ habit: Task) -> ElderlyProfile? {
        // PHASE 3: Use AppState as single source of truth
        return appState.profiles.first { $0.id == habit.profileId }
    }
    
    private func deleteHabit(habit: Task) {
        // Mark as pending deletion (prevents List from auto-animating)
        habitsPendingDeletion.insert(habit.id)

        // Store habit and show confirmation alert
        habitToDelete = habit
        showingDeleteConfirmation = true
    }

    private func confirmDeleteHabit() {
        guard let habit = habitToDelete else { return }

        // Remove from pending deletion
        habitsPendingDeletion.remove(habit.id)

        // Optimistic UI update: immediately remove from local state with iOS-native spring animation
        _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            locallyDeletedHabitIds.insert(habit.id)
        }

        // Trigger haptic feedback immediately for responsiveness
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Perform database deletion in background
        _Concurrency.Task {
            do {
                // Delete habit from database with userId and profileId
                try await container.resolve(DatabaseServiceProtocol.self)
                    .deleteTask(habit.id, userId: habit.userId, profileId: habit.profileId)

                // Update AppState to remove the deleted task (fixes reappearing habit bug)
                await MainActor.run {
                    appState.deleteTask(habit.id)
                    viewModel.loadDashboardData()
                }

            } catch {
                print("❌ Failed to delete habit: \(error.localizedDescription)")

                // Revert optimistic update on error with spring animation
                await MainActor.run {
                    _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        locallyDeletedHabitIds.remove(habit.id)
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }

        // Clear state
        habitToDelete = nil
    }

    // MARK: - ✨ Unified Create Button
    /**
     * FLOATING UNIFIED CREATE BUTTON: Bottom center call-to-action
     * 
     * PURPOSE: Primary action button for creating new profiles or tasks
     * Positioned at bottom center for easy thumb access
     * Shows action sheet to choose between profile creation or task creation
     * Same size as profile circles for visual consistency
     */
    private var unifiedCreateButton: some View {
        Button(action: {
            // Haptic feedback for create action
            HapticFeedback.medium()

            showingCreateActionSheet = true
        }) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 61, height: 61) // Updated to match user requirements
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .overlay(
            CreateActionCard(
                isPresented: $showingCreateActionSheet,
                onCreateHabit: {
                    showingTaskCreation = true
                },
                onCreateProfile: {
                    profileViewModel.startProfileOnboarding()
                    showingDirectOnboarding = true
                }
            )
        )
    }
    
    // MARK: - 🗑️ Delete Profile Button Content
    /**
     * DELETE PROFILE BUTTON: Removes selected profile and all habits
     *
     * PURPOSE: Allow users to delete profiles to test Twilio SMS integration
     * Displays at bottom of merged card
     * Shows profile name and habit count in confirmation dialog
     */
    private var deleteProfileButtonContent: some View {
        Button(action: {
            guard !isDeleteButtonCoolingDown else {
                return
            }

            // Haptic feedback for delete action
            HapticFeedback.medium()

            showingProfileDeleteConfirmation = true
        }) {
            HStack {
                Text("Delete Profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)

                Spacer()  // Push content to the left
            }
            .frame(maxWidth: .infinity, minHeight: 47)
        }
        .disabled(isDeleteButtonCoolingDown)
        .alert("Delete Profile", isPresented: $showingProfileDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                confirmDeleteProfile()
            }
        } message: {
            if let profile = selectedProfile {
                let habitCount = profileHabits.count
                Text("Are you sure you want to delete '\(profile.name)' and all \(habitCount) associated habit\(habitCount == 1 ? "" : "s")? This action cannot be undone.")
            } else {
                Text("No profile selected.")
            }
        }
    }

    // MARK: - Profile Deletion Logic
    private func confirmDeleteProfile() {
        guard let profile = selectedProfile else {
            return
        }

        // Trigger haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Call ProfileViewModel to delete profile (recursive deletion of habits)
        profileViewModel.deleteProfile(profile)

        // Reset selected profile index to 0 after deletion
        selectedProfileIndex = 0
    }

    // MARK: - Helper Properties
    // selectedProfile is already defined earlier in the file
}

// MARK: - Habit Row With Custom Swipe
struct HabitRowWithCustomSwipe: View {
    let habit: Task
    let profile: ElderlyProfile?
    let isLastItem: Bool
    let onDelete: () -> Void

    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var isRevealed: Bool = false

    private let deleteButtonWidth: CGFloat = 80
    private let swipeThreshold: CGFloat = 50

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background (always present, revealed by drag)
            HStack {
                Spacer()
                Button(action: {
                    // Don't animate here - just trigger delete confirmation
                    onDelete()
                    // Keep button revealed until user confirms/cancels
                }) {
                    ZStack {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: deleteButtonWidth)

                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxHeight: .infinity)
            }

            // Main content that slides
            VStack(spacing: 0) {
                HabitRowViewSimple(
                    habit: habit,
                    profile: profile
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Divider
                if !isLastItem {
                    Divider()
                        .overlay(Color(hex: "f8f3f3"))
                        .padding(.horizontal, 4)
                }
            }
            .background(Color.white)
            .offset(x: dragOffset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let translation = value.translation.width
                        let verticalTranslation = abs(value.translation.height)
                        let horizontalTranslation = abs(translation)

                        // Require swipe to be STRONGLY horizontal (3x more horizontal than vertical)
                        // This prevents accidental tab switching while allowing scroll
                        guard horizontalTranslation > verticalTranslation * 3 else { return }

                        // Only allow left swipe
                        if translation < 0 {
                            dragOffset = max(translation, -deleteButtonWidth)
                        } else if isRevealed {
                            // Allow closing if already revealed
                            dragOffset = min(0, -deleteButtonWidth + translation)
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let verticalTranslation = abs(value.translation.height)
                        let horizontalTranslation = abs(translation)

                        // Require swipe to be STRONGLY horizontal
                        guard horizontalTranslation > verticalTranslation * 3 else { return }

                        withAnimation(.easeOut(duration: 0.25)) {
                            if translation < -swipeThreshold {
                                // Reveal delete button
                                dragOffset = -deleteButtonWidth
                                isRevealed = true
                            } else {
                                // Close
                                dragOffset = 0
                                isRevealed = false
                            }
                        }
                    }
            )
        }
    }
}

// MARK: - Habit Card View Component
/// Individual habit as standalone card (matches other cards in view)
struct HabitCardView: View {
    let habit: Task
    let profile: ElderlyProfile?
    let onTap: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    private let habitColors: [Color] = [
        Color(hex: "B9E3FF"),
        Color.red.opacity(0.6),
        Color.green.opacity(0.6),
        Color.purple.opacity(0.6),
        Color.orange.opacity(0.6)
    ]

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Emoji with colored circle background
                ZStack {
                    Circle()
                        .fill(habitColor)
                        .frame(width: 40, height: 40)

                    Text(getHabitEmoji(habit))
                        .font(.system(size: 20))
                }

                // Title + Frequency
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)

                    Text(smartFrequencyText(for: habit))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "9f9f9f"))
                }

                Spacer()

                // Time
                Text(DateFormatters.formatTime(habit.scheduledTime))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
    }

    private var habitColor: Color {
        let hash = abs(habit.id.hashValue)
        let colorIndex = hash % habitColors.count
        return habitColors[colorIndex]
    }

    private func getHabitEmoji(_ habit: Task) -> String {
        if habit.requiresPhoto {
            return "📷"
        } else if habit.requiresText {
            return "💬"
        } else {
            return "📷"
        }
    }

    private func smartFrequencyText(for habit: Task) -> String {
        let scheduledDays = getScheduledDays(for: habit)
        let dayCount = scheduledDays.count

        switch dayCount {
        case 7:
            return "Daily"
        case 5:
            let weekdays = [1, 2, 3, 4, 5]
            if scheduledDays == weekdays {
                return "Weekdays"
            }
            fallthrough
        case 2:
            let weekend = [0, 6]
            if scheduledDays == weekend {
                return "Weekends"
            }
            fallthrough
        case 1:
            let dayIndex = scheduledDays.first ?? 0
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            return "Every \(dayNames[dayIndex])"
        case 6:
            let allDays = Set([0, 1, 2, 3, 4, 5, 6])
            let missingDay = allDays.subtracting(scheduledDays).first ?? 0
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            return "Daily except \(dayNames[missingDay])"
        case 2...5:
            let dayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let dayStrings = scheduledDays.map { dayAbbreviations[$0] }
            return dayStrings.joined(separator: ", ")
        default:
            return "Custom"
        }
    }

    private func getScheduledDays(for habit: Task) -> [Int] {
        switch habit.frequency {
        case .daily:
            return [0, 1, 2, 3, 4, 5, 6]
        case .weekdays:
            return [1, 2, 3, 4, 5]
        case .weekly:
            let taskWeekday = Calendar.current.component(.weekday, from: habit.scheduledTime)
            return [taskWeekday - 1]
        case .custom:
            return habit.customDays.map { $0.toIndex() }.sorted()
        case .once:
            return []
        }
    }
}

// MARK: - Simplified Habit Row View Component
struct HabitRowViewSimple: View {
    let habit: Task
    let profile: ElderlyProfile?

    // PHASE 3: Need appState for profile slot calculation
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    // Pastel colors matching profile colors
    private let habitColors: [Color] = [
        Color(hex: "B9E3FF"),   // Light blue
        Color.red.opacity(0.6), // Red
        Color.green.opacity(0.6), // Green
        Color.purple.opacity(0.6), // Purple
        Color.orange.opacity(0.6)  // Orange
    ]

    var body: some View {
        HStack(spacing: 12) {
            // Emoji with colored circle background
            ZStack {
                Circle()
                    .fill(habitColor)
                    .frame(width: 40, height: 40)

                Text(getHabitEmoji(habit))
                    .font(.system(size: 20)) // Slightly smaller to fit in circle
            }

            // Title + Frequency
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Text(smartFrequencyText(for: habit))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "9f9f9f"))
            }

            Spacer()

            // Time
            Text(DateFormatters.formatTime(habit.scheduledTime))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "F8F8F8"))
        )
    }

    // MARK: - Computed Properties

    /// Returns consistent color for this habit based on its ID
    private var habitColor: Color {
        // Use hash of habit ID to pick consistent color
        let hash = abs(habit.id.hashValue)
        let colorIndex = hash % habitColors.count
        return habitColors[colorIndex]
    }

    // MARK: - Helper Functions

    /// Returns emoji based on confirmation method (photo vs text)
    private func getHabitEmoji(_ habit: Task) -> String {
        // Use photo emoji for photo confirmation, text bubble for text confirmation
        if habit.requiresPhoto {
            return "📷" // Camera emoji for photo-based habits
        } else if habit.requiresText {
            return "💬" // Speech bubble emoji for text-based habits
        } else {
            // Fallback: use photo emoji as default
            return "📷"
        }
    }

    /// Generates natural language frequency description
    private func smartFrequencyText(for habit: Task) -> String {
        let scheduledDays = getScheduledDays(for: habit)
        let dayCount = scheduledDays.count

        switch dayCount {
        case 7:
            return "Daily"
        case 5:
            // Check if it's Mon-Fri
            let weekdays = [1, 2, 3, 4, 5]
            if scheduledDays == weekdays {
                return "Weekdays"
            }
            fallthrough
        case 2:
            // Check if it's Sat-Sun
            let weekend = [0, 6]
            if scheduledDays == weekend {
                return "Weekends"
            }
            fallthrough
        case 1:
            // Single day - "Every Monday"
            let dayIndex = scheduledDays.first ?? 0
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            return "Every \(dayNames[dayIndex])"
        case 6:
            // Daily except one day
            let allDays = Set([0, 1, 2, 3, 4, 5, 6])
            let missingDay = allDays.subtracting(scheduledDays).first ?? 0
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            return "Daily except \(dayNames[missingDay])"
        case 2...5:
            // 2-5 specific days - list them
            let dayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let dayStrings = scheduledDays.map { dayAbbreviations[$0] }
            return dayStrings.joined(separator: ", ")
        default:
            return "Custom"
        }
    }

    /// Returns array of day indices (0-6) that the habit is scheduled for
    private func getScheduledDays(for habit: Task) -> [Int] {
        switch habit.frequency {
        case .daily:
            return [0, 1, 2, 3, 4, 5, 6] // All days
        case .weekdays:
            return [1, 2, 3, 4, 5] // Mon-Fri
        case .weekly:
            let taskWeekday = Calendar.current.component(.weekday, from: habit.scheduledTime)
            return [taskWeekday - 1] // Single day
        case .custom:
            return habit.customDays.map { $0.toIndex() }.sorted()
        case .once:
            return [] // No recurring days
        }
    }

}

// MARK: - Weekday Helper Extensions
extension Weekday {
    static func fromIndex(_ index: Int) -> Weekday {
        switch index {
        case 0: return .sunday
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        default: return .sunday
        }
    }

    func toIndex() -> Int {
        switch self {
        case .sunday: return 0
        case .monday: return 1
        case .tuesday: return 2
        case .wednesday: return 3
        case .thursday: return 4
        case .friday: return 5
        case .saturday: return 6
        }
    }
}

// MARK: - Day Color Scheme
/// Monochromatic color palette for a day card
struct DayColorScheme {
    let background: Color  // Main card background
    let text: Color        // Day label text (darker shade)
    let slot: Color        // Slot background (slightly darker than background)
}

// MARK: - Habit Slot Position Preference
/// Preference key for collecting habit slot Y positions
struct HabitSlotPositionKey: PreferenceKey {
    static var defaultValue: [HabitSlotPosition] = []

    static func reduce(value: inout [HabitSlotPosition], nextValue: () -> [HabitSlotPosition]) {
        value.append(contentsOf: nextValue())
    }
}

struct HabitSlotPosition: Equatable, Identifiable {
    let id: String      // Unique position ID (habitId + dayIndex + slotIndex)
    let yCenter: CGFloat
    let isPhoto: Bool
}

// MARK: - Habit Type Circle
/// Circle with emoji indicating habit type (photo or text)
struct HabitTypeCircle: View {
    let isPhoto: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "D0D0D0"), lineWidth: 2)
                )

            Text(isPhoto ? "📷" : "💬")
                .font(.system(size: 14))
        }
    }
}

// MARK: - Day Overview Card
/// A card representing a single day of the week with habit slots
struct DayOverviewCard: View {
    let weekday: Weekday
    let habits: [Task]
    let colorScheme: DayColorScheme
    let maxSlots: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day label in top-left
            Text(weekday.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            // Habit slots (3 slots per day) - vertical for more room
            VStack(spacing: 8) {
                ForEach(0..<maxSlots, id: \.self) { slotIndex in
                    if slotIndex < habits.count {
                        // Filled slot - show habit info
                        FilledHabitSlot(
                            habit: habits[slotIndex],
                            colorScheme: colorScheme
                        )
                    } else {
                        // Empty slot - show placeholder
                        EmptyHabitSlot(colorScheme: colorScheme)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme.background)
                .shadow(color: colorScheme.background.opacity(0.5), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Day Overview Card With Position Reporting
/// A card that reports the Y positions of its habit slots for circle alignment
struct DayOverviewCardWithPositionReporting: View {
    let weekday: Weekday
    let habits: [Task]
    let colorScheme: DayColorScheme
    let maxSlots: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day label in top-left
            Text(weekday.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            // Habit slots (3 slots per day) - vertical for more room
            VStack(spacing: 8) {
                ForEach(0..<maxSlots, id: \.self) { slotIndex in
                    if slotIndex < habits.count {
                        let habit = habits[slotIndex]
                        // Filled slot with position reporting
                        FilledHabitSlot(
                            habit: habit,
                            colorScheme: colorScheme
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: HabitSlotPositionKey.self,
                                    value: [HabitSlotPosition(
                                        id: "\(weekday.rawValue)_\(slotIndex)_\(habit.id)",
                                        yCenter: geo.frame(in: .named("weekOverview")).midY,
                                        isPhoto: habit.requiresPhoto
                                    )]
                                )
                            }
                        )
                    } else {
                        // Empty slot - show placeholder
                        EmptyHabitSlot(colorScheme: colorScheme)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme.background)
                .shadow(color: colorScheme.background.opacity(0.5), radius: 12, x: 0, y: 4)
        )
    }
}


// MARK: - Filled Habit Slot
/// A slot showing an existing habit
struct FilledHabitSlot: View {
    let habit: Task
    let colorScheme: DayColorScheme

    var body: some View {
        HStack {
            // Habit title
            Text(habit.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(1)

            Spacer()

            // Time
            Text(DateFormatters.formatTime(habit.scheduledTime))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "666666"))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "f9f9f9"))
        )
    }
}

// MARK: - Empty Habit Slot
/// An empty slot indicating room for a habit
struct EmptyHabitSlot: View {
    let colorScheme: DayColorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme.slot)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
    }
}


