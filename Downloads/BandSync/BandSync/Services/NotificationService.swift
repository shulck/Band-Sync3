import Foundation
import UserNotifications
import SwiftUI

class NotificationService {
    static let shared = NotificationService()

    private init() {
        requestAuthorization()
    }

    // Request permission to send notifications
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }

            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }

    // Check authorization status
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                completion(isAuthorized)
            }
        }
    }

    // Schedule notification for event
    func scheduleEventNotification(for event: Event, reminderTime: ReminderTime) {
        // Cancel all previous notifications for this event
        cancelEventNotifications(for: event.id)

        let center = UNUserNotificationCenter.current()

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event: \(event.title)"
        content.body = "Location: \(event.location)\nTime: \(formatTime(event.date))"
        content.sound = .default
        content.badge = 1

        // Add category for interactive actions
        content.categoryIdentifier = "EVENT"

        // Add event data
        content.userInfo = [
            "eventId": event.id,
            "eventTitle": event.title,
            "eventLocation": event.location
        ]

        // Calculate reminder time
        let triggerDate = calculateNotificationTime(for: event.date, reminderTime: reminderTime)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // Create notification request
        let identifier = "event-\(event.id)-\(reminderTime.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Add notification to notification center
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for event \(event.id) at \(triggerDate)")
            }
        }
    }

    // Cancel notifications for event
    func cancelEventNotifications(for eventId: String) {
        let center = UNUserNotificationCenter.current()

        // Find and remove all notifications for this event
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.filter { $0.identifier.starts(with: "event-\(eventId)") }
                .map { $0.identifier }

            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // Setup notification actions
    func setupNotificationActions() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_EVENT",
            title: "View Details",
            options: .foreground
        )

        let reminderAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind in 30 minutes",
            options: .authenticationRequired
        )

        let category = UNNotificationCategory(
            identifier: "EVENT",
            actions: [viewAction, reminderAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // Helper functions

    // Calculate time for notification
    private func calculateNotificationTime(for eventDate: Date, reminderTime: ReminderTime) -> Date {
        let calendar = Calendar.current

        switch reminderTime {
        case .atTime:
            return eventDate
        case .fifteenMinutes:
            return calendar.date(byAdding: .minute, value: -15, to: eventDate) ?? eventDate
        case .thirtyMinutes:
            return calendar.date(byAdding: .minute, value: -30, to: eventDate) ?? eventDate
        case .oneHour:
            return calendar.date(byAdding: .hour, value: -1, to: eventDate) ?? eventDate
        case .twoHours:
            return calendar.date(byAdding: .hour, value: -2, to: eventDate) ?? eventDate
        case .oneDay:
            return calendar.date(byAdding: .day, value: -1, to: eventDate) ?? eventDate
        case .twoDays:
            return calendar.date(byAdding: .day, value: -2, to: eventDate) ?? eventDate
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: eventDate) ?? eventDate
        }
    }

    // Format time for display in notification
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Reminder time for event
enum ReminderTime: String, CaseIterable, Identifiable {
    case atTime = "At time of event"
    case fifteenMinutes = "15 minutes before"
    case thirtyMinutes = "30 minutes before"
    case oneHour = "1 hour before"
    case twoHours = "2 hours before"
    case oneDay = "1 day before"
    case twoDays = "2 days before"
    case oneWeek = "1 week before"

    var id: String { self.rawValue }
}
