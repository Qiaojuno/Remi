import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SuperwallKit
import GoogleSignIn

// MARK: - App Delegate for Orientation Control
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

@main
struct HalloApp: App {
    // MARK: - App Delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - Dependencies
    private let container: Container
    
    // MARK: - App Lifecycle
    init() {
        // Skip heavy initialization during Canvas/Preview execution
        if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            // Configure Firebase FIRST, before Container initialization
            HalloApp.configureFirebase()
            print("✅ Firebase configuration completed successfully")
        }

        // Initialize Container AFTER Firebase is configured
        container = Container.shared
        print("✅ Container initialized successfully")

        // Configure other services after container is initialized
        if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            configureNotifications()
            configureSuperwall()
            configureGoogleSignIn()
        }

        configureAppearance()
        print("✅ App initialization completed")
    }
    
    private static func configureFirebase() {
        print("🔥 Starting Firebase configuration...")

        // Simple Firebase configuration
        FirebaseApp.configure()
        print("✅ Firebase configured")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .inject(container: container)
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    // Skip app launch handling during Canvas/Preview execution
                    if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
                        handleAppLaunch()
                    }

                    // Force portrait orientation and lock it
                    AppDelegate.orientationLock = .portrait
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    handleAppWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    handleAppDidEnterBackground()
                }
        }
    }
    
    // MARK: - Configuration
    
    private func configureNotifications() {
        _Concurrency.Task {
            await requestNotificationPermissions()
        }
    }
    
    private func configureSuperwall() {
        // Superwall API key from dashboard
        let SUPERWALL_API_KEY = "pk_1FZVcGgpr1JMD5XJ4d0Cb"
        
        Superwall.configure(apiKey: SUPERWALL_API_KEY)
        print("✅ Superwall configuration initiated")
        
        // Optional: Set user attributes for targeting
        // Superwall.shared.setUserAttributes([
        //     "plan": "free",
        //     "profiles_created": 0
        // ])
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ Failed to configure Google Sign-In: Missing CLIENT_ID")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Google Sign-In configured successfully")
    }
    
    private func configureAppearance() {
        // Register custom fonts (Poppins & Inter available when needed)
        AppFonts.registerFonts()

        #if DEBUG
        AppFonts.printAvailableFonts()
        #endif

        // Configure global app appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        // Configure tab bar appearance
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray

        // Senior-friendly settings
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance()
        }
    }
    
    // MARK: - App Lifecycle Handlers
    private func handleAppLaunch() {
        print("📱 Hallo app launched")
        
        // Initialize critical services
        _Concurrency.Task {
            await initializeCriticalServices()
        }
        
        // Analytics removed - no longer tracking app launch
    }
    
    private func handleAppWillEnterForeground() {
        print("🔄 App entering foreground")
        
        // Refresh data when app comes to foreground
        _Concurrency.Task {
            await refreshAppData()
        }
        
        // Check for pending notifications
        checkPendingNotifications()
    }
    
    private func handleAppDidEnterBackground() {
        print("⏸️ App entering background")
        
        // Save any pending changes
        savePendingChanges()
        
        // Schedule background notifications if needed
        scheduleBackgroundNotifications()
    }
    
    // MARK: - Service Initialization
    private func initializeCriticalServices() async {
        print("🚀 [App] initializeCriticalServices START")

        // Initialize authentication state
        print("🔍 [App] Resolving AuthenticationServiceProtocol...")
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        print("🔍 [App] BEFORE initializeAuthState - currentUser: \(authService.currentUser?.uid ?? "nil")")
        await authService.initializeAuthState()
        print("🔍 [App] AFTER initializeAuthState - currentUser: \(authService.currentUser?.uid ?? "nil")")

        // Initialize DataSyncCoordinator (with real-time listeners if user authenticated)
        print("🔍 [App] Resolving DataSyncCoordinator...")
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        print("🔍 [App] DataSyncCoordinator resolved, calling initialize...")
        let userId = authService.currentUser?.uid
        await dataSyncCoordinator.initialize(userId: userId)
        print("🔍 [App] DataSyncCoordinator.initialize() completed")

        if let userId = userId {
            print("✅ [App] DataSyncCoordinator initialized with userId: \(userId)")
            // Setup incoming SMS listener
            setupSMSListener(userId: userId, dataSyncCoordinator: dataSyncCoordinator)
        } else {
            print("⚠️ [App] DataSyncCoordinator initialized without user (login required for sync)")
        }

        print("✅ Critical services initialized successfully")
    }
    
    private func requestNotificationPermissions() async {
        let notificationService = container.resolve(NotificationServiceProtocol.self)

        let granted = await notificationService.requestPermissions()
        print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")

        // Check for orphaned pending notifications from old code
        let pendingIds = await notificationService.getPendingNotificationIds()
        if !pendingIds.isEmpty {
            print("⚠️ Found \(pendingIds.count) orphaned pending notifications - clearing them")
            print("📋 Notification IDs: \(pendingIds.prefix(5))") // Log first 5 for debugging
            await notificationService.cancelAllNotifications()
            print("✅ All orphaned notifications cleared")
        } else {
            print("✅ No pending notifications found")
        }
    }
    
    // MARK: - Data Management
    private func refreshAppData() async {
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        
        await dataSyncCoordinator.syncAllData()
        print("✅ App data refreshed")
    }
    
    private func savePendingChanges() {
        // Save any unsaved changes before app goes to background
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        
        _Concurrency.Task {
            await dataSyncCoordinator.saveUnsavedChanges()
        }
    }
    
    /// Sets up Firestore listener for incoming SMS messages
    private func setupSMSListener(userId: String, dataSyncCoordinator: DataSyncCoordinator) {
        print("📱 [App] Setting up SMS listener for user: \(userId)")

        guard let databaseService = container.resolve(DatabaseServiceProtocol.self) as? FirebaseDatabaseService else {
            print("❌ [App] Failed to cast DatabaseService to FirebaseDatabaseService")
            return
        }

        // Subscribe to incoming SMS messages
        databaseService.observeIncomingSMSMessages(userId)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ [App] SMS listener completed")
                    case .failure(let error):
                        print("❌ [App] SMS listener error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { smsResponse in
                    print("📩 [App] Received SMS response - broadcasting to DataSyncCoordinator")
                    print("   - Profile ID: \(smsResponse.profileId ?? "unknown")")
                    print("   - Message: \(smsResponse.textResponse ?? "no text")")
                    print("   - Is Confirmation: \(smsResponse.isConfirmationResponse)")

                    // Broadcast to all ViewModels via DataSyncCoordinator
                    dataSyncCoordinator.broadcastSMSResponse(smsResponse)
                }
            )
            .store(in: &container.cancellables) // Store in Container's cancellables

        print("✅ [App] SMS listener registered successfully")
    }

    private func checkPendingNotifications() {
        // For MVP, notifications are checked when tasks are loaded
        // No separate check needed at app foreground
        print("ℹ️ Notification check skipped - handled by task loading")
    }
    
    private func scheduleBackgroundNotifications() {
        // TODO: Implement background notifications if needed
        print("⚠️ Background notifications not yet implemented")
    }
    
    // Analytics removed - no longer tracking app events
}

// MARK: - App Configuration Extensions
extension HalloApp {
    // MARK: - Environment Setup
    private var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

// MARK: - Error Handling
extension HalloApp {
    private func handleCriticalError(_ error: Error) {
        print("🚨 Critical app error: \(error)")
        
        // Log to crash reporting service
        // CrashlyticsService.shared.recordError(error)
        
        // Show user-friendly error if needed
        _Concurrency.Task { @MainActor in
            print("🚨 Critical app error: \(error.localizedDescription)")
            // TODO: Display critical error to user if needed
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct HalloApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .inject(container: Container.shared)
    }
}
#endif

