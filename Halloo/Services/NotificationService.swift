import Foundation
import UserNotifications

/// Notification permission service implementation
///
/// Handles only permission management for push notifications.
/// See `NotificationServiceProtocol` for architecture details.
class NotificationService: NotificationServiceProtocol {

    func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("❌ Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
