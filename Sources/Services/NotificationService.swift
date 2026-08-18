import Foundation
import AppKit
import UserNotifications

/// Handles local notification delivery, sounds, and action responses for break reminders.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let categoryIdentifier = "BREAK_REMINDER"
    private let snoozeActionIdentifier = "SNOOZE_ACTION"
    private let doneActionIdentifier = "DONE_ACTION"

    /// Callback for when the user responds to a notification.
    var onBreakResponse: ((_ snoozed: Bool) -> Void)?

    override init() {
        super.init()
        setupNotificationCategories()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Setup

    private func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze",
            options: []
        )
        let doneAction = UNNotificationAction(
            identifier: doneActionIdentifier,
            title: "Done",
            options: .destructive
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [doneAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Request notification permission. Called once at startup.
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                print("Farsight: Notification permission denied.")
            }
        } catch {
            print("Farsight: Error requesting notification permission: \(error)")
        }
    }

    // MARK: - Sound alerts

    func playBreakStartSound() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    func playBreakCompleteSound() {
        if let sound = NSSound(named: "Ping") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    // MARK: - Send

    func sendBreakNotification(soundEnabled: Bool, durationSeconds: Int) {
        if soundEnabled {
            playBreakStartSound()
        }

        let content = UNMutableNotificationContent()
        content.title = "Time for a 20-20-20 break"
        content.body = "Look at something 20 feet away for \(durationSeconds) seconds. Your eyes will thank you."
        content.categoryIdentifier = categoryIdentifier
        if soundEnabled {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Farsight: Failed to deliver notification: \(error)")
            }
        }
    }

    func sendBreakCompletedNotification(soundEnabled: Bool) {
        if soundEnabled {
            playBreakCompleteSound()
        }

        let content = UNMutableNotificationContent()
        content.title = "Break complete"
        content.body = "Great job protecting your eyes. Back to work!"
        if soundEnabled {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let snoozed: Bool
        switch response.actionIdentifier {
        case snoozeActionIdentifier:
            snoozed = true
        case doneActionIdentifier:
            snoozed = false
        case UNNotificationDefaultActionIdentifier:
            snoozed = false
        default:
            snoozed = false
        }

        await MainActor.run {
            onBreakResponse?(snoozed)
        }
    }
}
