import SwiftUI
import Combine
import SuperwallKit
import Firebase
import UserNotifications

// MARK: - Environment Keys
private struct IsScrollDisabledKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct IsDraggingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isScrollDisabled: Bool {
        get { self[IsScrollDisabledKey.self] }
        set { self[IsScrollDisabledKey.self] = newValue }
    }

    var isDragging: Bool {
        get { self[IsDraggingKey.self] }
        set { self[IsDraggingKey.self] = newValue }
    }
}

struct ContentView: View {
    // MARK: - Environment
    @Environment(\.container) private var container

    // MARK: - State Management
    // Phase 1: READ-ONLY AppState integration (keeping existing ViewModels temporarily)
    // FIXED: Use @StateObject to subscribe to @Published properties for UI updates
    @StateObject private var appState: AppState = {
        let container = Container.shared
        return AppState(
            authService: container.resolve(AuthenticationServiceProtocol.self),
            databaseService: container.resolve(DatabaseServiceProtocol.self),
            dataSyncCoordinator: container.resolve(DataSyncCoordinator.self),
            imageCache: container.resolve(ImageCacheService.self)
        )
    }()

    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var profileViewModel: ProfileViewModel?
    @State private var dashboardViewModel: DashboardViewModel?
    @State private var galleryViewModel: GalleryViewModel?
    @State private var authService: FirebaseAuthenticationService?
    @State private var isAuthenticated = false  // Temporary - will be removed in Phase 4
    @State private var selectedTab = 0
    @State private var previousTab = 0  // Track previous tab for Habits (middle) transition direction
    @State private var transitionDirection: Int = 1  // Unused - kept for backward compatibility with bindings
    @State private var selectedProfileIndex = 0  // Shared profile selection for header
    @State private var isTransitioning = false  // Lock to prevent animation overlap during rapid tab switches
    @GestureState private var dragOffset: CGFloat = 0  // Real-time drag tracking for interactive swipe
    @State private var isHorizontalDragging = false  // Track if user is actively horizontal swiping
    @State private var horizontalGestureMomentum = false  // Prioritize horizontal after recent tab switch

    // Create action state (lifted from DashboardView for proper presentation context)
    @State private var showingCreateActionSheet = false
    @State private var showingDirectOnboarding = false
    @State private var showingTaskCreation = false // NEW: For habit creation card
    @State private var isCreateExpanded = false // Track create button toggle state

    @State private var authCancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Controls whether tab swiping is enabled
    /// Disabled on HabitsView (tab 2) to prevent conflict with swipe-to-delete gestures
    /// Also restricted to only Dashboard ↔ Gallery (tabs 0-1)
    private var allowsTabSwiping: Bool {
        selectedTab != 2  // Disable on Habits tab (index 2)
    }

    /// Controls which tab transitions are allowed
    /// Only allows swiping between Dashboard (0) and Gallery (1)
    private func isValidTabTransition(from currentTab: Int, to newTab: Int) -> Bool {
        // Only allow transitions between tabs 0 and 1 (Dashboard ↔ Gallery)
        let validTabs = Set([0, 1])
        return validTabs.contains(currentTab) && validTabs.contains(newTab)
    }

    // MARK: - Initialization
    init() {
        // ViewModels will be created in initializeViewModels to avoid crashes during init
    }

    var body: some View {
        navigationContent
            .onAppear {
                initializeViewModels()
            }
            .onChange(of: onboardingViewModel?.isComplete) { oldValue, newValue in
                if let newValue = newValue {
                    handleOnboardingCompletion(newValue)
                }
            }
    }
    
    // MARK: - Navigation Content
    @ViewBuilder
    private var navigationContent: some View {
        if onboardingViewModel != nil {
            if isAuthenticated {
                authenticatedContent
            } else {
                LoginView(onAuthenticationSuccess: {
                    // Auth state will be updated by the listener automatically
                    // Just reload profiles when ready
                    profileViewModel?.loadProfiles()
                })
                .environmentObject(onboardingViewModel!)
            }
        } else {
            LoadingView()
        }
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        mainAppFlow
    }
    
    
    // MARK: - Main App Flow
    private var mainAppFlow: some View {
        // Layered architecture: static chrome + animated content
        ZStack {
            // LAYER 0: Background (static, never animates)
            Color(hex: "f9f9f9")
                .ignoresSafeArea()

            // LAYER 1-10: Transitioning content (animated with asymmetric slide)
            if let dashboardVM = dashboardViewModel,
               let profileVM = profileViewModel,
               let galleryVM = galleryViewModel {

                ZStack {
                    // Dashboard Tab - Home screen (content only) - LEFTMOST
                    DashboardView(
                        selectedTab: $selectedTab,
                        showHeader: false,
                        showingCreateActionSheet: $showingCreateActionSheet,
                        showingDirectOnboarding: $showingDirectOnboarding,
                        showingTaskCreation: $showingTaskCreation
                    )
                        .environmentObject(dashboardVM)
                        .environmentObject(profileVM)
                        .environmentObject(appState)  // PHASE 1: Inject AppState for read-only access
                        .environment(\.isScrollDisabled, isHorizontalDragging)
                        .environment(\.isDragging, dragOffset != 0)
                        .offset(x: tabOffset(for: 0))
                        .zIndex(selectedTab == 0 ? 1 : 0)
                        .id("dashboard-\(appState.currentUser?.id ?? "no-user")") // Force recreation on login/logout

                    // Gallery Tab - Archive of completed habits with photos (content only) - MIDDLE
                    GalleryView(selectedTab: $selectedTab, showHeader: false)
                        .environmentObject(galleryVM) // Use real Firebase services!
                        .environmentObject(profileVM)
                        .environmentObject(dashboardVM) // Needed for GalleryDetailView
                        .environmentObject(appState)  // PHASE 1: Inject AppState for read-only access
                        .environment(\.isScrollDisabled, isHorizontalDragging)
                        .environment(\.isDragging, dragOffset != 0)
                        .offset(x: tabOffset(for: 1))
                        .zIndex(selectedTab == 1 ? 1 : 0)
                        .id("gallery-\(appState.currentUser?.id ?? "no-user")") // Force recreation on login/logout

                    // Habits Tab - Habit management screen (content only) - RIGHTMOST
                    HabitsView(selectedTab: $selectedTab, showHeader: false)
                        .environmentObject(dashboardVM) // Share same instance for real-time data sync
                        .environmentObject(profileVM)
                        .environmentObject(appState)  // PHASE 1: Inject AppState for read-only access
                        .environment(\.isScrollDisabled, isHorizontalDragging)
                        .environment(\.isDragging, dragOffset != 0)
                        .offset(x: tabOffset(for: 2))
                        .zIndex(selectedTab == 2 ? 1 : 0)
                        .id("habits-\(appState.currentUser?.id ?? "no-user")") // Force recreation on login/logout
}
                .onChange(of: selectedTab) { oldValue, newValue in
                    // Lock transitions
                    isTransitioning = true

                    // Enable horizontal gesture momentum for next 0.8 seconds (increased from 0.6s)
                    horizontalGestureMomentum = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        horizontalGestureMomentum = false
                    }

                    // Update previousTab for Habits transition direction
                    previousTab = oldValue

                    // Unlock quickly - just enough to prevent double-taps (150ms)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isTransitioning = false
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85), value: dragOffset)
                .gesture(
                    allowsTabSwiping ? DragGesture(minimumDistance: 20)
                        .updating($dragOffset) { value, state, _ in
                            // Prevent drag during animation
                            guard !isTransitioning else { return }

                            // Only enable horizontal swipe if gesture is more horizontal than vertical
                            let horizontalDistance = abs(value.translation.width)
                            let verticalDistance = abs(value.translation.height)

                            // GESTURE PRIORITY SYSTEM:
                            // - Momentum mode (0.8s after tab switch): Horizontal EXTREMELY favored (vertical must be 6x more)
                            // - Normal mode: Horizontal very strongly favored (vertical must be 3.5x more)
                            let verticalThreshold: CGFloat = horizontalGestureMomentum ? 6.0 : 3.5

                            // Horizontal wins unless vertical is significantly more
                            guard verticalDistance < horizontalDistance * verticalThreshold else { return }

                            // Prevent swiping beyond boundaries and to disabled tabs
                            let swipeDirection = value.translation.width > 0 ? "right" : "left"
                            if selectedTab == 0 && swipeDirection == "right" {
                                // Can't swipe right from Dashboard (leftmost)
                                return
                            }
                            if selectedTab == 1 && swipeDirection == "left" {
                                // Can't swipe left from Gallery (Habits navigation disabled)
                                return
                            }
                            if selectedTab == 2 && swipeDirection == "left" {
                                // Can't swipe left from Habits (rightmost)
                                return
                            }

                            // Mark that horizontal dragging is active (disables vertical scroll)
                            if !isHorizontalDragging {
                                isHorizontalDragging = true
                            }

                            // Update drag offset in real-time for interactive scrubbing
                            state = value.translation.width
                        }
                        .onEnded { value in
                            // Prevent tab change during animation
                            guard !isTransitioning else {
                                // Re-enable vertical scrolling if blocked during animation
                                isHorizontalDragging = false
                                return
                            }

                            let horizontalDistance = value.translation.width
                            let verticalDistance = abs(value.translation.height)
                            let velocity = value.predictedEndTranslation.width - value.translation.width

                            // Use same momentum-aware threshold as .updating
                            let verticalThreshold: CGFloat = horizontalGestureMomentum ? 6.0 : 3.5
                            guard verticalDistance < abs(horizontalDistance) * verticalThreshold else { return }

                            // Calculate if swipe should trigger tab change
                            // Fast swipe: Very low threshold - even moderate-speed swipes trigger
                            // Slow swipe: Only truly lazy swipes need to drag the full distance
                            let fastVelocityThreshold: CGFloat = 100  // Super low - most swipes are "fast"
                            let slowDistanceThreshold: CGFloat = 120  // Only lazy swipes hit this

                            let isFastSwipe = abs(velocity) > fastVelocityThreshold
                            let isSlowDrag = abs(horizontalDistance) > slowDistanceThreshold

                            let shouldChangeTab = isFastSwipe || isSlowDrag

                            // Swipe left = move forward (next tab)
                            if horizontalDistance < 0 && shouldChangeTab {
                                if selectedTab < 2 {
                                    let newTab = selectedTab + 1
                                    // Only allow transition if valid (Dashboard ↔ Gallery only)
                                    if isValidTabTransition(from: selectedTab, to: newTab) {
                                        previousTab = selectedTab
                                        selectedTab = newTab

                                        // Delay re-enabling vertical scroll briefly (200ms)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                                            isHorizontalDragging = false
                                        }
                                    } else {
                                        // Invalid transition, re-enable immediately
                                        isHorizontalDragging = false
                                    }
                                } else {
                                    // No tab change, re-enable immediately
                                    isHorizontalDragging = false
                                }
                            }
                            // Swipe right = move backward (previous tab)
                            else if horizontalDistance > 0 && shouldChangeTab {
                                if selectedTab > 0 {
                                    let newTab = selectedTab - 1
                                    // Only allow transition if valid (Dashboard ↔ Gallery only)
                                    if isValidTabTransition(from: selectedTab, to: newTab) {
                                        previousTab = selectedTab
                                        selectedTab = newTab

                                        // Delay re-enabling vertical scroll briefly (200ms)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                                            isHorizontalDragging = false
                                        }
                                    } else {
                                        // Invalid transition, re-enable immediately
                                        isHorizontalDragging = false
                                    }
                                } else {
                                    // No tab change, re-enable immediately
                                    isHorizontalDragging = false
                                }
                            }
                            // If didn't meet threshold, snap back - re-enable scroll immediately
                            else {
                                isHorizontalDragging = false
                            }
                        }
                    : nil  // No gesture on Habits tab - allows swipe-to-delete to work without conflict
                )

                // LAYER 100: Static chrome (header + nav, never animates)
                VStack(spacing: 0) {
                    // Header at top (profile circles + Remi logo + settings)
                    SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
                        .environmentObject(dashboardVM)
                        .environmentObject(profileVM)
                        .environmentObject(appState)  // FIXED: Inject AppState
                        .background(Color(hex: "f9f9f9").opacity(0)) // Transparent background

                    Spacer()

                    // Standard iOS-style tab bar at bottom
                    StandardTabBar(
                        selectedTab: $selectedTab,
                        isCreateExpanded: $isCreateExpanded,
                        onCreateTapped: { showingCreateActionSheet = true }
                    )
                }
                .ignoresSafeArea(.all, edges: .bottom) // Extend VStack to screen bottom
                .zIndex(100) // Always on top

            } else {
                // Loading state while ViewModel is being created
                LoadingView()
            }
        }
        .overlay(
            CreateActionCard(
                isPresented: $showingCreateActionSheet,
                onCreateHabit: {
                    showingTaskCreation = true
                },
                onCreateProfile: {
                    if let profileVM = profileViewModel {
                        profileVM.startProfileOnboarding()
                        showingDirectOnboarding = true
                    }
                }
            )
            .environmentObject(appState)
        )
        .onChange(of: showingCreateActionSheet) { oldValue, newValue in
            // Reset create button when action sheet is dismissed
            if !newValue {
                isCreateExpanded = false
            }
        }
        .overlay(
            // Profile Creation Card (replaces full-screen SimplifiedProfileCreationView)
            Group {
                if let profileVM = profileViewModel {
                    ProfileCreationCard(
                        isPresented: $showingDirectOnboarding,
                        onDismiss: {
                            showingDirectOnboarding = false
                        }
                    )
                    .environmentObject(appState)
                    .environmentObject(profileVM)
                }
            }
        )
        .overlay(
            // NEW: Habit Creation Card (replaces full-screen TaskCreationViewWrapper)
            Group {
                if let dashboardVM = dashboardViewModel, let profileVM = profileViewModel {
                    HabitCreationCardWrapper(
                        isPresented: $showingTaskCreation,
                        preselectedProfileId: dashboardVM.selectedProfileId,
                        container: container,
                        appState: appState,
                        profileVM: profileVM
                    )
                }
            }
        )
        .onChange(of: showingTaskCreation) { oldValue, newValue in
            // Reset create button when habit card is dismissed
            if !newValue {
                isCreateExpanded = false
            }
        }
    }

    // MARK: - Create Button (for Dashboard only)
    private var createHabitButton: some View {
        Button(action: {
            // Haptic feedback for create action
            HapticFeedback.medium()

            showingCreateActionSheet = true
        }) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 57.25, height: 57.25)
                    .shadow(color: Color(hex: "6f6f6f").opacity(0.15), radius: 4, x: 0, y: 2)

                Image(systemName: "plus")
                    .font(.system(size: 26.11, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Offset Helper
    /// Calculates horizontal offset for each tab based on position and drag state
    /// Dashboard (0) = LEFT, Habits (1) = MIDDLE, Gallery (2) = RIGHT
    private func tabOffset(for tab: Int) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width

        // Base position offset (where tab lives when selected)
        let baseOffset = CGFloat(tab - selectedTab) * screenWidth

        // Add interactive drag offset
        return baseOffset + dragOffset
    }
    
    // MARK: - Initialization Methods
    @MainActor
    private func initializeViewModels() {
        print("🔵 [ContentView] initializeViewModels() CALLED")

        // Only initialize once - prevent recreating ViewModels on every render
        guard profileViewModel == nil else {
            print("⚠️ [ContentView] ViewModels already initialized - skipping")
            return
        }

        print("🔵 [ContentView] Initializing ViewModels for FIRST TIME...")

        // AppState is now initialized as @StateObject at declaration time
        print("✅ [ContentView] AppState already initialized as @StateObject")

        // Create ViewModels using Container (all factory methods are @MainActor)
        onboardingViewModel = container.makeOnboardingViewModel()
        profileViewModel = container.makeProfileViewModel()

        print("✅ [ContentView] ProfileViewModel created")

        // PHASE 2: Inject AppState into ProfileViewModel for write consolidation
        profileViewModel?.setAppState(appState)

        // Load profiles after ViewModel is fully initialized
        profileViewModel?.loadProfiles()

        dashboardViewModel = container.makeDashboardViewModel()
        galleryViewModel = container.makeGalleryViewModel()

        // PHASE 4: Inject AppState into DashboardViewModel
        dashboardViewModel?.setAppState(appState)

        // Store auth service reference (singleton)
        authService = container.resolve(AuthenticationServiceProtocol.self) as? FirebaseAuthenticationService

        // Subscribe to auth state changes
        setupAuthStateObserver()

        // Check if user is already authenticated on app launch
        _Concurrency.Task {
            // Small delay to ensure Firebase Auth is ready
            try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            await MainActor.run {
                print("🔵 [ContentView] Checking auth on launch...")
                if authService?.isAuthenticated == true {
                    print("✅ [ContentView] User is authenticated on launch")
                    isAuthenticated = true
                    // Load all user data and setup real-time listeners
                    _Concurrency.Task {
                        print("🔵 [ContentView] Calling appState.loadUserData()...")
                        await appState.loadUserData()

                        // Restore any missing photoURL references from Storage
                        print("🔍 [ContentView] Checking for missing profile photos...")
                        await self.profileViewModel?.restoreMissingProfilePhotos()

                        // DEBUG: Check and clear pending notifications
                        await self.debugAndClearNotifications()

                        // CRITICAL: Re-populate the duplicate prevention Set AFTER data is loaded
                        // This prevents duplicate gallery events when SMS listener replays old confirmations
                        await MainActor.run {
                            print("🔵 [ContentView] Re-populating gallery event tracking set after data load...")
                            self.profileViewModel?.populateGalleryEventTrackingSet(from: appState.galleryEvents)
                        }
                    }
                } else {
                    print("⚠️ [ContentView] User is NOT authenticated on launch")
                    isAuthenticated = false
                }
            }
        }
    }

    /// Debug function to check and clear all pending/delivered notifications
    /// This helps identify if notifications are being scheduled despite local notifications being disabled
    private func debugAndClearNotifications() async {
        let center = UNUserNotificationCenter.current()

        // Check pending notifications (scheduled but not delivered)
        let pending = await center.pendingNotificationRequests()
        print("📱 [Notifications] Pending notifications: \(pending.count)")
        for request in pending {
            print("  - ID: \(request.identifier)")
            print("    Title: \(request.content.title)")
            print("    Body: \(request.content.body)")
            if let trigger = request.trigger {
                print("    Trigger: \(trigger)")
            }
        }

        // Check delivered notifications (already shown to user)
        let delivered = await center.deliveredNotifications()
        print("📱 [Notifications] Delivered notifications: \(delivered.count)")
        for notification in delivered {
            print("  - ID: \(notification.request.identifier)")
            print("    Title: \(notification.request.content.title)")
            print("    Body: \(notification.request.content.body)")
        }

        // Clear ALL notifications (both pending and delivered)
        await center.removeAllPendingNotificationRequests()
        await center.removeAllDeliveredNotifications()
        print("✅ [Notifications] Cleared all pending and delivered notifications")
    }

    private func setupAuthStateObserver() {
        guard let authService = authService else { return }

        // Subscribe to auth state publisher
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak authService] newAuthState in
                self.isAuthenticated = newAuthState

                if newAuthState {
                    // User logged in - load data and setup listeners
                    print("✅ [ContentView] User logged in - loading data and setting up listeners")

                    // PHASE 1: Load data into AppState (single source of truth)
                    _Concurrency.Task { @MainActor in
                        await self.appState.loadUserData()

                        // Restore any missing photoURL references from Storage
                        print("🔍 [ContentView] Checking for missing profile photos...")
                        await self.profileViewModel?.restoreMissingProfilePhotos()

                        // Refresh expired photo URLs with fresh download tokens
                        print("🔄 [ContentView] Refreshing profile photo URLs...")
                        await self.profileViewModel?.refreshProfilePhotoURLs()

                        // CRITICAL: Re-populate the duplicate prevention Set AFTER data is loaded
                        // This prevents duplicate gallery events when SMS listener replays old confirmations
                        self.profileViewModel?.populateGalleryEventTrackingSet(from: self.appState.galleryEvents)
                    }

                    // Keep existing ViewModel loads temporarily (Phase 2 will remove)
                    self.profileViewModel?.loadProfiles()
                } else {
                    // User logged out - reset all state and stop listeners
                    print("🛑 [ContentView] User logged out - resetting state and stopping listeners")

                    // Reset AppState (clears data + stops listeners)
                    self.appState.reset()

                    // Reset selected tab to home
                    self.selectedTab = 0
                    self.selectedProfileIndex = 0
                }
            }
            .store(in: &authCancellables)
    }

    // TEMPORARY: Safe TaskViewModel creation with detailed debugging
    private func safeTaskViewModel() -> TaskViewModel? {
        let dbService = container.resolve(DatabaseServiceProtocol.self)
        let smsService = container.resolve(SMSServiceProtocol.self)
        let notificationService = container.resolve(NotificationServiceProtocol.self)
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)

        let viewModel = TaskViewModel(
            databaseService: dbService,
            smsService: smsService,
            notificationService: notificationService,
            authService: authService,
            dataSyncCoordinator: dataSyncCoordinator
        )

        // PHASE 2: Inject AppState into TaskViewModel for write consolidation
        viewModel.setAppState(appState)

        return viewModel
    }
    
    // MARK: - Event Handlers
    private func handleOnboardingCompletion(_ isComplete: Bool) {
        if isComplete {
            // User completed onboarding, reset tab selection
            selectedTab = 0
        }
    }
    
    
    // MARK: - UI Configuration
    // TabBar hiding functions no longer needed since we removed TabView completely
    // Keeping empty functions to avoid breaking any remaining references
    private func hideTabBarCompletely() {
        // No longer needed - TabView removed
    }
    
    private func configureTabBarAppearance() {
        // No longer needed - TabView removed
    }
}

// MARK: - Authentication States
enum AuthenticationState {
    case loading
    case authenticated
    case unauthenticated
}

// PHASE 4: REMOVED AuthenticationViewModel (dead code - never instantiated)
// Authentication is now handled by AppState.currentUser and isAuthenticated @State
// ContentView subscribes to authService.authStatePublisher directly

// MARK: - Loading View
struct LoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            // Remi logo with animation
            Text("Remi")
                .font(.system(size: 60, weight: .medium))
                .tracking(-3.0)
                .foregroundColor(.black)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text("Make sure your loved one never misses another reminder")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "7A7A7A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .tracking(-0.3)

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "f9f9f9")) // Same background as app to prevent black flash
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // ISOLATED CANVAS TESTS - NO SERVICES OR DEPENDENCIES
            
            // Test LoadingView independently
            LoadingView()
                .previewDisplayName("Loading View")
            
            // Test simple tab structure without ViewModels
            TabView {
                Text("Home Tab - Canvas Test")
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                Text("Gallery Tab - Canvas Test") 
                    .tabItem {
                        Image(systemName: "photo.on.rectangle")
                        Text("Gallery")
                    }
                    .tag(1)
            }
            .previewDisplayName("Tab Structure Test")
            
            // Test basic UI elements
            VStack(spacing: 20) {
                Text("Hallo")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Text("Canvas UI Test")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Test Button") {
                    // No action needed for Canvas
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .previewDisplayName("Basic UI Elements")
        }
    }
}
#endif

// MARK: - Task Creation Wrapper (OLD - DEPRECATED, keeping for reference)
private struct TaskCreationViewWrapper: View {
    let container: Container
    let appState: AppState
    let preselectedProfileId: String?
    let profileVM: ProfileViewModel
    let dismissAction: () -> Void

    @StateObject private var taskVM: TaskViewModel

    init(container: Container, appState: AppState, preselectedProfileId: String?, profileVM: ProfileViewModel, dismissAction: @escaping () -> Void) {
        self.container = container
        self.appState = appState
        self.preselectedProfileId = preselectedProfileId
        self.profileVM = profileVM
        self.dismissAction = dismissAction

        let vm = container.makeTaskViewModel()
        vm.setAppState(appState)
        _taskVM = StateObject(wrappedValue: vm)
    }

    var body: some View {
        TaskCreationView(
            preselectedProfileId: preselectedProfileId,
            dismissAction: dismissAction
        )
        .environmentObject(taskVM)
        .environmentObject(profileVM)
        .environmentObject(appState)
    }
}

// MARK: - Habit Creation Card Wrapper
private struct HabitCreationCardWrapper: View {
    @Binding var isPresented: Bool
    let preselectedProfileId: String?
    let container: Container
    let appState: AppState
    let profileVM: ProfileViewModel

    @StateObject private var taskVM: TaskViewModel

    init(isPresented: Binding<Bool>, preselectedProfileId: String?, container: Container, appState: AppState, profileVM: ProfileViewModel) {
        self._isPresented = isPresented
        self.preselectedProfileId = preselectedProfileId
        self.container = container
        self.appState = appState
        self.profileVM = profileVM

        let vm = container.makeTaskViewModel()
        vm.setAppState(appState)
        _taskVM = StateObject(wrappedValue: vm)
    }

    var body: some View {
        HabitCreationCard(
            isPresented: $isPresented,
            preselectedProfileId: preselectedProfileId,
            onDismiss: {
                isPresented = false
            }
        )
        .environmentObject(appState)
        .environmentObject(profileVM)
        .environmentObject(taskVM)
    }
}

