//
//  ViewModelExtensions.swift
//  Halloo
//
//  Created on 2025-10-28
//  AppState CRUD Protocol Extensions - Eliminates 80+ lines of duplicate code
//

import Foundation

// MARK: - AppState Integration Protocol
/// Protocol for ViewModels that interact with AppState
///
/// Provides unified CRUD operations with consistent logging and error handling.
/// Eliminates duplicate `appState?.addX()` calls across ViewModels.
///
/// **Usage:**
/// ```swift
/// extension ProfileViewModel: AppStateViewModel {}
///
/// // In ViewModel methods:
/// updateProfile(updatedProfile)  // Instead of: appState?.updateProfile(profile) + logging
/// ```
@MainActor
protocol AppStateViewModel: AnyObject {
    var appState: AppState? { get }
}

// MARK: - Profile Operations
extension AppStateViewModel {
    /// Adds a profile to AppState with automatic logging
    ///
    /// - Parameters:
    ///   - profile: The profile to add
    ///   - context: Calling function name (auto-captured via #function)
    @MainActor
    func addProfile(_ profile: ElderlyProfile, context: String = #function) {
        appState?.addProfile(profile)
        AppLogger.success(.profile, "Profile added to AppState: \(profile.name)", context: context)
    }

    /// Updates a profile in AppState with automatic logging
    ///
    /// - Parameters:
    ///   - profile: The profile to update
    ///   - context: Calling function name (auto-captured via #function)
    @MainActor
    func updateProfile(_ profile: ElderlyProfile, context: String = #function) {
        appState?.updateProfile(profile)
        AppLogger.success(.profile, "Profile updated in AppState: \(profile.name)", context: context)
    }

    /// Deletes a profile from AppState with automatic logging
    ///
    /// - Parameters:
    ///   - profileId: The ID of the profile to delete
    ///   - profileName: The name of the profile (for logging)
    ///   - context: Calling function name (auto-captured via #function)
    @MainActor
    func deleteProfile(_ profileId: String, profileName: String, context: String = #function) {
        appState?.deleteProfile(profileId)
        AppLogger.success(.profile, "Profile deleted from AppState: \(profileName)", context: context)
    }
}

// MARK: - Task Operations
extension AppStateViewModel {
    /// Adds a task to AppState with automatic logging
    ///
    /// - Parameters:
    ///   - task: The task to add
    ///   - context: Calling function name (auto-captured via #function)
    @MainActor
    func addTask(_ task: Task, context: String = #function) {
        appState?.addTask(task)
        AppLogger.success(.task, "Task added to AppState: \(task.title)", context: context)
    }

    /// Updates a task in AppState with automatic logging
    ///
    /// - Parameters:
    ///   - task: The task to update
    ///   - context: Calling function name (auto-captured via #function)
    @MainActor
    func updateTask(_ task: Task, context: String = #function) {
        appState?.updateTask(task)
        AppLogger.success(.task, "Task updated in AppState: \(task.title)", context: context)
    }

    /// Deletes a task from AppState with automatic logging
    ///
    /// - Parameters:
    ///   - taskId: The ID of the task to delete
    ///   - taskTitle: The title of the task (for logging)
    ///   - context: Calling function name (auto-captured via #function)
    @MainActor
    func deleteTask(_ taskId: String, taskTitle: String, context: String = #function) {
        appState?.deleteTask(taskId)
        AppLogger.success(.task, "Task deleted from AppState: \(taskTitle)", context: context)
    }
}

// MARK: - Optimistic Update Pattern
extension AppStateViewModel {
    /// Performs an optimistic UI update with automatic rollback on error
    ///
    /// This pattern updates the UI immediately (optimistic), attempts the Firebase operation,
    /// and automatically rolls back the UI if the operation fails.
    ///
    /// **Usage:**
    /// ```swift
    /// await optimisticUpdate(
    ///     updatedTask,
    ///     update: { self.updateTask(updatedTask) },
    ///     rollback: {
    ///         if let original = self.tasks.first(where: { $0.id == updatedTask.id }) {
    ///             self.updateTask(original)
    ///         }
    ///     },
    ///     operation: { try await self.databaseService.updateTask(updatedTask) }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - item: The item being updated (for logging)
    ///   - update: Closure that performs the optimistic UI update
    ///   - rollback: Closure that reverts the UI change on error
    ///   - operation: Async throwing closure that performs the Firebase operation
    func optimisticUpdate<T>(
        _ item: T,
        update: @MainActor () -> Void,
        rollback: @MainActor () -> Void,
        operation: () async throws -> Void
    ) async {
        // Optimistic UI update
        await MainActor.run {
            update()
            AppLogger.verbose(.appState, "Optimistic update applied")
        }

        do {
            // Attempt Firebase sync
            try await operation()
            AppLogger.success(.appState, "Optimistic update confirmed")
        } catch {
            // Rollback on failure
            await MainActor.run {
                rollback()
                AppLogger.warning(.appState, "Optimistic update rolled back - \(error.localizedDescription)")
            }
            // Don't throw - error already handled via rollback
        }
    }
}
