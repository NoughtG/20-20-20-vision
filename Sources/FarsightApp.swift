import SwiftUI

@main
struct FarsightApp: App {
    @State private var persistence = PersistenceService()
    @State private var notificationService = NotificationService()
    @State private var presenceService = PresenceService()
    @State private var streakService: StreakService?
    @State private var timerService: TimerService?

    var body: some Scene {
        MenuBarExtra {
            if let timerService, let streakService {
                MenuBarView(
                    timerService: timerService,
                    presenceService: presenceService,
                    streakService: streakService,
                    persistence: persistence
                )
            } else {
                Text("Starting...")
                    .padding()
                    .onAppear { setup() }
            }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                persistence: persistence,
                presenceService: presenceService
            )
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if presenceService.isBlinking {
            // Animated double-blink during camera presence check
            Image(systemName: presenceService.blinkFrame % 2 == 1 ? "eye.slash" : "eye.fill")
        } else if timerService?.isBreakActive == true {
            Image(systemName: "eye.circle.fill")
        } else {
            Image(systemName: "eye")
        }
    }

    init() {
        // Hide the Dock icon — this app lives in the menu bar only.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func setup() {
        let ss = StreakService(persistence: persistence)
        let ts = TimerService(persistence: persistence, notificationService: notificationService)

        // Wire notification responses back to the timer service
        notificationService.onBreakResponse = { snoozed in
            ts.handleBreakResponse(snoozed: snoozed)
        }

        // Request notification permission
        Task {
            await notificationService.requestPermission()
        }

        // If presence detection is already enabled (persisted setting), start it
        if persistence.settings.presenceDetectionEnabled {
            Task {
                await presenceService.start()
            }
        }

        // Start the countdown
        ts.start()
        streakService = ss
        timerService = ts

        // Keep face detection state in sync with timer service
        syncPresenceState(timerService: ts)
    }

    private func syncPresenceState(timerService: TimerService) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [presenceService] _ in
            Task { @MainActor in
                timerService.faceDetected = presenceService.faceDetected
            }
        }
    }
}
