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
    @Environment(\.scenePhase) private var scenePhase

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

    // MARK: - Centralized App Router
    // Single source of truth for navigation decisions
    // Replaces scattered auth/subscription checks across ContentView, OnboardingViewModel, OnboardingViews
    @StateObject private var appRouter: AppRouter = {
        let container = Container.shared
        return AppRouter(
            authService: container.resolve(AuthenticationServiceProtocol.self),
            databaseService: container.resolve(DatabaseServiceProtocol.self)
        )
    }()

    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var profileViewModel: ProfileViewModel?
    @State private var dashboardViewModel: DashboardViewModel?
    @State private var galleryViewModel: GalleryViewModel?
    @State private var authService: FirebaseAuthenticationService?
    @State private var selectedTab = 0
    @State private var selectedProfileIndex = 0  // Shared profile selection for header

    // Create action state (lifted from DashboardView for proper presentation context)
    @State private var showingCreateActionSheet = false
    @State private var showingDirectOnboarding = false
    @State private var showingTaskCreation = false
    @State private var isCreateExpanded = false

    @State private var authCancellables = Set<AnyCancellable>()

    // MARK: - Background/Foreground Refresh
    @State private var backgroundedAt: Date?
    @State private var showRefreshLoadingScreen: Bool = false
    private let refreshThresholdSeconds: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization
    init() {
        // ViewModels will be created in initializeViewModels to avoid crashes during init
    }

    var body: some View {
        ZStack {
            navigationContent
                .onAppear {
                    initializeViewModels()
                }
                .onChange(of: onboardingViewModel?.isComplete) { oldValue, newValue in
                    if let newValue = newValue {
                        handleOnboardingCompletion(newValue)
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }

        }
    }
    
    // MARK: - Navigation Content
    // ✅ ARCHITECTURE: Centralized routing via AppRouter
    // AppRouter determines destination based on: auth state, subscription status, quiz progress
    // Single source of truth replaces scattered if/else checks across multiple files
    @ViewBuilder
    private var navigationContent: some View {
        switch appRouter.destination {
        case .loading:
            // App is resolving where to route - show loading screen
            LoadingView()

        case .onboarding(let resumeStep):
            // User needs onboarding (not authenticated or has quiz progress)
            if let onboardingVM = onboardingViewModel {
                OnboardingContainerView()
                    .environmentObject(onboardingVM)
                    .environmentObject(appRouter)
                    .onAppear {
                        // If router specifies a resume step, set it
                        if let step = resumeStep {
                            onboardingVM.currentStep = step
                        }
                    }
            } else {
                LoadingView()
            }

        case .paywall:
            // User is authenticated but needs subscription
            if let onboardingVM = onboardingViewModel {
                OnboardingContainerView()
                    .environmentObject(onboardingVM)
                    .environmentObject(appRouter)
                    .onAppear {
                        // Route to paywall step
                        onboardingVM.currentStep = .step6Paywall
                    }
            } else {
                LoadingView()
            }

        case .dashboard:
            // User is fully entitled - show main app
            authenticatedContent
                .environmentObject(appState)
                .environmentObject(appRouter)
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        ZStack {
            mainAppFlow

            // Overlay loading screen when refreshing after returning from background
            if showRefreshLoadingScreen {
                LoadingView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showRefreshLoadingScreen)
    }
    
    
    // MARK: - Main App Flow
    private var mainAppFlow: some View {
        ZStack {
            // Background
            Color(hex: "f9f9f9")
                .ignoresSafeArea()

            if let dashboardVM = dashboardViewModel,
               let profileVM = profileViewModel {

                // Tab content - simple switch, no animations
                Group {
                    switch selectedTab {
                    case 0:
                        dashboardTabView(dashboardVM: dashboardVM, profileVM: profileVM)
                    case 1:
                        galleryTabView(profileVM: profileVM, dashboardVM: dashboardVM)
                    case 2:
                        habitsTabView(dashboardVM: dashboardVM, profileVM: profileVM)
                    default:
                        dashboardTabView(dashboardVM: dashboardVM, profileVM: profileVM)
                    }
                }

                // Static chrome (header + nav)
                VStack(spacing: 0) {
                    // Header at top (profile circles + Remi logo + settings)
                    SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)
                        .environmentObject(dashboardVM)
                        .environmentObject(profileVM)
                        .environmentObject(appState)

                    Spacer()

                    // Standard iOS-style tab bar at bottom
                    StandardTabBar(
                        selectedTab: $selectedTab,
                        isCreateExpanded: $isCreateExpanded,
                        onCreateTapped: { showingCreateActionSheet = true }
                    )
                }
                .ignoresSafeArea(.all, edges: .bottom)

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

    // MARK: - Tab View Helpers
    /// Dashboard tab with all environment objects and modifiers
    @ViewBuilder
    private func dashboardTabView(dashboardVM: DashboardViewModel, profileVM: ProfileViewModel) -> some View {
        DashboardView(
            selectedTab: $selectedTab,
            showHeader: false,
            showingCreateActionSheet: $showingCreateActionSheet,
            showingDirectOnboarding: $showingDirectOnboarding,
            showingTaskCreation: $showingTaskCreation
        )
        .environmentObject(dashboardVM)
        .environmentObject(profileVM)
        .environmentObject(appState)
        .id("dashboard-\(appState.currentUser?.uid ?? "no-user")")
    }

    /// Gallery tab with all environment objects and modifiers
    @ViewBuilder
    private func galleryTabView(profileVM: ProfileViewModel, dashboardVM: DashboardViewModel) -> some View {
        GalleryView(selectedTab: $selectedTab, showingCreateActionSheet: $showingCreateActionSheet, showHeader: false)
            .environmentObject(profileVM)
            .environmentObject(dashboardVM)
            .environmentObject(appState)
            .id("gallery-\(appState.currentUser?.uid ?? "no-user")")
    }

    /// Habits tab with all environment objects and modifiers
    @ViewBuilder
    private func habitsTabView(dashboardVM: DashboardViewModel, profileVM: ProfileViewModel) -> some View {
        HabitsView(selectedTab: $selectedTab, showingCreateActionSheet: $showingCreateActionSheet, showHeader: false)
            .environmentObject(dashboardVM)
            .environmentObject(profileVM)
            .environmentObject(appState)
            .id("habits-\(appState.currentUser?.uid ?? "no-user")")
    }
    
    // MARK: - Initialization Methods
    @MainActor
    private func initializeViewModels() {
        // Only initialize once - prevent recreating ViewModels on every render
        guard profileViewModel == nil else {
            return
        }

        // AppState is now initialized as @StateObject at declaration time

        // Create ViewModels using Container (all factory methods are @MainActor)
        onboardingViewModel = container.makeOnboardingViewModel()

        // Inject AppRouter into OnboardingViewModel for centralized exit handling
        onboardingViewModel?.setAppRouter(appRouter)

        profileViewModel = container.makeProfileViewModel()

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

        // ✅ CENTRALIZED ROUTING: Let AppRouter determine initial destination
        // This replaces scattered auth/subscription checks with a single orchestration point
        _Concurrency.Task {
            // Resolve destination (handles auth check, subscription check, quiz progress)
            await appRouter.resolveDestination()

            // If user is authenticated, load their data
            if authService?.isAuthenticated == true {
                await appState.loadUserData()

                // Restore any missing photoURL references from Storage
                await self.profileViewModel?.restoreMissingProfilePhotos()

                // Re-populate the duplicate prevention Set AFTER data is loaded
                await MainActor.run {
                    self.profileViewModel?.populateGalleryEventTrackingSet(from: appState.galleryEvents)
                }
            }
        }
    }

    private func setupAuthStateObserver() {
        guard let authService = authService else { return }

        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { newAuthState in
                if newAuthState {
                    // User logged in - setup Firebase listeners and load data
                    let dataSyncCoordinator = self.container.resolve(DataSyncCoordinator.self)

                    // ✅ FIX: Setup Firebase listeners on mid-session login
                    // This fixes the race condition where listeners weren't initialized
                    // when user logs in from the Welcome page (vs app launch)
                    if let userId = authService.currentUser?.uid {
                        dataSyncCoordinator.setupFirebaseListeners(userId: userId)
                    }

                    _Concurrency.Task { @MainActor in
                        // Sync RevenueCat + Superwall identity with Firebase user
                        // Ensures purchases and paywall targeting are linked correctly
                        if let userId = authService.currentUser?.uid {
                            await self.syncSubscriptionSDKIdentities(userId: userId)
                        }

                        // ✅ FIX: Store any FCM token that arrived before user logged in
                        await AppDelegate.storePendingFCMTokenIfNeeded()

                        await self.appState.loadUserData()

                        // Restore any missing photoURL references from Storage
                        await self.profileViewModel?.restoreMissingProfilePhotos()

                        // Refresh expired photo URLs with fresh download tokens
                        await self.profileViewModel?.refreshProfilePhotoURLs()

                        // Re-populate the duplicate prevention Set AFTER data is loaded
                        self.profileViewModel?.populateGalleryEventTrackingSet(from: self.appState.galleryEvents)

                        // ✅ CENTRALIZED ROUTING: Re-resolve destination after auth change
                        await self.appRouter.handleAuthStateChange(isAuthenticated: true)
                    }

                    // Keep existing ViewModel loads temporarily (Phase 2 will remove)
                    self.profileViewModel?.loadProfiles()
                } else {
                    // User logged out - reset all state and stop listeners
                    let dataSyncCoordinator = self.container.resolve(DataSyncCoordinator.self)
                    dataSyncCoordinator.stopFirebaseListeners()

                    // Reset RevenueCat + Superwall to anonymous user
                    _Concurrency.Task {
                        await self.resetSubscriptionSDKIdentities()
                    }

                    // Reset AppState (clears data + stops listeners)
                    self.appState.reset()

                    // Reset selected tab to home
                    self.selectedTab = 0
                    self.selectedProfileIndex = 0

                    // ✅ FIX: Reset OnboardingViewModel to prevent paywall from appearing
                    // Without this, currentStep may still be .step6Paywall from the previous
                    // session, causing PaywallStepView to render and trigger Superwall
                    self.onboardingViewModel?.currentStep = .welcome

                    // ✅ CENTRALIZED ROUTING: Notify router of logout
                    self.appRouter.handleLogout()
                }
            }
            .store(in: &authCancellables)
    }

    // MARK: - Subscription SDK Identity Management

    /// Syncs RevenueCat and Superwall customer identity with Firebase user ID
    /// Called on login to ensure purchases and paywall targeting are linked correctly
    private func syncSubscriptionSDKIdentities(userId: String) async {
        // Sync RevenueCat identity for purchase attribution and cross-device restore
        let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
        do {
            try await subscriptionService.identify(userId: userId)
        } catch {
            // Non-fatal: RevenueCat will continue with anonymous ID
            print("⚠️ [RevenueCat] Failed to sync user identity: \(error.localizedDescription)")
        }

        // Sync Superwall identity for paywall targeting and analytics
        // This ensures A/B tests and targeting rules are consistent per user
        await MainActor.run {
            Superwall.shared.identify(userId: userId)
        }
    }

    /// Resets RevenueCat and Superwall to anonymous user on logout
    /// Prevents the next user from inheriting previous user's subscription/targeting state
    private func resetSubscriptionSDKIdentities() async {
        // Reset RevenueCat identity
        let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
        do {
            try await subscriptionService.logout()
        } catch {
            // Non-fatal: Will be reset on next app launch
            print("⚠️ [RevenueCat] Failed to reset identity on logout: \(error.localizedDescription)")
        }

        // Reset Superwall identity
        await MainActor.run {
            Superwall.shared.reset()
        }
    }

    // TEMPORARY: Safe TaskViewModel creation with detailed debugging
    private func safeTaskViewModel() -> TaskViewModel? {
        let dbService = container.resolve(DatabaseServiceProtocol.self)
        let smsService = container.resolve(SMSServiceProtocol.self)
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)

        let viewModel = TaskViewModel(
            databaseService: dbService,
            smsService: smsService,
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
            // User completed onboarding flow (either via quiz or direct login)
            // Reset tab selection to Dashboard
            selectedTab = 0
        }
    }

    /// Handle app backgrounding/foregrounding - refresh data if away 5+ minutes
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            backgroundedAt = Date()
        case .inactive:
            break
        case .active:
            defer { backgroundedAt = nil }
            guard authService?.isAuthenticated == true,
                  let backgrounded = backgroundedAt,
                  Date().timeIntervalSince(backgrounded) >= refreshThresholdSeconds else { return }

            showRefreshLoadingScreen = true
            _Concurrency.Task {
                async let refresh: Void = appState.refreshUserData()
                async let delay: Void = { try? await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000) }()
                _ = await (refresh, delay)
                await MainActor.run {
                    self.profileViewModel?.populateGalleryEventTrackingSet(from: appState.galleryEvents)
                    showRefreshLoadingScreen = false
                }
            }
        @unknown default:
            break
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
    var body: some View {
        VStack(spacing: 20) {
            // Remi logo image - static, no animation
            Image("Remi Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120)

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "f9f9f9")) // Same background as app to prevent black flash
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

