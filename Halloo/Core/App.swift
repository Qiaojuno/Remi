import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseMessaging
import SuperwallKit
import RevenueCat
import GoogleSignIn
import UserNotifications

// MARK: - App Delegate for Push Notifications & Orientation Control

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set FCM and notification delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications (required for push)
        application.registerForRemoteNotifications()

        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    // MARK: - APNs Token Registration

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass APNs token to Firebase - FCM exchanges it for an FCM token
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [Push] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - FCM Token Handling (MessagingDelegate)

    /// Pending FCM token that arrived before user was authenticated
    /// Will be stored once authentication completes
    private static var pendingFCMToken: String?

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            return
        }

        // Store token in Firestore for authenticated users
        _Concurrency.Task {
            await storeFCMToken(token)
        }
    }

    /// Stores FCM token in Firestore for the current user
    /// If user is not authenticated yet, queues the token for later storage
    private func storeFCMToken(_ token: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            // ✅ FIX: Queue token for storage once user authenticates
            // This happens when FCM delivers token before Firebase Auth restores session
            AppDelegate.pendingFCMToken = token
            print("⚠️ [Push] User not authenticated yet, queuing FCM token for later")
            return
        }

        // Clear any pending token since we're storing now
        AppDelegate.pendingFCMToken = nil

        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                "fcmPlatform": "ios"
            ], merge: true)
            print("✅ [Push] FCM token stored successfully")
        } catch {
            print("❌ [Push] Failed to store FCM token: \(error.localizedDescription)")
        }
    }

    /// Stores any pending FCM token that arrived before authentication
    /// Called after user successfully authenticates
    static func storePendingFCMTokenIfNeeded() async {
        guard let token = pendingFCMToken,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }

        pendingFCMToken = nil
        print("📤 [Push] Storing queued FCM token after authentication")

        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                "fcmPlatform": "ios"
            ], merge: true)
            print("✅ [Push] Queued FCM token stored successfully")
        } catch {
            print("❌ [Push] Failed to store queued FCM token: \(error.localizedDescription)")
        }
    }

    // MARK: - Foreground Notification Display (UNUserNotificationCenterDelegate)

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification Tap Handling (UNUserNotificationCenterDelegate)

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Extract custom data from notification payload
        if let type = userInfo["type"] as? String, type == "noReply" {
            let habitId = userInfo["habitId"] as? String
            let profileId = userInfo["profileId"] as? String

            // Post notification to navigate to relevant screen
            NotificationCenter.default.post(
                name: .didTapNoReplyNotification,
                object: nil,
                userInfo: [
                    "habitId": habitId as Any,
                    "profileId": profileId as Any
                ]
            )
        }

        completionHandler()
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    /// Posted when user taps a "no reply" push notification
    static let didTapNoReplyNotification = Notification.Name("didTapNoReplyNotification")
}

// MARK: - Main App

@main
struct HalloApp: App {
    // MARK: - App Delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Dependencies
    private let container: Container

    /// Shared PurchaseController for Superwall/RevenueCat integration
    private let purchaseController = PurchaseController()

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

            // CRITICAL: Start syncing subscription status to Superwall
            // This must be called AFTER both RevenueCat and Superwall are configured
            // Without this, Superwall will timeout waiting for subscription status
            purchaseController.syncSubscriptionStatus()
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
                .onReceive(NotificationCenter.default.publisher(for: .didTapNoReplyNotification)) { notification in
                    handleNoReplyNotificationTap(notification)
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
        // RevenueCat Public SDK API Key (Apple App Store)
        // This key works for both debug and release builds
        // RevenueCat automatically detects sandbox vs production from the receipt
        let REVENUECAT_API_KEY = "appl_xYqryxlTdBpJFNfaYVAftzCmVaM"

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
        let options = SuperwallOptions()
        #if DEBUG
        options.logging.level = .debug  // Enable debug logging to diagnose product issues
        #endif

        // Use the shared purchaseController instance so we can call syncSubscriptionStatus()
        Superwall.configure(
            apiKey: SUPERWALL_API_KEY,
            purchaseController: purchaseController,
            options: options
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

        // Clear badge count when app comes to foreground
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    private func handleAppDidEnterBackground() {
        // Save any pending changes
        savePendingChanges()
    }

    private func handleNoReplyNotificationTap(_ notification: Notification) {
        // Handle navigation when user taps a "no reply" notification
        guard let userInfo = notification.userInfo,
              let _ = userInfo["profileId"] as? String else {
            return
        }

        // TODO: Implement navigation to profile/habit detail view
        // This could update an @AppStorage or @Published property that ContentView observes
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

            // Re-register FCM token for this user (in case token changed while logged out)
            await refreshFCMToken()

            // ✅ FIX: Store any FCM token that arrived before auth was restored
            await AppDelegate.storePendingFCMTokenIfNeeded()
        }
    }

    private func requestNotificationPermissions() async {
        let notificationService = container.resolve(NotificationServiceProtocol.self)
        _ = await notificationService.requestPermissions()
    }

    /// Refreshes FCM token registration for the current user
    private func refreshFCMToken() async {
        guard let token = Messaging.messaging().fcmToken,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                "fcmPlatform": "ios"
            ], merge: true)
        } catch {
            print("❌ [Push] Failed to refresh FCM token: \(error.localizedDescription)")
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

// MARK: - FCM Token Management on Auth State Changes

extension HalloApp {
    /// Call this when user logs out to remove FCM token
    static func clearFCMTokenOnLogout(userId: String) async {
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": FieldValue.delete()
            ])
        } catch {
            print("❌ [Push] Failed to clear FCM token: \(error.localizedDescription)")
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
