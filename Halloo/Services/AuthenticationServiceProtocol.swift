//
//  AuthenticationServiceProtocol.swift
//  Hallo
//
//  Purpose: Defines secure authentication contract for family members accessing elderly care coordination
//  Key Features: 
//    • Multi-provider authentication (email/password, Apple ID, Google) for family convenience
//    • Secure account management with elderly care data protection standards
//    • Token management for API access and family data synchronization
//  Dependencies: Foundation, Firebase Auth, Apple AuthenticationServices, Google Sign-In
//  
//  Business Context: Secure gateway protecting elderly care data and enabling family coordination
//  Critical Paths: Account creation → Authentication → Family data access → Elderly profile management
//
//  Created by Claude Code on 2025-07-28
//

import Foundation
import Combine

/// Secure authentication service contract for family members accessing elderly care coordination features
///
/// This protocol defines the complete authentication interface for the Hallo app's family-focused
/// elderly care system. It handles secure account creation, multi-provider sign-in options,
/// and robust session management while protecting sensitive elderly care data and family
/// coordination information with enterprise-grade security standards.
///
/// ## Core Responsibilities:
/// - **Family Account Security**: Secure account creation and authentication for family members
/// - **Multi-Provider Support**: Email/password, Apple ID, and Google authentication options
/// - **Session Management**: Secure token handling and session persistence for family coordination
/// - **Account Recovery**: Password reset and account verification workflows
/// - **Data Protection**: Authentication barriers protecting elderly care information
///
/// ## Security Considerations:
/// - **Elderly Data Protection**: Authentication protects sensitive elderly care and response data
/// - **Family Privacy**: User isolation ensures families only access their own elderly profiles
/// - **Token Security**: Secure token management for API access and cross-device synchronization
/// - **Account Verification**: Email verification for account security and recovery
///
/// ## Usage Pattern:
/// ```swift
/// let authService: AuthenticationServiceProtocol = container.makeAuthService()
/// 
/// // Create family account for elderly care coordination
/// let result = try await authService.createAccount(
///     email: "family@example.com",
///     password: "SecurePassword123",
///     fullName: "Sarah Johnson"
/// )
/// 
/// // Check authentication status
/// if authService.isAuthenticated {
///     let user = authService.currentUser
///     // Access elderly care features
/// }
/// ```
///
/// - Important: Authentication is required for all elderly care coordination features
/// - Note: Supports offline token validation for seamless family user experience
/// - Warning: Account deletion permanently removes all family and elderly care data
protocol AuthenticationServiceProtocol {
    
    /// Currently authenticated family user with elderly care access permissions
    /// 
    /// Provides access to authenticated family member's profile information
    /// including unique identifier, email, and verification status for
    /// elderly care coordination and family data access.
    var currentUser: AuthUser? { get }
    
    /// Whether a family member is currently authenticated for elderly care access
    /// 
    /// Indicates if family user has valid authentication session enabling
    /// access to elderly profiles, care tasks, and SMS coordination features.
    var isAuthenticated: Bool { get }
    
    // MARK: - Family Account Creation and Authentication
    
    /// Creates secure family account for elderly care coordination access
    /// 
    /// Establishes new family member account with secure password requirements
    /// and email verification for protecting elderly care data and enabling
    /// multi-device family coordination across care management workflows.
    ///
    /// - Parameter email: Family member's email address for account identification
    /// - Parameter password: Secure password meeting elderly care data protection standards
    /// - Parameter fullName: Family member's full name for care coordination identification
    /// - Returns: Authentication result with user ID and access tokens
    /// - Throws: AuthError if account creation fails or email already exists
    /// - Important: Account creation enables elderly profile management and care coordination
    func createAccount(email: String, password: String, fullName: String) async throws -> AuthResult
    
    /// Authenticates family member with email and password for elderly care access
    /// 
    /// Validates family member credentials and establishes secure session for
    /// accessing elderly profiles, care tasks, and SMS coordination features
    /// with persistent authentication across app sessions.
    ///
    /// - Parameter email: Family member's registered email address
    /// - Parameter password: Family member's account password
    /// - Returns: Authentication result with user session and access permissions
    /// - Throws: AuthError if credentials are invalid or account is disabled
    func signIn(email: String, password: String) async throws -> AuthResult
    
    /// Authenticates family member using Apple ID for convenient elderly care access
    /// 
    /// Provides streamlined authentication using Apple's secure Sign in with Apple
    /// service for family members preferring biometric or Apple ecosystem
    /// authentication while maintaining elderly care data protection.
    ///
    /// - Returns: Authentication result with Apple-provided user information
    /// - Throws: AuthError if Apple authentication fails or is cancelled
    /// - Note: Apple Sign In provides enhanced privacy and security for family users
    func signInWithApple() async throws -> AuthResult
    
    /// Authenticates family member using Google account for elderly care coordination
    /// 
    /// Enables Google account authentication for family members preferring
    /// Google ecosystem integration while maintaining secure access to
    /// elderly care features and family coordination capabilities.
    ///
    /// - Returns: Authentication result with Google-provided user information
    /// - Throws: AuthError if Google authentication fails or permissions denied
    /// - Important: Google authentication requires appropriate OAuth scopes for elderly care access
    @MainActor func signInWithGoogle() async throws -> AuthResult
    
    // MARK: - Family Account Security Management
    
    /// Securely signs out family member and clears elderly care access session
    /// 
    /// Terminates authenticated session and clears access tokens while ensuring
    /// elderly care data security and preventing unauthorized access to family
    /// coordination features after family member logout.
    ///
    /// - Throws: AuthError if sign out process fails
    /// - Important: Sign out prevents access to elderly care data until re-authentication
    func signOut() async throws
    
    /// Permanently deletes family account and all associated elderly care data
    /// 
    /// Irreversible account deletion that removes family member account,
    /// elderly profiles, care tasks, SMS responses, and coordination history
    /// while respecting data privacy and elderly care information protection.
    ///
    /// - Throws: AuthError if account deletion fails or requires additional verification
    /// - Warning: Account deletion permanently removes all family and elderly care coordination data
    func deleteAccount() async throws
    
    /// Updates family member's password with enhanced security requirements
    /// 
    /// Modifies account password with validation against elderly care data
    /// protection standards and maintains secure access to family coordination
    /// features with improved authentication security.
    ///
    /// - Parameter newPassword: New secure password meeting protection requirements
    /// - Throws: AuthError if password update fails or doesn't meet security standards
    /// - Important: Password updates require current session validation for security
    func updatePassword(_ newPassword: String) async throws
    
    /// Sends password reset email for family account recovery
    /// 
    /// Initiates secure password reset workflow for family members who cannot
    /// access their elderly care coordination account, providing secure recovery
    /// path while protecting elderly care data from unauthorized access.
    ///
    /// - Parameter email: Family member's registered email address for password reset
    /// - Throws: AuthError if password reset delivery fails or email not found
    /// - Note: Password reset emails include security verification for elderly care data protection
    func sendPasswordReset(to email: String) async throws
    
    // MARK: - Family Profile Information Management
    
    /// Updates family member's display name for elderly care coordination identification
    /// 
    /// Modifies family member's display name used in care coordination interfaces,
    /// SMS attribution, and family member identification across elderly care
    /// workflows while maintaining authentication security.
    ///
    /// - Parameter name: Updated display name for family care coordination
    /// - Throws: AuthError if display name update fails
    /// - Note: Display name changes appear in elderly care coordination and SMS attribution
    func updateDisplayName(_ name: String) async throws
    
    /// Updates family member's email address with verification requirements
    /// 
    /// Changes primary email address for family account while maintaining
    /// elderly care data access and requiring email verification for security
    /// and account recovery capabilities.
    ///
    /// - Parameter email: New email address for family account identification
    /// - Throws: AuthError if email update fails or verification is incomplete
    /// - Important: Email changes require verification to maintain account security
    func updateEmail(_ email: String) async throws
    
    // MARK: - Secure Token Management for Elderly Care API Access
    
    /// Refreshes authentication token for continued elderly care API access
    /// 
    /// Obtains fresh authentication token for accessing elderly care coordination
    /// APIs and maintaining secure session for family data synchronization
    /// and cross-device care coordination workflows.
    ///
    /// - Returns: Refreshed authentication token for API access
    /// - Throws: AuthError if token refresh fails or session is invalid
    /// - Important: Token refresh enables continuous access to elderly care features
    func refreshAuthToken() async throws -> String
    
    /// Retrieves current authentication token for elderly care API requests
    /// 
    /// Provides valid authentication token for API requests accessing elderly
    /// profiles, care tasks, SMS responses, and family coordination features
    /// with proper security validation and expiration handling.
    ///
    /// - Returns: Current valid authentication token for API access
    /// - Throws: AuthError if token retrieval fails or session has expired
    /// - Note: ID tokens provide secure identity verification for elderly care data access
    func getIdToken() async throws -> String
    
    // MARK: - Family Account Verification and Security Validation
    
    /// Sends email verification for family account security confirmation
    /// 
    /// Delivers email verification message to family member for account
    /// security validation and enabling full access to elderly care coordination
    /// features with verified communication channel for security alerts.
    ///
    /// - Throws: AuthError if verification email delivery fails
    /// - Important: Email verification enhances security for elderly care data access
    func sendEmailVerification() async throws
    
    /// Checks if family member's email address has been verified for security
    /// 
    /// Validates email verification status for family account security and
    /// determines eligibility for full elderly care coordination features
    /// and security-sensitive family data access.
    ///
    /// - Returns: True if email address has been verified for security
    /// - Note: Email verification may be required for certain elderly care features
    func isEmailVerified() -> Bool
    
    /// Publisher for authentication state changes
    /// 
    /// Publishes authentication state changes to enable reactive UI updates
    /// and family coordination synchronization when users sign in or out
    var authStatePublisher: AnyPublisher<Bool, Never> { get }
    
    /// Initializes authentication state on app launch
    /// 
    /// Sets up authentication state monitoring and restores any existing
    /// user sessions for seamless family coordination access
    func initializeAuthState() async

    /// Waits for auth state to be initialized before making routing decisions
    ///
    /// Firebase Auth restores sessions from Keychain asynchronously on app launch.
    /// Call this method before checking `isAuthenticated` to ensure the auth state
    /// has been definitively determined (either with a user or definitively no user).
    ///
    /// This prevents race conditions where routing happens before Firebase has
    /// finished restoring the session from Keychain.
    ///
    /// - Note: Returns immediately if auth state is already initialized
    func waitForAuthStateInitialization() async
}

// MARK: - Auth User Model
struct AuthUser: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let isEmailVerified: Bool
    let createdAt: Date?
    let lastSignInAt: Date?
    
    init(
        uid: String,
        email: String? = nil,
        displayName: String? = nil,
        isEmailVerified: Bool = false,
        createdAt: Date? = nil,
        lastSignInAt: Date? = nil
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isEmailVerified = isEmailVerified
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
    }
}

// MARK: - Auth Result Model
struct AuthResult: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let isNewUser: Bool
    let idToken: String
    
    init(
        uid: String,
        email: String? = nil,
        displayName: String? = nil,
        isNewUser: Bool = false,
        idToken: String = ""
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isNewUser = isNewUser
        self.idToken = idToken
    }
}

// MARK: - Authentication Errors
enum AuthenticationError: LocalizedError {
    case userNotFound
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case tokenExpired
    case userNotAuthenticated
    case emailNotVerified
    case accountDisabled
    case tooManyRequests
    case operationNotAllowed
    case invalidEmail
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User account not found. Please check your credentials or create a new account."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .emailAlreadyInUse:
            return "An account with this email already exists. Please sign in instead."
        case .weakPassword:
            return "Password is too weak. Please choose a stronger password."
        case .networkError:
            return "Network connection error. Please check your internet connection and try again."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .userNotAuthenticated:
            return "Please sign in to continue."
        case .emailNotVerified:
            return "Please verify your email address before continuing."
        case .accountDisabled:
            return "Your account has been disabled. Please contact support."
        case .tooManyRequests:
            return "Too many failed attempts. Please try again later."
        case .operationNotAllowed:
            return "This operation is not allowed. Please contact support."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .unknownError(let message):
            return "An error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .userNotFound:
            return "Try creating a new account or check your email address."
        case .invalidCredentials:
            return "Double-check your email and password, or use 'Forgot Password'."
        case .emailAlreadyInUse:
            return "Try signing in with your existing account."
        case .weakPassword:
            return "Use at least 8 characters with a mix of letters, numbers, and symbols."
        case .networkError:
            return "Check your internet connection and try again."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .emailNotVerified:
            return "Check your email for a verification link."
        case .tooManyRequests:
            return "Wait a few minutes before trying again."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}