import SwiftUI

// MARK: - Habit Creation Card Component
/**
 * HABIT CREATION CARD: Custom white card popup for creating new habits
 *
 * PURPOSE: Replaces multi-step wizard with single-screen form in card format
 * DESIGN: White rounded card with shadow, slides up from bottom
 * SECTIONS: Profile selector, habit name, days, times, confirmation method
 *
 * USAGE:
 * ```swift
 * .overlay(
 *     HabitCreationCard(
 *         isPresented: $showingHabitCreation,
 *         preselectedProfileId: selectedProfileId,
 *         onDismiss: { showingHabitCreation = false }
 *     )
 * )
 * ```
 */
struct HabitCreationCard: View {
    @Binding var isPresented: Bool
    let preselectedProfileId: String?
    let onDismiss: () -> Void

    // Environment
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel

    // Form state
    @State private var selectedProfileId: String?
    @State private var habitName: String = ""
    @State private var selectedEmoji: String = "😊" // Default emoji
    @State private var selectedDays: Set<Int> = []
    @State private var selectedTimes: [Date] = []
    @State private var confirmationMethod: String = "" // "photo" or "text"
    @State private var showingTimePicker: Bool = false
    @State private var tempSelectedTime = Date()
    @State private var isCreating = false // Loading state
    @State private var showingEmojiPicker = false // Emoji picker state

    // Emoji options for habit
    private let emojiOptions = ["😊", "💊", "🏃", "📚", "💪", "🧘", "🥗", "💧", "🛏️", "🧠", "❤️", "🎯", "✨", "🌟", "🔥"]

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed background overlay (tap to dismiss)
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }

                        // Reset form and call dismiss callback after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            resetForm()
                            onDismiss()
                        }
                    }
                    .transition(.opacity)
            }

            // White card popup
            VStack {
                Spacer()

                if isPresented {
                    cardContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
        .sheet(isPresented: $showingTimePicker) {
            TimePickerSheet(
                selectedTime: $tempSelectedTime,
                selectedTimes: $selectedTimes,
                isPresented: $showingTimePicker
            )
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerSheet(
                selectedEmoji: $selectedEmoji,
                emojiOptions: emojiOptions,
                isPresented: $showingEmojiPicker
            )
        }
        .onAppear {
            // Set preselected profile if provided
            if let profileId = preselectedProfileId {
                selectedProfileId = profileId
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Card with scrollable content + button inside
            VStack(spacing: 0) {
                // Off-white title tab at top (rounded only on top corners)
                ZStack {
                    // Top corners only rounded
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                    .fill(Color(hex: "f9f9f9"))
                    .frame(height: 50)

                    Text("New Habit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(height: 50)
                .zIndex(1)

                ScrollView {
                    VStack(spacing: 24) { // Clean spacing between sections
                        // Profile Selector
                        profileSelectorSection

                        // Habit Name
                        habitNameSection

                        // Days of Week
                        daysSection

                        // Times
                        timesSection

                        // Confirmation Method
                        confirmationMethodSection

                        // Button inside card (scrollable)
                        if !isTextFieldFocused {
                            createButtonInside
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 24) // Match CreateActionCard's internal padding
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 500)
                .background(Color.white)
                .onTapGesture {
                    // Dismiss keyboard when tapping anywhere in the scroll view
                    isTextFieldFocused = false
                }
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
            .padding(.horizontal, 16) // Match CreateActionCard exactly
            .padding(.bottom, 90) // Position right above tab bar (same as CreateActionCard)
        }
    }

    // MARK: - Profile Selector Section
    private var profileSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who Is This For?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 10) {
                ForEach(appState.profiles) { profile in
                    profileRow(for: profile)
                }
            }
            .padding(12)
            .background(Color(hex: "F8F8F8"))
            .cornerRadius(12)
        }
    }

    private func profileRow(for profile: ElderlyProfile) -> some View {
        let isSelected = selectedProfileId == profile.id
        let profileSlot = appState.profiles.firstIndex(where: { $0.id == profile.id }) ?? 0

        return Button(action: {
            HapticFeedback.light()
            selectedProfileId = profile.id
        }) {
            HStack(spacing: 14) {
                // Profile picture on left
                ProfileImageView(
                    profile: profile,
                    profileSlot: profileSlot,
                    isSelected: isSelected,
                    size: .custom(45)
                )

                // Name in bold on right
                Text(profile.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)

                Spacer()

                // Selection indicator - green checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(10)
        }
    }


    // MARK: - Habit Name Section
    private var habitNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's The Habit?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            // Habit name input wrapped in light grey card
            VStack(spacing: 12) {
                // Combined Emoji + Text Field
                HStack(spacing: 12) {
                    // Emoji on left (clickable)
                    Button(action: {
                        HapticFeedback.light()
                        isTextFieldFocused = false
                        showingEmojiPicker = true
                    }) {
                        Text(selectedEmoji)
                            .font(.system(size: 28))
                    }

                    // Text Field on right
                    ZStack(alignment: .leading) {
                        TextField("", text: $habitName)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)
                            .focused($isTextFieldFocused)

                        if habitName.isEmpty {
                            Text("e.g., take medication")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.gray.opacity(0.8))
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(10)

                // Trending Habits Section (inside grey card)
                trendingHabitsContent
            }
            .padding(12)
            .background(Color(hex: "F8F8F8"))
            .cornerRadius(12)
        }
    }

    // MARK: - Trending Habits Content (no padding/background, used inside grey card)
    private var trendingHabitsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trending popular habits")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(trendingHabits, id: \.0) { emoji, habitName in
                        Button(action: {
                            HapticFeedback.light()
                            selectedEmoji = emoji
                            self.habitName = habitName
                        }) {
                            HStack(spacing: 8) {
                                Text(emoji)
                                    .font(.system(size: 22))
                                Text(habitName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    // Trending habits data
    private let trendingHabits: [(String, String)] = [
        ("💊", "Take medication"),
        ("🚶", "Morning walk"),
        ("💧", "Drink water"),
        ("📖", "Read book"),
        ("🧘", "Meditation"),
        ("🥗", "Healthy meal")
    ]

    // MARK: - Days Section
    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which Days?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            // Week selector wrapped in light grey box
            VStack(spacing: 10) {
                ForEach(0..<7) { index in
                    Button(action: {
                        HapticFeedback.light()
                        if selectedDays.contains(index) {
                            selectedDays.remove(index)
                        } else {
                            selectedDays.insert(index)
                        }
                    }) {
                        HStack {
                            Text(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][index])
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)

                            Spacer()

                            if selectedDays.contains(index) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(12)
            .background(Color(hex: "F8F8F8")) // Same as trending habits
            .cornerRadius(12)
        }
    }

    // MARK: - Times Section
    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Times?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 10) {
                // Display selected times as white rectangles
                ForEach(Array(selectedTimes.enumerated()), id: \.offset) { index, time in
                    HStack {
                        Text(DateFormatters.formatTime(time))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)

                        Spacer()

                        Button(action: {
                            selectedTimes.remove(at: index)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "9f9f9f"))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)
                }

                // Add Time button - light grey box
                Button(action: {
                    showingTimePicker = true
                }) {
                    HStack {
                        Text("🕐")
                            .font(.system(size: 20))
                        Text("Add Time")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "F8F8F8"))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Confirmation Method Section
    private var confirmationMethodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How To Confirm?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            HStack(spacing: 10) {
                // Photo Option
                Button(action: {
                    HapticFeedback.light()
                    confirmationMethod = "photo"
                }) {
                    HStack(spacing: 10) {
                        Text("📷")
                            .font(.system(size: 28))
                        Text("Photo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(confirmationMethod == "photo" ? .white : .black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(confirmationMethod == "photo" ? Color.black : Color(hex: "F5F5F5"))
                    .cornerRadius(10)
                }

                // Text Option
                Button(action: {
                    HapticFeedback.light()
                    confirmationMethod = "text"
                }) {
                    HStack(spacing: 10) {
                        Text("💬")
                            .font(.system(size: 28))
                        Text("Text")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(confirmationMethod == "text" ? .white : .black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(confirmationMethod == "text" ? Color.black : Color(hex: "F5F5F5"))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Create Button (Inside Card)
    private var createButtonInside: some View {
        Button(action: handleCreateHabit) {
            ZStack {
                // Button text (hidden when loading)
                Text("Create Habit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(isCreating ? 0 : 1)

                // Loading indicator
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48) // Reduced from 50 to 48 for more compact look
            .background(canCreate && !isCreating ? Color.black : Color.gray.opacity(0.3))
            .cornerRadius(14) // Reduced from 15 to 14 to match confirmation cards
        }
        .disabled(!canCreate || isCreating)
        .padding(.bottom, 4) // Small bottom padding inside card
    }

    // MARK: - Validation
    private var canCreate: Bool {
        !habitName.isEmpty &&
        selectedProfileId != nil &&
        !selectedDays.isEmpty &&
        !selectedTimes.isEmpty &&
        !confirmationMethod.isEmpty
    }

    // MARK: - Actions
    private func handleCreateHabit() {
        guard canCreate && !isCreating else { return }
        guard let profileId = selectedProfileId else { return }
        guard let profile = appState.profiles.first(where: { $0.id == profileId }) else { return }

        // Set loading state immediately
        isCreating = true

        // Haptic feedback
        HapticFeedback.medium()

        // Transfer data to TaskViewModel
        taskViewModel.selectedProfile = profile
        // Prepend emoji to habit name with a space
        taskViewModel.taskTitle = "\(selectedEmoji) \(habitName)"
        taskViewModel.taskCategory = .medication
        taskViewModel.frequency = .custom
        taskViewModel.scheduledTimes = selectedTimes
        taskViewModel.customDays = convertDaysToWeekdays(selectedDays)

        // Set confirmation method
        if confirmationMethod == "photo" {
            taskViewModel.requiresPhoto = true
            taskViewModel.requiresText = false
        } else {
            taskViewModel.requiresPhoto = false
            taskViewModel.requiresText = true
        }

        // FIX: Run validation synchronously before attempting to create task
        // Don't bypass validation - it's critical for 30-minute gap enforcement
        // Wait a moment for validation to complete, then check if form is valid
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Check if validation passed
            if !taskViewModel.isValidForm {
                // Validation failed - show error and reset loading state
                isCreating = false
                // Error message is already set by validation
                return
            }

            // Validation passed - create task
            taskViewModel.createTask()

            // Small delay before dismissing to show loading state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Reset loading state
                isCreating = false

                // Dismiss card
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPresented = false
                }

                // Reset form and call dismiss callback after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    resetForm()
                    onDismiss()
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func resetForm() {
        selectedProfileId = nil
        habitName = ""
        selectedEmoji = "😊"
        selectedDays = []
        selectedTimes = []
        confirmationMethod = ""
        isCreating = false
    }

    private func convertDaysToWeekdays(_ days: Set<Int>) -> Set<Weekday> {
        Set(days.compactMap { dayIndex in
            switch dayIndex {
            case 0: return .sunday
            case 1: return .monday
            case 2: return .tuesday
            case 3: return .wednesday
            case 4: return .thursday
            case 5: return .friday
            case 6: return .saturday
            default: return nil
            }
        })
    }
}

// MARK: - Emoji Picker Sheet
struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    let emojiOptions: [String]
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Grid of emojis
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button(action: {
                            HapticFeedback.light()
                            selectedEmoji = emoji
                            isPresented = false
                        }) {
                            Text(emoji)
                                .font(.system(size: 40))
                                .frame(width: 60, height: 60)
                                .background(selectedEmoji == emoji ? Color(hex: "B9E3FF") : Color(hex: "F8F8F8"))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Select Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview
// Note: TimePickerSheet is defined in TaskViews.swift and reused here
#Preview {
    ZStack {
        Color(hex: "f9f9f9")
            .ignoresSafeArea()

        HabitCreationCard(
            isPresented: .constant(true),
            preselectedProfileId: nil,
            onDismiss: { print("Dismissed") }
        )
        .environmentObject(AppState(
            authService: Container.shared.resolve(AuthenticationServiceProtocol.self),
            databaseService: Container.shared.resolve(DatabaseServiceProtocol.self),
            dataSyncCoordinator: Container.shared.resolve(DataSyncCoordinator.self),
            imageCache: Container.shared.resolve(ImageCacheService.self)
        ))
        .environmentObject(ProfileViewModel(
            databaseService: Container.shared.resolve(DatabaseServiceProtocol.self),
            smsService: Container.shared.resolve(SMSServiceProtocol.self),
            authService: Container.shared.resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: Container.shared.resolve(DataSyncCoordinator.self)
        ))
        .environmentObject(Container.shared.makeTaskViewModel())
    }
}
