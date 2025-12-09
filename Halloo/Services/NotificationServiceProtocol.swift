import Foundation
import UserNotifications

/// Notification permission service for push notification support
///
/// ## Architecture:
/// - **Local notifications**: NOT used (legacy code removed)
/// - **Push notifications**: Delivered by Cloud Functions when SMS not replied within 30 min
///
/// This service only handles permission management. The actual "no reply" notifications
/// are triggered by the backend (Cloud Functions) which monitors SMS reply status
/// and sends push notifications via FCM when needed.
///
/// ## Flow:
/// 1. SMS sent to elderly recipient via Twilio
/// 2. Cloud Functions monitors for reply (30 min timeout)
/// 3. If no reply → Cloud Functions sends push notification to family user
/// 4. iOS displays the push notification (requires permission granted here)
protocol NotificationServiceProtocol {

    /// Request notification permission from user
    ///
    /// Must be granted for push notifications from Cloud Functions to be displayed.
    /// Called during onboarding and at app launch.
    func requestPermissions() async -> Bool

    /// Check current notification authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus
}
