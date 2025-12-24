import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let galleryTabTapped = Notification.Name("galleryTabTapped")
}

/**
 * GALLERY DETAIL VIEW - Expanded content view for gallery items
 *
 * PURPOSE: Full-screen detailed view of gallery content (photos, SMS texts, profile creation events)
 * Replaces the squished gallery grid with expansive, readable content display
 *
 * CONTENT TYPES:
 * - Photos: Large image with "task confirmed" + task name + completion time
 * - SMS Texts: Conversation-style bubbles with sent/received messages  
 * - Profile Creation: Large profile picture with "profile created" + name + creation time
 *
 * NAVIGATION: Full-screen cover with shared header and bottom pill navigation
 * UI CONSISTENCY: Matches DashboardView and GalleryView design language
 */
struct GalleryDetailView: View {

    // MARK: - Properties
    let event: GalleryHistoryEvent
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.container) private var container
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel

    // Navigation state
    let currentIndex: Int
    let totalEvents: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    // Computed navigation availability
    private var hasPrevious: Bool { currentIndex > 0 }
    private var hasNext: Bool { currentIndex < totalEvents - 1 }

    // Animation state
    @State private var showBottomNavBar = false

    // Navigation bar state
    @State private var isCreateExpanded: Bool = false
    @State private var showingCreateActionSheet: Bool = false
    @State private var selectedProfileIndex: Int = 0

    // Creation card states
    @State private var showingHabitCreation: Bool = false
    @State private var showingProfileCreation: Bool = false

    // MARK: - Initialization
    init(
        event: GalleryHistoryEvent,
        selectedTab: Binding<Int>,
        currentIndex: Int = 0,
        totalEvents: Int = 1,
        onPrevious: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {}
    ) {
        self.event = event
        self._selectedTab = selectedTab
        self.currentIndex = currentIndex
        self.totalEvents = totalEvents
        self.onPrevious = onPrevious
        self.onNext = onNext
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Invisible but interactive SharedHeaderSection (duplicates the one behind for touch events)
                SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
                    .environmentObject(appState)
                    .environmentObject(profileViewModel)
                    .environmentObject(dashboardViewModel)
                    .background(Color(hex: "f9f9f9")) // Match ContentView styling
                    .opacity(showBottomNavBar ? 0.01 : 0) // Starts at 0, becomes 0.01 after animation

                // Full-width white card extending to bottom of screen
                VStack(spacing: 0) {
                    // Navigation header with chevrons and date
                    navigationHeader
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24) // Increased vertical padding

                    // Scrollable content area that fills remaining space
                    ScrollView {
                        VStack(spacing: 0) {
                            // Square content area - full width like Instagram
                            contentSquare

                            // Bottom metadata info with padding
                            metadataInfo
                                .padding(.horizontal, 20)
                                .padding(.bottom, 120) // Space for floating navigation
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2)
                .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Match GalleryView alignment
                .frame(maxHeight: .infinity) // Extend to bottom
                .ignoresSafeArea(.container, edges: .bottom) // Extend past safe area to bottom edge
            }

            // Bottom navigation bar - appears after animation
            VStack {
                Spacer()
                StandardTabBar(
                    selectedTab: $selectedTab,
                    isCreateExpanded: $isCreateExpanded,
                    onCreateTapped: {
                        showingCreateActionSheet = true
                    }
                )
                .padding(.horizontal, UIScreen.main.bounds.width * 0.04) // Match white card inset above
                .opacity(showBottomNavBar ? 1 : 0) // Animate only the nav bar opacity
                .animation(.easeIn(duration: 0.2), value: showBottomNavBar)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom) // Prevent bottom safe area from compressing entire view
        .navigationBarHidden(true)
        .presentationDragIndicator(.hidden) // Hide the drag indicator
        .interactiveDismissDisabled(true) // Disable swipe-to-dismiss
        .overlay(
            // Wrapper with padding to match GalleryView base padding (4% screen width)
            CreateActionCard(
                isPresented: $showingCreateActionSheet,
                onCreateHabit: {
                    showingHabitCreation = true
                },
                onCreateProfile: {
                    showingProfileCreation = true
                }
            )
            .padding(.horizontal, UIScreen.main.bounds.width * 0.04)
        )
        .overlay(
            // Wrapper with padding to match GalleryView base padding (4% screen width)
            HabitCreationCard(
                isPresented: $showingHabitCreation,
                preselectedProfileId: nil, // No preselection in gallery detail
                onDismiss: {
                    showingHabitCreation = false
                }
            )
            .environmentObject(appState)
            .environmentObject(profileViewModel)
            .environmentObject(TaskViewModel(
                databaseService: container.resolve(DatabaseServiceProtocol.self),
                smsService: container.resolve(SMSServiceProtocol.self),
                authService: container.resolve(AuthenticationServiceProtocol.self),
                dataSyncCoordinator: container.resolve(DataSyncCoordinator.self)
            ))
            .padding(.horizontal, UIScreen.main.bounds.width * 0.04)
        )
        .overlay(
            // Wrapper with padding to match GalleryView base padding (4% screen width)
            ProfileCreationCard(
                isPresented: $showingProfileCreation,
                onDismiss: {
                    showingProfileCreation = false
                }
            )
            .environmentObject(appState)
            .environmentObject(profileViewModel)
            .padding(.horizontal, UIScreen.main.bounds.width * 0.04)
        )
        .onChange(of: showingCreateActionSheet) { oldValue, newValue in
            // Reset create button when action sheet is dismissed
            if !newValue {
                isCreateExpanded = false
            }
        }
        .onChange(of: showingHabitCreation) { oldValue, newValue in
            // Close create action sheet when habit creation opens
            if newValue {
                showingCreateActionSheet = false
            }
        }
        .onChange(of: showingProfileCreation) { oldValue, newValue in
            // Close create action sheet when profile creation opens
            if newValue {
                showingCreateActionSheet = false
            }
        }
        .onAppear {
            // Show bottom nav bar after animation completes (0.4s delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showBottomNavBar = true
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Dismiss the detail view whenever any tab is tapped
            presentationMode.wrappedValue.dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .galleryTabTapped)) { _ in
            // Dismiss when gallery tab is tapped (even if already on gallery)
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Navigation Header with Chevrons
    private var navigationHeader: some View {
        HStack {
            // Back button with chevron
            Button(action: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if hasPrevious {
                        onPrevious()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(.system(size: 16, weight: .light))
                }
                .foregroundColor(hasPrevious ? .gray : .gray.opacity(0.5))
            }
            
            Spacer()
            
            // Date in center
            Text(formatEventDate(event.createdAt))
                .font(AppFonts.poppinsMedium(size: 18))
                .foregroundColor(Color(hex: "595959"))
            
            Spacer()
            
            // Next button with chevron - always visible, disabled when not available
            Button(action: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if hasNext {
                        onNext()
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Text("Next")
                        .font(.system(size: 16, weight: .light))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(hasNext ? .gray : .gray.opacity(0.3))
            }
            .disabled(!hasNext)
        }
    }
    
    // MARK: - Content View (switches based on event type)
    @ViewBuilder
    private var contentView: some View {
        switch event.eventType {
        case .taskResponse:
            if event.hasPhoto {
                photoContentView
            } else {
                smsConversationView
            }
        case .profileCreated:
            profileCreatedView
        }
    }
    
    // MARK: - Square Content Area
    private var contentSquare: some View {
        VStack(spacing: 0) {
            contentView
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width) // True square
        .cornerRadius(8)
        .clipped()
    }
    
    // MARK: - Bottom Metadata Info
    private var metadataInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch event.eventType {
            case .taskResponse:
                VStack(alignment: .leading, spacing: 4) {
                    // Show "no reply" for events without a response, "task confirmed" otherwise
                    Text(event.hasTextResponse || event.hasPhoto ? "task confirmed" : "no reply")
                        .font(AppFonts.poppins(size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))

                    // Combined name and time with bullet separator
                    HStack(spacing: 0) {
                        Text(event.originalTaskTitle + " • " + formatEventTime(event.createdAt))
                            .font(AppFonts.poppinsMedium(size: 18))
                            .foregroundColor(.black)

                        Spacer()
                    }
                }
            case .profileCreated:
                VStack(alignment: .leading, spacing: 4) {
                    Text("profile created")
                        .font(AppFonts.poppins(size: 14))
                        .foregroundColor(Color(hex: "9f9f9f"))
                    
                    // Combined name and time with bullet separator
                    HStack(spacing: 0) {
                        Text(event.profileName + " • " + formatEventTime(event.createdAt))
                            .font(AppFonts.poppinsMedium(size: 18))
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Photo Content View
    private var photoContentView: some View {
        // Photo fills the entire content area
        Group {
            if let photoData = event.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(hex: "f0f0f0"))
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .overlay(
                        Text("Photo")
                            .font(AppFonts.poppins(size: 16))
                            .foregroundColor(Color(hex: "9f9f9f"))
                    )
            }
        }
    }
    
    // MARK: - SMS Conversation View
    private var smsConversationView: some View {
        VStack(spacing: 20) {

            // Conversation bubbles container
            VStack(spacing: 16) {

                // Outgoing message (what we sent) - right aligned, blue
                // Use actual sent message if available, otherwise reconstruct
                HStack {
                    Spacer(minLength: UIScreen.main.bounds.width * 0.2) // 20% left margin

                    SpeechBubbleView(
                        text: event.sentMessage ?? constructSentMessage(),
                        isOutgoing: true,
                        backgroundColor: Color(hex: "007AFF"), // iOS blue
                        textColor: .white
                    )
                }

                // Incoming message (their response) - left aligned, gray
                // Only show if there was an actual response (not for no-reply events)
                if let textResponse = event.textResponse, !textResponse.isEmpty {
                    HStack {
                        SpeechBubbleView(
                            text: textResponse,
                            isOutgoing: false,
                            backgroundColor: Color(hex: "E5E5EA"), // iOS gray
                            textColor: .black
                        )

                        Spacer(minLength: UIScreen.main.bounds.width * 0.2) // 20% right margin
                    }
                }

                // Reply message (thank you) - right aligned, blue
                if let replyMessage = event.replyMessage, !replyMessage.isEmpty {
                    HStack {
                        Spacer(minLength: UIScreen.main.bounds.width * 0.2) // 20% left margin

                        SpeechBubbleView(
                            text: replyMessage,
                            isOutgoing: true,
                            backgroundColor: Color(hex: "007AFF"), // iOS blue
                            textColor: .white
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16) // Add minimal padding for SMS chat bubbles
    }

    // MARK: - Helper: Construct Sent Message
    /// Reconstructs the sent message from the task title
    /// Matches the format used by TwilioSMSService.getTaskReminderMessage()
    private func constructSentMessage() -> String {
        let taskTitle = event.originalTaskTitle.isEmpty ? "task reminder" : event.originalTaskTitle

        // Match the template from TwilioSMSService.getTaskReminderMessage()
        // Format: "Hi [name]! Time to: [task]\n\nReply DONE when complete."
        return "Hi! Time to: \(taskTitle)\n\nReply DONE when complete."
    }
    
    // MARK: - Profile Created View
    private var profileCreatedView: some View {
        // Profile picture fills the entire content area like regular photos
        Group {
            if let photoURL = event.photoURL, !photoURL.isEmpty {
                // Try cache first to avoid AsyncImage flicker
                if let cachedImage = appState.imageCache.getCachedImage(for: photoURL) {
                    // Use cached image directly - synchronous, no placeholder
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                        .clipped()
                } else {
                    // Fallback to AsyncImage for first load or cache miss
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                            .clipped()
                    } placeholder: {
                        // Profile color background + initial letter during loading
                        Rectangle()
                            .fill(profileColor.opacity(0.3))
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                            .overlay(
                                Text(profileInitial)
                                    .font(.system(size: 80, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                }
            } else {
                // Initial letter fallback as full-size photo
                Rectangle()
                    .fill(profileColor) // Full opacity background
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .overlay(
                        Text(profileInitial)
                            .font(.system(size: 120, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var hasPhoto: Bool {
        if case .taskResponse(let data) = event.eventData {
            return data.photoData != nil
        }
        return false
    }
    
    private var profileColor: Color {
        let colors: [Color] = [
            Color(hex: "B9E3FF"),         // Blue
            Color.red,                    // Red
            Color.green,                  // Green
            Color.purple                  // Purple
        ]
        return colors[event.profileSlot % colors.count]
    }
    
    private var profileInitial: String {
        String(event.profileName.prefix(1)).uppercased()
    }

    // MARK: - Helper Functions
    
    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}


// MARK: - Preview Support
#if DEBUG
struct GalleryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Simple preview without complex mock data
        VStack(spacing: 20) {
            SpeechBubbleView(
                text: "Take your medication",
                isOutgoing: true,
                backgroundColor: Color(hex: "007AFF"),
                textColor: .white
            )
            
            SpeechBubbleView(
                text: "Done!",
                isOutgoing: false,
                backgroundColor: Color(hex: "E5E5EA"),
                textColor: .black
            )
        }
        .padding()
        .previewDisplayName("Speech Bubbles")
    }
}
#endif