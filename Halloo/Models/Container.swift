import Foundation
import SwiftUI
import Combine
import Firebase

// MARK: - Dependency Container
final class Container: ObservableObject {
    static let shared = Container()

    private var services: [String: Any] = [:]
    private var singletons: [String: Any] = [:]  // Singleton instances
    private let lock = NSLock()

    // Store Combine subscriptions (e.g., SMS listener)
    var cancellables = Set<AnyCancellable>()

    private init() {
        setupServices()
    }
        
    // MARK: - Service Registration
    private func setupServices() {
        // Verify Firebase is configured (logs warning if not)
        _ = checkFirebaseConfiguration()

        // Core Services - Firebase only (Mock services removed for MVP)
        registerSingleton(AuthenticationServiceProtocol.self) {
            FirebaseAuthenticationService()
        }

        registerSingleton(DatabaseServiceProtocol.self) {
            FirebaseDatabaseService()
        }
        
        // Twilio SMS Service (Production)
        register(SMSServiceProtocol.self) {
            TwilioSMSService()
        }
        
        // Notification Service - TODO: Implement real NotificationService
        register(NotificationServiceProtocol.self) {
            NotificationService()
        }

        // DataSync Coordinator - Singleton for multi-device sync
        registerSingleton(DataSyncCoordinator.self) {
            DataSyncCoordinator(
                databaseService: self.resolve(DatabaseServiceProtocol.self)
            )
        }

        // Image Cache Service - Singleton for profile photo caching
        registerSingleton(ImageCacheService.self) {
            ImageCacheService()
        }

        // Subscription Service - Singleton for RevenueCat subscription management
        registerSingleton(SubscriptionServiceProtocol.self) {
            RevenueCatSubscriptionService()
        }
    }
    
    // MARK: - Firebase Configuration Check
    private func checkFirebaseConfiguration() -> Bool {
        // Check if Firebase has been configured
        guard FirebaseApp.app() != nil else {
            return false
        }

        // In preview/canvas mode, use mock services
        if ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
            return false
        }

        // Check for explicit mock mode environment variable
        if ProcessInfo.processInfo.environment["USE_MOCK_SERVICES"] == "true" {
            return false
        }

        return true
    }
    
    // MARK: - Generic Registration
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        services[key] = factory
    }
    
    func register<T>(_ type: T.Type, factory: @escaping (Container) -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        services[key] = { [weak self] in
            guard let self = self else { 
                fatalError("Container deallocated during service resolution") 
            }
            return factory(self)
        }
    }
    
    // MARK: - Singleton Registration
    private func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)

        // Create instance OUTSIDE the lock to avoid deadlock when factory calls resolve()
        let instance = factory()

        // Then lock only to store it
        lock.lock()
        defer { lock.unlock() }
        singletons[key] = instance
    }

    // MARK: - Service Resolution
    func resolve<T>(_ type: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: type)

        // Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // Fall back to factory pattern for non-singletons
        guard let factory = services[key] else {
            fatalError("Service \(key) not registered")
        }

        if let directFactory = factory as? () -> T {
            return directFactory()
        } else if let containerFactory = factory as? (Container) -> T {
            return containerFactory(self)
        } else {
            fatalError("Invalid factory type for service \(key)")
        }
    }
    
    // MARK: - ViewModel Factories
    @MainActor
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            authService: resolve(AuthenticationServiceProtocol.self),
            databaseService: resolve(DatabaseServiceProtocol.self)
        )
    }
    
    @MainActor
    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            smsService: resolve(SMSServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self)
        )
    }

    @MainActor
    func makeProfileViewModelForCanvas() -> ProfileViewModel {
        ProfileViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            smsService: resolve(SMSServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self),
            skipAutoLoad: true
        )
    }
    
    @MainActor
    func makeTaskViewModel() -> TaskViewModel {
        TaskViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            smsService: resolve(SMSServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self)
        )
    }
    
    @MainActor
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self)
        )
    }
    
    @MainActor
    func makeGalleryViewModel() -> GalleryViewModel {
        GalleryViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self)
        )
    }
}

// MARK: - SwiftUI Environment Integration
struct ContainerKey: EnvironmentKey {
    static let defaultValue: Container = Container.shared
}

extension EnvironmentValues {
    var container: Container {
        get { self[ContainerKey.self] }
        set { self[ContainerKey.self] = newValue }
    }
}

// MARK: - SwiftUI ViewModifier for Dependency Injection
struct DependencyInjection: ViewModifier {
    let container: Container
    
    func body(content: Content) -> some View {
        content
            .environmentObject(container)
            .environment(\.container, container)
    }
}

extension View {
    func inject(container: Container = Container.shared) -> some View {
        modifier(DependencyInjection(container: container))
    }
}

// MARK: - Service Factory (Alternative Pattern)
class ServiceFactory {
    private let container: Container
    
    init(container: Container = Container.shared) {
        self.container = container
    }
    
    // Factory methods for services that need special configuration
    func makeAuthenticatedDatabaseService() async throws -> DatabaseServiceProtocol {
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        
        // Ensure user is authenticated before creating database service
        guard authService.isAuthenticated else {
            throw ServiceError.userNotAuthenticated
        }
        
        return container.resolve(DatabaseServiceProtocol.self)
    }
    
    func makeConfiguredSMSService() -> SMSServiceProtocol {
        let smsService = container.resolve(SMSServiceProtocol.self)
        
        // Configure SMS service with app-specific settings
        // This would be where we set Twilio credentials, templates, etc.
        
        return smsService
    }
}

// MARK: - Service Errors
enum ServiceError: LocalizedError {
    case userNotAuthenticated
    case serviceNotAvailable
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to access this service"
        case .serviceNotAvailable:
            return "Required service is not available"
        case .configurationError:
            return "Service configuration error"
        }
    }
}

// MARK: - Testing Support
#if DEBUG
extension Container {
    func registerMock<T>(_ type: T.Type, mock: T) {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: type)
        services[key] = { mock }
    }
}
#endif
