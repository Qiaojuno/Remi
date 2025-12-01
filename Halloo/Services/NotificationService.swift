import Foundation
import UserNotifications

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

    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        scheduledTime: Date
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(withId id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func getPendingNotificationIds() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }
}
