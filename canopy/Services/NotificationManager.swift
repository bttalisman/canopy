import Foundation
import UserNotifications
import SwiftData

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    var deviceToken: String?

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Device Token Registration

    func registerToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        print("[Push] Device token: \(token)")

        // Immediately register with backend using all active events
        registerTokenWithAllEvents()
    }

    /// Register token with all active events so the device receives any push notification.
    /// Called immediately when the token is received, and again from syncReminders with specific event IDs.
    func registerTokenWithAllEvents() {
        guard let token = deviceToken else { return }

        let baseURL = Secrets.canopyAPIBaseURL
        guard !baseURL.isEmpty, baseURL != "YOUR_API_URL_HERE" else { return }
        guard let url = URL(string: "\(baseURL)/api/events") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data, error == nil else { return }

            // Parse event IDs from the public API response
            guard let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            let eventIds = events.compactMap { $0["id"] as? String }

            if !eventIds.isEmpty {
                self?.registerTokenWithBackend(eventIds: eventIds)
            }
        }.resume()
    }

    func registerTokenWithBackend(eventIds: [String]) {
        guard let token = deviceToken else { return }

        let baseURL = Secrets.canopyAPIBaseURL
        guard !baseURL.isEmpty, baseURL != "YOUR_API_URL_HERE" else { return }

        guard let url = URL(string: "\(baseURL)/api/devices/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["deviceToken": token, "eventIds": eventIds]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                print("[Push] Registration error: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("[Push] Registration response: \(http.statusCode)")
            }
        }.resume()
    }

    // MARK: - Permission

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[Notifications] Permission error: \(error.localizedDescription)")
            }
            print("[Notifications] Permission granted: \(granted)")
        }
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    private var quietHoursEnabled: Bool {
        UserDefaults.standard.object(forKey: "quietHoursEnabled") as? Bool ?? false
    }

    private func isInQuietHours(_ date: Date) -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        // Quiet hours: 10 PM (22) to 8 AM
        return hour >= 22 || hour < 8
    }

    // MARK: - Schedule Reminder for a Saved Session

    func scheduleReminder(for item: ScheduleItem) {
        guard isEnabled else { return }
        guard let event = item.event else { return }

        // 10 minutes before start
        let triggerDate = item.startTime.addingTimeInterval(-10 * 60)

        // Don't schedule if it's in the past or during quiet hours
        guard triggerDate > Date() else { return }
        guard !isInQuietHours(triggerDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Starting in 10 minutes"
        content.body = "\(item.title) at \(item.stage?.name ?? event.location)"
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"
        content.userInfo = ["scheduleItemTitle": item.title, "eventName": event.name]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = "session-\(item.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                print("[Notifications] Failed to schedule: \(error.localizedDescription)")
            } else {
                print("[Notifications] Scheduled reminder for '\(item.title)' at \(triggerDate)")
            }
        }
    }

    // MARK: - Remove Reminder

    func removeReminder(for item: ScheduleItem) {
        let id = "session-\(item.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        print("[Notifications] Removed reminder for '\(item.title)'")
    }

    // MARK: - Schedule Conflict Alert

    func scheduleConflictAlert(item1: ScheduleItem, item2: ScheduleItem) {
        guard isEnabled else { return }
        guard !isInQuietHours(Date()) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Schedule Conflict"
        content.body = "\"\(item1.title)\" and \"\(item2.title)\" overlap at \(item1.startTime.formatted(.dateTime.hour().minute()))"
        content.sound = .default
        content.categoryIdentifier = "CONFLICT_ALERT"

        // Fire immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let id = "conflict-\(item1.id.uuidString)-\(item2.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Schedule Event Eve Reminder

    func scheduleEventEveReminder(for event: Event) {
        guard isEnabled else { return }
        // Event eve fires at 6 PM, which is outside quiet hours, but check anyway
        // 6 PM the day before the event starts
        let calendar = Calendar.current
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: event.startDate) else { return }
        let triggerDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayBefore) ?? dayBefore

        guard triggerDate > Date() else { return }
        guard !isInQuietHours(triggerDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(event.name) starts tomorrow!"
        content.body = "At \(event.location). Check your saved sessions."
        content.sound = .default
        content.categoryIdentifier = "EVENT_EVE"

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = "event-eve-\(event.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                print("[Notifications] Failed to schedule event eve: \(error.localizedDescription)")
            } else {
                print("[Notifications] Scheduled eve reminder for '\(event.name)'")
            }
        }
    }

    func removeEventEveReminder(for event: Event) {
        let id = "event-eve-\(event.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Sync All Reminders (call after bookmark changes)

    @MainActor
    func syncReminders(context: ModelContext) {
        // Clear all existing session reminders
        center.getPendingNotificationRequests { [weak self] requests in
            let sessionIds = requests.filter { $0.identifier.hasPrefix("session-") }.map(\.identifier)
            self?.center.removePendingNotificationRequests(withIdentifiers: sessionIds)

            // Re-schedule from saved items
            DispatchQueue.main.async {
                let descriptor = FetchDescriptor<UserSavedItem>()
                guard let savedItems = try? context.fetch(descriptor) else { return }

                var scheduledEvents = Set<UUID>()

                for saved in savedItems {
                    guard let item = saved.scheduleItem, !item.isCancelled else { continue }

                    // Schedule session reminder
                    self?.scheduleReminder(for: item)

                    // Schedule event eve reminder (once per event)
                    if let event = item.event, !scheduledEvents.contains(event.id) {
                        self?.scheduleEventEveReminder(for: event)
                        scheduledEvents.insert(event.id)
                    }
                }

                print("[Notifications] Synced \(savedItems.count) reminders")

                // Sync device token with backend for push notifications
                let eventIds = Array(scheduledEvents).map(\.uuidString)
                self?.registerTokenWithBackend(eventIds: eventIds)
            }
        }
    }

    // MARK: - Foreground Notification Display

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
