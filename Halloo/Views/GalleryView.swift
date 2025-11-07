import SwiftUI

// Import the gallery history event model and profile gallery item view
// These imports ensure the new components are available in GalleryView

struct GalleryView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.container) private var container
    @Environment(\.isScrollDisabled) private var isScrollDisabled

    // PHASE 3: Single source of truth for shared state
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel

    // MARK: - Navigation State
    /// Tab selection binding from parent ContentView for floating pill navigation
    @Binding var selectedTab: Int

    /// Binding to ContentView's create action sheet state
    @Binding var showingCreateActionSheet: Bool

    /// Controls whether to show header (false when rendered in ContentView's layered architecture)
    var showHeader: Bool = true

    // MARK: - State
    @State private var selectedFilter: GalleryFilter = .all
    @State private var selectedEventForDetail: GalleryHistoryEvent?
    @State private var showingAccountSettings = false

    // MARK: - Initialization
    init(selectedTab: Binding<Int>, showingCreateActionSheet: Binding<Bool>, showHeader: Bool = true) {
        self._selectedTab = selectedTab
        self._showingCreateActionSheet = showingCreateActionSheet
        self.showHeader = showHeader
    }
    
    var body: some View {
        ZStack {
            // Match DashboardView structure exactly - no NavigationView wrapper
            ScrollView {
                VStack(spacing: 0) { // Match DashboardView spacing: 0 between sections

                    // Header with Remi logo and settings (no profile selection needed for Gallery) (conditionally rendered)
                    if showHeader {
                        galleryHeaderSection
                            .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Header gets padding
                    }

                    // Gallery card - match spacing ratio with DashboardView profiles
                    VStack(alignment: .leading, spacing: 16) {
                        // White card container (92% screen width)
                        VStack(spacing: 0) {
                            // Gallery card header with title and filter button
                            galleryCardHeader
                                .background(Color.white)

                            // Photo Grid extends naturally without bottom rounding
                            photoGridContent
                                .background(Color.white)
                                .animation(.easeInOut(duration: 0.3), value: selectedFilter)
                        }
                        .cornerRadius(10) // Round all corners
                        .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2) // Subtle shadow matching DashboardView
                    }
                    .padding(.top, showHeader ? 0 : 100) // Add top padding when header is hidden (static header height)

                    // Bottom padding to prevent content from hiding behind navigation
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Match DashboardView (96% width)
            }
            .scrollDisabled(isScrollDisabled)
            .background(Color(hex: "f9f9f9")) // Light gray app background
        }
        .onAppear {
            // View appeared - data is loaded from AppState
        }
        .fullScreenCover(item: $selectedEventForDetail) { event in
            // PHASE 4: Read from AppState instead of ViewModel
            let currentIndex = appState.galleryEvents.firstIndex(where: { $0.id == event.id }) ?? 0
            let totalEvents = appState.galleryEvents.count

            GalleryDetailView(
                event: event,
                selectedTab: $selectedTab,
                currentIndex: currentIndex,
                totalEvents: totalEvents,
                onPrevious: {
                    navigateToPrevious(from: event)
                },
                onNext: {
                    navigateToNext(from: event)
                }
            )
            .environmentObject(appState)
            .environmentObject(profileViewModel)
            .environmentObject(dashboardViewModel)
            .inject(container: container)
            .presentationBackground(.clear) // Transparent background to show underlying navigation
            .transition(.identity) // No transition effect for gallery detail
        }
    }

    // MARK: - Navigation Helpers

    private func navigateToPrevious(from currentEvent: GalleryHistoryEvent) {
        // PHASE 4: Read from AppState instead of ViewModel
        guard let currentIndex = appState.galleryEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex > 0 else { return }

        let previousEvent = appState.galleryEvents[currentIndex - 1]
        selectedEventForDetail = previousEvent
    }

    private func navigateToNext(from currentEvent: GalleryHistoryEvent) {
        // PHASE 4: Read from AppState instead of ViewModel
        guard let currentIndex = appState.galleryEvents.firstIndex(where: { $0.id == currentEvent.id }),
              currentIndex < appState.galleryEvents.count - 1 else { return }

        let nextEvent = appState.galleryEvents[currentIndex + 1]
        selectedEventForDetail = nextEvent
    }

    /// Get profile initial letter for display in gallery
    /// PHASE 3: Looks up profile by ID from AppState and returns first letter of name
    private func getProfileInitial(for profileId: String) -> String? {
        guard let profile = appState.profiles.first(where: { $0.id == profileId }) else {
            return nil
        }
        return String(profile.name.prefix(1)).uppercased()
    }

    /// Get profile slot index for color coding
    /// PHASE 3: Looks up profile by ID from AppState and returns its index
    private func getProfileSlot(for profileId: String) -> Int? {
        guard let index = appState.profiles.firstIndex(where: { $0.id == profileId }) else {
            return nil
        }
        return index
    }

    /// Render appropriate gallery view based on event type
    @ViewBuilder
    private func galleryEventView(for event: GalleryHistoryEvent) -> some View {
        switch event.eventData {
        case .taskResponse:
            GalleryPhotoView.taskResponse(
                event: event,
                profileInitial: getProfileInitial(for: event.profileId),
                profileSlot: getProfileSlot(for: event.profileId)
            )
        case .profileCreated:
            // Use ProfileGalleryItemView for profile creation events
            ProfileGalleryItemView(event: event)
        }
    }
}

// MARK: - Helper Extensions
extension GalleryView {
    // Simple header with just logo and settings (no profile selection)
    private var galleryHeaderSection: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Remi")
                .font(AppFonts.poppinsMedium(size: 37.5))
                .tracking(-3.1)
                .foregroundColor(.black)
                .fixedSize()
                .layoutPriority(1)

            Spacer()

            Button(action: {
                HapticFeedback.medium()
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingAccountSettings = true
                }
            }) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background(Color(hex: "f9f9f9")) // Match app background color
        .fullScreenCoverNoAnimation(isPresented: $showingAccountSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(profileViewModel)
        }
    }

    // Gallery Card Header Component - Horizontal Filter Selector
    private var galleryCardHeader: some View {
        HStack(spacing: 0) {
            ForEach(GalleryFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .regular))
                        .foregroundColor(selectedFilter == filter ? .black : Color(hex: "9f9f9f"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedFilter == filter ?
                            Color(hex: "f0f0f0") : Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background(Color(hex: "f9f9f9"))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // Photo Grid Content Component
    private var photoGridContent: some View {
        LazyVStack(spacing: 16) {
            if groupedEventsByDate.isEmpty {
                // Empty state: Centered content directly on card background
                VStack(spacing: 16) {
                    Spacer()

                    // Light blue rounded square with salad emoji
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "B9E3FF"))
                            .frame(width: 120, height: 120)

                        Text("🥗")
                            .font(.system(size: 60))
                    }

                    // Bold headline
                    Text("Make your first habit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)

                    // Subtext
                    Text("Start saving messages from your loved ones")
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
                .frame(height: 500) // Taller height to get closer to nav bar
            } else {
                ForEach(groupedEventsByDate, id: \.date) { dateGroup in
                    VStack(alignment: .leading, spacing: 8) {
                        // Date header
                        HStack {
                            Text(formatDateHeader(dateGroup.date))
                                .tracking(-1)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color(hex: "9f9f9f"))  // Dark grey
                            Spacer()
                        }
                        .padding(.horizontal, 12)

                        // Photo grid for this date
                        LazyVGrid(columns: gridColumns, spacing: 4) {
                            ForEach(dateGroup.events) { event in
                                // Render appropriate view based on event type
                                galleryEventView(for: event)
                                    .onTapGesture {
                                        selectedEventForDetail = event
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
        .padding(.bottom, 120) // Space for last photos + tab bar clearance
    }
    
    // Grid Layout Configuration
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    // Group events by date
    private var groupedEventsByDate: [(date: Date, events: [GalleryHistoryEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.createdAt)
        }

        let result = grouped.map { (date: $0.key, events: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }

        return result
    }
    
    // Filter events based on selected filter
    // PHASE 4: Read from AppState (single source of truth) instead of ViewModel
    private var filteredEvents: [GalleryHistoryEvent] {
        let events: [GalleryHistoryEvent]
        switch selectedFilter {
        case .all:
            events = appState.galleryEvents
        case .photos:
            events = appState.galleryEvents.filter { $0.photoData != nil }
        case .sms:
            events = appState.galleryEvents.filter { $0.hasTextResponse }
        }
        return events
    }
    
    // Format date for section headers
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    // Example text message box (unclickable)
    private var exampleTextMessageBox: some View {
        ZStack {
            // Light background
            Color(hex: "f5f5f5")

            // Middle aligned vertically
            VStack(spacing: 6) {
                // Outgoing message bubble (blue, top right) with 3 lines of broken up bars
                HStack {
                    Spacer()
                    MiniSpeechBubble(
                        textLines: [
                            [(11, 1.5), (13, 1.5), (15, 1.5)],   // Line 1: 3 segments = 2 gaps
                            [(18, 1.5), (17, 1.5)],              // Line 2: 2 segments = 1 gap
                            [(10, 1.5), (14, 1.5), (12, 1.5)]    // Line 3: 3 segments = 2 gaps
                        ],
                        isOutgoing: true,
                        backgroundColor: Color(hex: "007AFF"),
                        tailInset: 8
                    )
                }
                .padding(.trailing, 6)

                // Incoming message bubble (gray, bottom left) with 1 line of broken up bars
                HStack {
                    MiniSpeechBubble(
                        textLines: [
                            [(13, 1.5), (15, 1.5), (10, 1.5)]  // Line 1: 3 segments = 2 gaps
                        ],
                        isOutgoing: false,
                        backgroundColor: Color(hex: "E5E5EA"),
                        tailInset: 8
                    )
                    Spacer()
                }
                .padding(.leading, 6)
            }

            // Small light blue circle in bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color(hex: "ADD8E6"))
                        .frame(width: 16, height: 16)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 112, height: 112)
        .cornerRadius(3)
        .allowsHitTesting(false) // Make unclickable
    }
}

// MARK: - Gallery Filter Enum
enum GalleryFilter: String, CaseIterable {
    case all = "All"
    case photos = "Photos"
    case sms = "SMS"
}

// MARK: - Components moved to separate files
// Photo components moved to /Views/Components/GalleryPhotoView.swift