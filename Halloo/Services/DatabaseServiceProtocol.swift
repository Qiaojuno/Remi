//
//  DatabaseServiceProtocol.swift
//  Remi
//
//  Purpose: Defines comprehensive database operations for elderly care coordination and family data management
//  Key Features: 
//    • Complete CRUD operations for users, elderly profiles, tasks, and SMS responses
//    • Advanced analytics and reporting for care adherence tracking
//    • Batch operations and search capabilities for family coordination efficiency
//  Dependencies: Foundation, Core Data Models (User, ElderlyProfile, Task, SMSResponse)
//  
//  Business Context: Central data contract enabling all elderly care features and family synchronization
//  Critical Paths: Profile creation → Task scheduling → SMS response tracking → Analytics generation
//
//  Created on 2025-07-28
//

import Foundation
import Combine

/// Comprehensive database service contract for elderly care coordination and family data management
///
/// This protocol defines the complete data persistence interface for the Hallo app's elderly
/// care coordination system. It encompasses all operations needed for families to manage
/// elderly profiles, coordinate care tasks, track SMS responses, and analyze care adherence
/// patterns across multiple family members and elderly users.
///
/// ## Core Responsibilities:
/// - **Family User Management**: Account creation, profile management, and subscription tracking
/// - **Elderly Profile Operations**: Profile lifecycle, SMS confirmation status, and care context
/// - **Task Coordination**: Care task scheduling, completion tracking, and family synchronization
/// - **SMS Response Processing**: Response storage, completion correlation, and communication history
/// - **Analytics & Reporting**: Care adherence analysis, family insights, and trend identification
///
/// ## Implementation Considerations:
/// - **Family Privacy**: All operations respect user isolation and family data boundaries
/// - **Real-Time Sync**: Support for live updates across family member devices
/// - **Offline Resilience**: Graceful handling of network interruptions during care coordination
/// - **Performance Optimization**: Efficient queries for time-sensitive elderly care operations
///
/// ## Usage Pattern:
/// ```swift
/// let databaseService: DatabaseServiceProtocol = container.makeDatabaseService()
/// 
/// // Create elderly profile
/// let profile = ElderlyProfile(name: "Grandma Rose", phoneNumber: "+1234567890")
/// try await databaseService.createElderlyProfile(profile)
/// 
/// // Track care task completion
/// let response = SMSResponse(taskId: taskId, isCompleted: true)
/// try await databaseService.createSMSResponse(response)
/// 
/// // Generate family care analytics
/// let analytics = try await databaseService.getUserAnalytics(for: userId)
/// ```
///
/// - Important: All operations maintain family data isolation and elderly care context
/// - Note: Supports both individual operations and batch processing for efficiency
/// - Warning: Care data persistence is critical for family peace of mind and elderly safety
protocol DatabaseServiceProtocol {
    
    // MARK: - Family User Management Operations
    
    /// Creates a new family user account with subscription and onboarding status
    /// 
    /// Establishes the foundational family account that will coordinate elderly care.
    /// Includes subscription tracking, onboarding completion status, and personalization
    /// data from the care needs assessment quiz.
    ///
    /// - Parameter user: Family user profile with account details and care preferences
    /// - Throws: DatabaseError if account creation fails or email already exists
    /// - Important: User creation enables elderly profile management and care coordination
    func createUser(_ user: User) async throws
    
    /// Retrieves family user account information and care preferences
    /// 
    /// Loads complete family user profile including subscription status, onboarding
    /// completion, and elderly care personalization data for app customization.
    ///
    /// - Parameter userId: Unique identifier for the family user account
    /// - Returns: Complete user profile or nil if account not found
    /// - Throws: DatabaseError if data retrieval fails
    func getUser(_ userId: String) async throws -> User?
    
    /// Updates family user account with subscription changes and preference modifications
    /// 
    /// Handles subscription status changes, profile updates, and care preference
    /// modifications while maintaining elderly care context and family coordination.
    ///
    /// - Parameter user: Updated family user profile with new information
    /// - Throws: DatabaseError if update operation fails
    /// - Note: Updates trigger family synchronization across devices
    func updateUser(_ user: User) async throws
    
    /// Permanently removes family user account and all associated elderly care data
    /// 
    /// Cascading deletion that removes user account, elderly profiles, care tasks,
    /// SMS responses, and analytics data while respecting data privacy requirements.
    ///
    /// - Parameter userId: Unique identifier for the family user account to delete
    /// - Throws: DatabaseError if deletion fails or user has active dependencies
    /// - Warning: Irreversible operation that removes all family care coordination data
    func deleteUser(_ userId: String) async throws

    // MARK: - Phone Registry Operations

    /// Checks phone number opt-out and confirmation status in the global registry
    ///
    /// Should be called BEFORE creating a profile to:
    /// 1. Block creation if phone number has previously opted out (STOP keyword)
    /// 2. Auto-confirm if phone was recently confirmed (skip SMS confirmation)
    ///
    /// This ensures TCPA compliance by respecting opt-outs even after profile deletion.
    ///
    /// - Parameter phoneNumber: E.164 formatted phone number (e.g., +17788143739)
    /// - Returns: PhoneRegistryStatus with optedOut, recentlyConfirmed, canAutoConfirm
    /// - Throws: Error if Cloud Function call fails (returns safe default on error)
    func checkPhoneOptOutStatus(phoneNumber: String) async throws -> PhoneRegistryStatus

    // MARK: - Elderly Profile Lifecycle Operations
    
    /// Creates a new elderly family member profile with SMS confirmation workflow initiation
    /// 
    /// Establishes an elderly profile that will receive SMS care reminders after
    /// confirmation. Includes relationship context, timezone information, and
    /// communication preferences for personalized elderly care coordination.
    ///
    /// - Parameter profile: Elderly family member profile with contact and care context
    /// - Throws: DatabaseError if profile creation fails or phone number conflicts
    /// - Important: Profile creation triggers SMS confirmation workflow to elderly person
    func createElderlyProfile(_ profile: ElderlyProfile) async throws
    
    /// Retrieves specific elderly profile with current confirmation and activity status
    /// 
    /// Loads complete elderly profile including SMS confirmation status, last activity,
    /// and care context for family coordination and task scheduling decisions.
    ///
    /// - Parameter profileId: Unique identifier for the elderly profile
    /// - Returns: Complete elderly profile or nil if not found
    /// - Throws: DatabaseError if data retrieval fails
    func getElderlyProfile(_ profileId: String) async throws -> ElderlyProfile?
    
    /// Retrieves all elderly profiles managed by a specific family user
    /// 
    /// Loads the complete collection of elderly family members under a family's
    /// care coordination, including confirmation status and activity tracking.
    ///
    /// - Parameter userId: Family user managing the elderly profiles
    /// - Returns: Array of elderly profiles sorted by creation date
    /// - Throws: DatabaseError if data retrieval fails
    /// - Note: Maximum 4 profiles per family to prevent SMS overwhelming
    func getElderlyProfiles(for userId: String) async throws -> [ElderlyProfile]
    
    /// Updates elderly profile information and handles SMS re-confirmation if needed
    /// 
    /// Modifies elderly profile details, handling phone number changes that require
    /// new SMS confirmation workflow and status updates for family coordination.
    ///
    /// - Parameter profile: Updated elderly profile with modified information
    /// - Throws: DatabaseError if update operation fails
    /// - Important: Phone number changes reset confirmation status and trigger new SMS
    func updateElderlyProfile(_ profile: ElderlyProfile) async throws
    
    /// Removes elderly profile and cascades deletion to associated care tasks and responses
    /// 
    /// Permanently deletes elderly profile along with all care tasks, SMS responses,
    /// and analytics data while maintaining family data integrity.
    ///
    /// - Parameter profileId: Unique identifier for the elderly profile to delete
    /// - Throws: DatabaseError if deletion fails or profile has active dependencies
    /// - Warning: Cascading deletion removes all care coordination history for this elderly person
    func deleteElderlyProfile(_ profileId: String, userId: String) async throws
    
    /// Retrieves all confirmed elderly profiles for a specific family user
    /// 
    /// Loads only confirmed elderly profiles that have completed SMS verification
    /// and are ready for task assignments and care coordination.
    ///
    /// - Parameter userId: Family user managing the elderly profiles
    /// - Returns: Array of confirmed elderly profiles
    /// - Throws: DatabaseError if data retrieval fails
    func getConfirmedProfiles(for userId: String) async throws -> [ElderlyProfile]
    
    // MARK: - Elderly Care Task Coordination Operations
    
    /// Creates a new care task with SMS reminder scheduling for elderly family member
    /// 
    /// Establishes a care task that will generate SMS reminders to the elderly person.
    /// Includes scheduling logic, completion requirements, and family notification setup.
    ///
    /// - Parameter task: Care task with scheduling, requirements, and elderly profile association
    /// - Throws: DatabaseError if task creation fails or profile limits exceeded
    /// - Important: Task creation for confirmed profiles triggers SMS reminder scheduling
    func createTask(_ task: Task) async throws
    
    /// Retrieves specific care task with current completion status and response history
    /// 
    /// Loads complete task information including scheduling details, completion status,
    /// and associated SMS responses for family oversight and coordination.
    ///
    /// - Parameter taskId: Unique identifier for the care task
    /// - Returns: Complete care task or nil if not found
    /// - Throws: DatabaseError if data retrieval fails
    func getTask(_ taskId: String) async throws -> Task?
    
    /// Retrieves all care tasks created by a specific family user across elderly profiles
    /// 
    /// Loads comprehensive task collection for family care coordination dashboard,
    /// including tasks for all elderly profiles managed by the family.
    ///
    /// - Parameter userId: Family user who created the care tasks
    /// - Returns: Array of care tasks sorted by creation date
    /// - Throws: DatabaseError if data retrieval fails
    func getTasks(for userId: String) async throws -> [Task]
    
    /// Retrieves care tasks for specific elderly profile with family context validation
    /// 
    /// Loads tasks targeted at a specific elderly family member, ensuring proper
    /// family ownership and care coordination context.
    ///
    /// - Parameter profileId: Elderly profile receiving the care tasks
    /// - Parameter userId: Family user managing the elderly profile
    /// - Returns: Array of care tasks for the specified elderly profile
    /// - Throws: DatabaseError if data retrieval fails
    func getTasks(for profileId: String, userId: String) async throws -> [Task]
    
    /// Retrieves currently active care tasks generating SMS reminders to elderly users
    /// 
    /// Loads only active tasks that are currently sending SMS reminders, excluding
    /// paused, archived, or completed tasks for family dashboard focus.
    ///
    /// - Parameter userId: Family user managing the active care tasks
    /// - Returns: Array of active care tasks generating SMS reminders
    /// - Throws: DatabaseError if data retrieval fails
    func getActiveTasks(for userId: String) async throws -> [Task]
    
    /// Retrieves care tasks scheduled for specific date across all elderly profiles
    /// 
    /// Loads date-specific task schedule for family daily coordination and
    /// oversight dashboard, including timezone-adjusted scheduling.
    ///
    /// - Parameter date: Target date for care task scheduling
    /// - Parameter userId: Family user managing the scheduled tasks
    /// - Returns: Array of care tasks scheduled for the specified date
    /// - Throws: DatabaseError if data retrieval fails
    func getTasksScheduledFor(date: Date, userId: String) async throws -> [Task]
    
    /// Updates care task with scheduling changes and completion tracking modifications
    /// 
    /// Modifies task details, scheduling, or requirements while maintaining SMS
    /// reminder coordination and family synchronization across devices.
    ///
    /// - Parameter task: Updated care task with modified scheduling or requirements
    /// - Throws: DatabaseError if update operation fails
    /// - Note: Schedule changes trigger SMS reminder rescheduling
    func updateTask(_ task: Task) async throws
    
    /// Permanently removes care task and associated SMS reminder scheduling
    ///
    /// Deletes care task along with SMS responses and reminder schedules while
    /// maintaining analytics data integrity for family care pattern analysis.
    ///
    /// - Parameter taskId: Unique identifier for the care task to delete
    /// - Parameter userId: Family user ID owning the task
    /// - Parameter profileId: Elderly profile ID associated with the task
    /// - Throws: DatabaseError if deletion fails or task has active dependencies
    /// - Important: Also cancels pending SMS reminders to elderly person
    func deleteTask(_ taskId: String, userId: String, profileId: String) async throws
    
    /// Archives completed or discontinued care task while preserving analytics data
    ///
    /// Moves task to archived status for historical reference while stopping
    /// active SMS reminders and removing from family active task dashboard.
    ///
    /// - Parameter taskId: Unique identifier for the care task to archive
    /// - Throws: DatabaseError if archiving operation fails
    /// - Note: Archived tasks retain completion history for family care analytics
    func archiveTask(_ taskId: String) async throws

    /// Observes real-time task updates across all user profiles for multi-device sync
    ///
    /// Provides Combine publisher for Firebase snapshot listener on habits collection group.
    /// Enables real-time synchronization where changes on Device A appear on Device B instantly.
    ///
    /// - Parameter userId: Family user ID whose tasks to observe
    /// - Returns: Publisher emitting task arrays on each Firestore update
    func observeUserTasks(_ userId: String) -> AnyPublisher<[Task], Error>

    /// Observes real-time profile updates for multi-device sync and confirmation tracking
    ///
    /// Provides Combine publisher for Firebase snapshot listener on elderly profiles.
    /// Tracks confirmation status changes when elderly user replies to SMS.
    ///
    /// - Parameter userId: Family user ID whose profiles to observe
    /// - Returns: Publisher emitting profile arrays on each Firestore update
    func observeUserProfiles(_ userId: String) -> AnyPublisher<[ElderlyProfile], Error>

    /// Observes real-time gallery event updates for multi-device sync and webhook integration
    ///
    /// Provides Combine publisher for Firebase snapshot listener on gallery events.
    /// Tracks new events created by Twilio webhook when elderly user replies to SMS.
    ///
    /// - Parameter userId: Family user ID whose gallery events to observe
    /// - Returns: Publisher emitting gallery event arrays on each Firestore update
    func observeUserGalleryEvents(_ userId: String) -> AnyPublisher<[GalleryHistoryEvent], Error>

    // MARK: - SMS Response Tracking and Analysis Operations
    
    /// Records SMS response from elderly family member for task completion tracking
    /// 
    /// Stores elderly person's SMS response including text, photos, completion status,
    /// and timestamp for family coordination and care adherence analytics.
    ///
    /// - Parameter response: SMS response with completion data and elderly context
    /// - Throws: DatabaseError if response recording fails
    /// - Important: Response creation triggers family notifications and dashboard updates
    func createSMSResponse(_ response: SMSResponse) async throws
    
    /// Retrieves specific SMS response with complete elderly communication context
    /// 
    /// Loads detailed SMS response including text content, photo attachments,
    /// completion status, and timing for family review and care coordination.
    ///
    /// - Parameter responseId: Unique identifier for the SMS response
    /// - Returns: Complete SMS response or nil if not found
    /// - Throws: DatabaseError if data retrieval fails
    func getSMSResponse(_ responseId: String) async throws -> SMSResponse?
    
    /// Retrieves SMS responses for specific date across all elderly profiles
    /// 
    /// Loads daily SMS activity for family care coordination dashboard,
    /// showing elderly engagement and task completion patterns.
    ///
    /// - Parameter userId: Family user managing the elderly profiles
    /// - Parameter date: Target date for SMS response activity
    /// - Returns: Array of SMS responses for the specified date
    /// - Throws: DatabaseError if data retrieval fails
    func getSMSResponses(for userId: String, date: Date) async throws -> [SMSResponse]
    
    /// Retrieves all SMS responses for specific care task completion tracking
    /// 
    /// Loads complete response history for a care task, including multiple
    /// attempts, partial completions, and final confirmation from elderly person.
    ///
    /// - Parameter taskId: Care task receiving SMS responses
    /// - Returns: Array of SMS responses for the specified task
    /// - Throws: DatabaseError if data retrieval fails
    func getSMSResponses(for taskId: String) async throws -> [SMSResponse]
    
    /// Retrieves SMS responses from specific elderly profile with family context
    /// 
    /// Loads communication history with a specific elderly family member,
    /// including task responses and profile confirmation exchanges.
    ///
    /// - Parameter profileId: Elderly profile sending SMS responses
    /// - Parameter userId: Family user managing the elderly profile
    /// - Returns: Array of SMS responses from the specified elderly profile
    /// - Throws: DatabaseError if data retrieval fails
    func getSMSResponses(for profileId: String, userId: String) async throws -> [SMSResponse]
    
    /// Retrieves most recent SMS responses for family dashboard activity feed
    /// 
    /// Loads latest elderly SMS activity across all profiles for real-time
    /// family coordination and engagement monitoring.
    ///
    /// - Parameter userId: Family user managing elderly profiles
    /// - Parameter limit: Maximum number of recent responses to retrieve
    /// - Returns: Array of recent SMS responses sorted by timestamp
    /// - Throws: DatabaseError if data retrieval fails
    func getRecentSMSResponses(for userId: String, limit: Int) async throws -> [SMSResponse]
    
    /// Retrieves completed SMS responses with photo attachments for gallery display
    /// 
    /// Loads SMS responses that include photo data for the elderly care gallery,
    /// showing visual proof of task completion across all family elderly profiles.
    ///
    /// - Returns: Array of completed SMS responses with photo data
    /// - Throws: DatabaseError if data retrieval fails
    func getCompletedResponsesWithPhotos() async throws -> [SMSResponse]
    
    /// Retrieves SMS confirmation responses for elderly profile setup validation
    /// 
    /// Loads confirmation exchange history for elderly profile setup,
    /// including YES/NO responses and setup completion status.
    ///
    /// - Parameter profileId: Elderly profile undergoing SMS confirmation
    /// - Returns: Array of confirmation SMS responses
    /// - Throws: DatabaseError if data retrieval fails
    func getConfirmationResponses(for profileId: String) async throws -> [SMSResponse]
    
    /// Updates SMS response with additional processing or correction information
    /// 
    /// Modifies response details, completion status, or processing metadata
    /// while maintaining elderly communication history and family coordination.
    ///
    /// - Parameter response: Updated SMS response with modified information
    /// - Throws: DatabaseError if update operation fails
    func updateSMSResponse(_ response: SMSResponse) async throws
    
    /// Removes SMS response while preserving elderly communication privacy
    /// 
    /// Deletes specific SMS response for privacy or data correction purposes
    /// while maintaining care analytics and family coordination integrity.
    ///
    /// - Parameter responseId: Unique identifier for the SMS response to delete
    /// - Throws: DatabaseError if deletion fails
    /// - Note: Deletion may impact care completion statistics and analytics
    func deleteSMSResponse(_ responseId: String) async throws
    
    // MARK: - Gallery History Event Operations

    /// Creates a gallery history event for tracking profile creation and task completion milestones
    ///
    /// Records significant events in the family care coordination history, including profile
    /// confirmations and task completions, for display in the gallery timeline.
    ///
    /// - Parameter event: Gallery history event with milestone data and family context
    /// - Throws: DatabaseError if event creation fails
    /// - Important: Gallery events provide families with visual timeline of care milestones
    func createGalleryHistoryEvent(_ event: GalleryHistoryEvent) async throws

    /// Retrieves all gallery history events for a specific family user
    ///
    /// Loads complete timeline of care milestones including profile creations and
    /// task completions for family gallery display and coordination history.
    ///
    /// - Parameter userId: Family user managing the care coordination
    /// - Returns: Array of gallery history events sorted by creation date
    /// - Throws: DatabaseError if data retrieval fails
    func getGalleryHistoryEvents(for userId: String) async throws -> [GalleryHistoryEvent]

    // MARK: - Photo Storage Operations

    /// Uploads photo data for SMS response and returns download URL
    ///
    /// Stores photo attachment from elderly SMS response in Firebase Storage
    /// and returns the public download URL for display in gallery and response views.
    ///
    /// - Parameter photoData: JPEG image data to upload
    /// - Parameter responseId: Unique identifier for the SMS response
    /// - Parameter userId: User ID to scope storage path (security: enforces ownership)
    /// - Returns: Public download URL for the uploaded photo
    /// - Throws: DatabaseError if photo upload fails
    func uploadPhoto(_ photoData: Data, for responseId: String, userId: String) async throws -> String

    /// Uploads profile photo and returns download URL
    ///
    /// Stores elderly profile photo in Firebase Storage and returns the public
    /// download URL for display in profile views and gallery.
    ///
    /// - Parameter photoData: JPEG image data to upload
    /// - Parameter profileId: Unique identifier for the elderly profile
    /// - Parameter userId: User ID to scope storage path (prevents cross-user conflicts)
    /// - Returns: Public download URL for the uploaded photo
    /// - Throws: DatabaseError if photo upload fails
    func uploadProfilePhoto(_ photoData: Data, for profileId: String, userId: String) async throws -> String

    /// Deletes photo from Firebase Storage
    ///
    /// Removes photo file from storage using the download URL.
    ///
    /// - Parameter url: Download URL of the photo to delete
    /// - Throws: DatabaseError if photo deletion fails
    func deletePhoto(at url: String) async throws

    /// Retrieves download URL for profile photo if it exists in Storage
    ///
    /// Checks if a profile photo file exists in Firebase Storage and returns
    /// the download URL. Useful for restoring missing photoURL references.
    ///
    /// - Parameter profileId: Unique identifier for the elderly profile
    /// - Parameter userId: User ID to scope storage path (prevents cross-user conflicts)
    /// - Returns: Download URL if photo exists, nil otherwise
    /// - Throws: DatabaseError if storage access fails
    func getProfilePhotoURL(for profileId: String, userId: String) async throws -> String?

    // MARK: - Analytics and Reporting
    func getTaskCompletionStats(for userId: String, from startDate: Date, to endDate: Date) async throws -> TaskCompletionStats
    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics
    func getUserAnalytics(for userId: String) async throws -> UserAnalytics
    
    // MARK: - Batch Operations
    func batchUpdateTasks(_ tasks: [Task]) async throws
    func batchDeleteTasks(_ taskIds: [String]) async throws
    func batchCreateSMSResponses(_ responses: [SMSResponse]) async throws
    
    // MARK: - Search and Filtering
    func searchTasks(query: String, userId: String) async throws -> [Task]
    func getTasksByCategory(_ category: TaskCategory, userId: String) async throws -> [Task]
    func getTasksByStatus(_ status: TaskStatus, userId: String) async throws -> [Task]
    func getOverdueTasks(for userId: String) async throws -> [Task]
    
    // MARK: - Data Synchronization
    func syncUserData(for userId: String) async throws
    func getLastSyncTimestamp(for userId: String) async throws -> Date?
    func updateSyncTimestamp(for userId: String, timestamp: Date) async throws
    
    // MARK: - Backup and Export
    func exportUserData(for userId: String) async throws -> UserDataExport
    func importUserData(_ data: UserDataExport, for userId: String) async throws
}

// MARK: - Analytics Models

struct TaskCompletionStats: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double
    let averageResponseTime: TimeInterval
    let streakCount: Int
    let categoryBreakdown: [TaskCategory: Int]
    let dailyCompletion: [Date: Int]
    let responseTypeBreakdown: [ResponseType: Int]
    
    var completionPercentage: Int {
        return Int(completionRate * 100)
    }
    
    var averageResponseTimeFormatted: String {
        let minutes = Int(averageResponseTime / 60)
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

struct ProfileAnalytics: Codable {
    let profileId: String
    let totalTasks: Int
    let completedTasks: Int
    let averageResponseTime: TimeInterval
    let lastActiveDate: Date?
    let responseRate: Double
    let preferredResponseType: ResponseType?
    let bestPerformingCategory: TaskCategory?
    let worstPerformingCategory: TaskCategory?
    let weeklyTrend: [Double] // Last 7 days completion rates
    
    var isActiveUser: Bool {
        guard let lastActive = lastActiveDate else { return false }
        return Date().timeIntervalSince(lastActive) < 7 * 24 * 60 * 60 // 7 days
    }
    
    var responseRatePercentage: Int {
        return Int(responseRate * 100)
    }
}

struct UserAnalytics: Codable {
    let userId: String
    let totalProfiles: Int
    let activeProfiles: Int
    let totalTasks: Int
    let overallCompletionRate: Double
    let profileAnalytics: [ProfileAnalytics]
    let subscriptionUsage: SubscriptionUsage
    let generatedAt: Date
    
    var mostActiveProfile: ProfileAnalytics? {
        return profileAnalytics.max { $0.responseRate < $1.responseRate }
    }
    
    var averageResponseTime: TimeInterval {
        let totalTime = profileAnalytics.reduce(0) { $0 + $1.averageResponseTime }
        return profileAnalytics.isEmpty ? 0 : totalTime / Double(profileAnalytics.count)
    }
}

struct SubscriptionUsage: Codable {
    let planType: String
    let profilesUsed: Int
    let profilesLimit: Int
    let tasksCreated: Int
    let smssSent: Int
    let storageUsed: Int // in bytes
    let billingPeriodStart: Date
    let billingPeriodEnd: Date
    
    var profilesUtilization: Double {
        return profilesLimit > 0 ? Double(profilesUsed) / Double(profilesLimit) : 0
    }
    
    var isNearingLimits: Bool {
        return profilesUtilization > 0.8
    }
}

struct UserDataExport: Codable {
    let userId: String
    let user: User
    let profiles: [ElderlyProfile]
    let tasks: [Task]
    let responses: [SMSResponse]
    let analytics: UserAnalytics
    let exportedAt: Date
    let formatVersion: String
    
    init(userId: String, user: User, profiles: [ElderlyProfile], tasks: [Task], responses: [SMSResponse], analytics: UserAnalytics) {
        self.userId = userId
        self.user = user
        self.profiles = profiles
        self.tasks = tasks
        self.responses = responses
        self.analytics = analytics
        self.exportedAt = Date()
        self.formatVersion = "1.0"
    }
}

// MARK: - Database Errors
enum DatabaseError: LocalizedError {
    case connectionFailed
    case operationTimeout
    case insufficientPermissions
    case documentNotFound
    case documentAlreadyExists
    case invalidData
    case quotaExceeded
    case networkUnavailable
    case corruptedData
    case syncFailed
    case exportFailed
    case importFailed
    case duplicatePhoneNumber(phoneNumber: String, existingProfileName: String, existingProfileId: String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to the database. Please check your internet connection."
        case .operationTimeout:
            return "Database operation timed out. Please try again."
        case .insufficientPermissions:
            return "You don't have permission to perform this operation."
        case .documentNotFound:
            return "The requested data was not found."
        case .documentAlreadyExists:
            return "This data already exists in the database."
        case .invalidData:
            return "The data format is invalid and cannot be saved."
        case .quotaExceeded:
            return "Database storage quota exceeded. Please contact support."
        case .networkUnavailable:
            return "Network is unavailable. Please check your connection and try again."
        case .corruptedData:
            return "The data appears to be corrupted and cannot be processed."
        case .syncFailed:
            return "Failed to synchronize data. Some changes may not have been saved."
        case .exportFailed:
            return "Failed to export your data. Please try again later."
        case .importFailed:
            return "Failed to import data. Please check the data format and try again."
        case .duplicatePhoneNumber(let phoneNumber, let existingProfileName, _):
            return "This phone number (\(phoneNumber)) is already used by '\(existingProfileName)'. Each phone number can only be used once."
        case .unknownError(let message):
            return "Database error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .networkUnavailable:
            return "Check your internet connection and try again."
        case .operationTimeout:
            return "The operation took too long. Try with a smaller amount of data."
        case .insufficientPermissions:
            return "Please sign out and sign back in, or contact support."
        case .documentNotFound:
            return "The data may have been deleted. Try refreshing the app."
        case .quotaExceeded:
            return "Consider upgrading your subscription or deleting old data."
        case .invalidData:
            return "Check your input and try again."
        case .syncFailed:
            return "Try closing and reopening the app to force a sync."
        case .duplicatePhoneNumber(_, let existingProfileName, _):
            return "Edit the existing profile '\(existingProfileName)' or use a different phone number."
        default:
            return "Please try again later or contact support if the problem persists."
        }
    }
}
