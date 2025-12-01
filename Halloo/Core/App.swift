import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SuperwallKit
import RevenueCat
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
        }

        // Initialize Container AFTER Firebase is configured
        container = Container.shared

        // Configure other services after container is initialized
        if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            configureNotifications()
            configureRevenueCat()
            configureSuperwall()
            configureGoogleSignIn()
        }

        configureAppearance()
    }
    
    private static func configureFirebase() {
        // Simple Firebase configuration
        FirebaseApp.configure()
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

    private func configureRevenueCat() {
        // RevenueCat API key - automatically switches between Test Store and Production
        // ⚠️ IMPORTANT: Replace "YOUR_PRODUCTION_KEY_HERE" with your production API key before release
        let REVENUECAT_API_KEY: String = {
            #if DEBUG
            // Test Store key for development and testing
            // This key works immediately without connecting real App Store
            return "test_JxDSDtqZjJxdAqlujuzvhPtVHSO"
            #else
            // Production key for App Store release
            // TODO: Replace with your production API key from RevenueCat dashboard
            // Find it at: Settings -> API Keys -> Apple App Store
            return "YOUR_PRODUCTION_KEY_HERE"
            #endif
        }()

        // Validate production key
        #if !DEBUG
        guard REVENUECAT_API_KEY != "YOUR_PRODUCTION_KEY_HERE" else {
            fatalError("🚨 CRITICAL: Replace production RevenueCat API key before release!")
        }
        #endif

        // Get subscription service from container
        let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)

        // Configure RevenueCat with current user ID (if authenticated)
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        let userId = authService.currentUser?.uid

        subscriptionService.configure(apiKey: REVENUECAT_API_KEY, userId: userId)
    }

    private func configureSuperwall() {
        // Superwall API key - automatically switches between Test and Production
        // ⚠️ IMPORTANT: Add production key before release (or use same key for both)
        let SUPERWALL_API_KEY: String = {
            #if DEBUG
            // Development/Test key
            return "pk_1FZVcGgpr1JMD5XJ4d0Cb"
            #else
            // Production key for App Store release
            // NOTE: Superwall allows using the same key for dev and prod
            // If you have separate environments, replace with production key
            // Find it at: Superwall Dashboard -> Settings -> API Keys
            return "pk_1FZVcGgpr1JMD5XJ4d0Cb"  // TODO: Update if using separate prod key
            #endif
        }()

        // Configure Superwall to use RevenueCat as the purchase controller
        Superwall.configure(
            apiKey: SUPERWALL_API_KEY,
            purchaseController: PurchaseController()
        )

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
        // Initialize critical services
        _Concurrency.Task {
            await initializeCriticalServices()
        }
    }

    private func handleAppWillEnterForeground() {
        // Refresh data when app comes to foreground
        _Concurrency.Task {
            await refreshAppData()
        }

        // Check for pending notifications
        checkPendingNotifications()
    }

    private func handleAppDidEnterBackground() {
        // Save any pending changes
        savePendingChanges()

        // Schedule background notifications if needed
        scheduleBackgroundNotifications()
    }
    
    // MARK: - Service Initialization
    private func initializeCriticalServices() async {
        // Initialize authentication state
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        await authService.initializeAuthState()

        // Initialize DataSyncCoordinator (with real-time listeners if user authenticated)
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)
        let userId = authService.currentUser?.uid
        await dataSyncCoordinator.initialize(userId: userId)

        if let userId = userId {
            // Setup incoming SMS listener
            setupSMSListener(userId: userId, dataSyncCoordinator: dataSyncCoordinator)
        }
    }
    
    private func requestNotificationPermissions() async {
        let notificationService = container.resolve(NotificationServiceProtocol.self)

        _ = await notificationService.requestPermissions()

        // Check for orphaned pending notifications from old code
        let pendingIds = await notificationService.getPendingNotificationIds()
        if !pendingIds.isEmpty {
            await notificationService.cancelAllNotifications()
        }
    }
    
    // MARK: - Data Management
    private func refreshAppData() async {
        let dataSyncCoordinator = container.resolve(DataSyncCoordinator.self)

        await dataSyncCoordinator.syncAllData()
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
        guard let databaseService = container.resolve(DatabaseServiceProtocol.self) as? FirebaseDatabaseService else {
            print("❌ [App] Failed to cast DatabaseService to FirebaseDatabaseService")
            return
        }

        // Subscribe to incoming SMS messages
        databaseService.observeIncomingSMSMessages(userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ [App] SMS listener error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { smsResponse in
                    // Broadcast to all ViewModels via DataSyncCoordinator
                    dataSyncCoordinator.broadcastSMSResponse(smsResponse)
                }
            )
            .store(in: &container.cancellables) // Store in Container's cancellables
    }

    private func checkPendingNotifications() {
        // For MVP, notifications are checked when tasks are loaded
        // No separate check needed at app foreground
    }

    private func scheduleBackgroundNotifications() {
        // TODO: Implement background notifications if needed
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

