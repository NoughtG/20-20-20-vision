import SwiftUI
import Observation

/// Main application state initialized immediately upon launch.
/// Starts timer, notifications, and presence monitoring without requiring user to open the menu.
@Observable
@MainActor
final class AppState {
    let persistence: PersistenceService
    let notificationService: NotificationService
    let presenceService: PresenceService
    let streakService: StreakService
    let timerService: TimerService

    init() {
        let p = PersistenceService()
        let n = NotificationService()
        let pr = PresenceService()
        let s = StreakService(persistence: p)
        let t = TimerService(persistence: p, notificationService: n)

        self.persistence = p
        self.notificationService = n
        self.presenceService = pr
        self.streakService = s
        self.timerService = t

        // Wire notification responses back to the timer service
        n.onBreakResponse = { [weak t] snoozed in
            t?.handleBreakResponse(snoozed: snoozed)
        }

        // Start countdown timer immediately upon app launch!
        t.start()

        // Request notification permission asynchronously
        Task {
            await n.requestPermission()
        }

        // Start presence detection if enabled in persisted settings
        if p.settings.presenceDetectionEnabled {
            Task {
                await pr.start()
            }
        }

        // Keep face detection state in sync with timer service
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.timerService.faceDetected = self.presenceService.faceDetected
            }
        }
    }
}

@main
struct FarsightApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                timerService: appState.timerService,
                presenceService: appState.presenceService,
                streakService: appState.streakService,
                persistence: appState.persistence
            )
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                persistence: appState.persistence,
                presenceService: appState.presenceService
            )
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if appState.presenceService.isBlinking {
            // Animated double-blink during camera presence check
            Image(systemName: appState.presenceService.blinkFrame % 2 == 1 ? "eye.slash" : "eye.fill")
        } else if appState.timerService.isBreakActive {
            Image(systemName: "eye.circle.fill")
        } else {
            Image(systemName: "eye")
        }
    }

    init() {
        // Hide the Dock icon — this app lives in the menu bar only.
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
