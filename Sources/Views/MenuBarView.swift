import SwiftUI

/// The modern window-style popover shown when clicking the menu bar icon.
/// Live-updates every second with animations, active break countdown, and rich controls.
struct MenuBarView: View {
    let timerService: TimerService
    let presenceService: PresenceService
    let streakService: StreakService
    let persistence: PersistenceService

    var body: some View {
        VStack(spacing: 16) {
            // Header: App Title & Status
            HStack {
                Label("Farsight", systemImage: timerService.isBreakActive ? "eye.circle.fill" : "eye.fill")
                    .font(.headline)
                    .foregroundStyle(timerService.isBreakActive ? .green : .primary)

                Spacer()

                if presenceService.isRunning && (presenceService.isSampling || presenceService.isBlinking) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Checking face...")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.green.opacity(0.15)))
                } else if presenceService.isRunning {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill.viewfinder")
                            .font(.caption2)
                        Text(presenceService.faceDetected ? "Present" : "Monitoring")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.secondary.opacity(0.12)))
                }
            }

            // Main Timer Display
            VStack(spacing: 6) {
                Text(timerService.formattedTimeRemaining)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timerColor)

                Text(timerStatusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(timerService.isBreakActive ? .green : (timerService.isPaused ? .orange : .secondary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(timerService.isBreakActive ? Color.green.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            )

            // Streak Card
            let streak = streakService.currentStreak
            HStack {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(streak == 1 ? "1 Day Streak" : "\(streak) Days Streak")
                            .font(.subheadline.bold())
                        Text("Keep up the rhythm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Share") {
                    StreakShareHelper.shareStreak(streakDays: streak)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.08))
            )

            // Primary Action Button
            if timerService.isBreakActive {
                HStack(spacing: 8) {
                    Button(action: {
                        timerService.handleBreakResponse(snoozed: false)
                    }) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)

                    Button("Snooze") {
                        timerService.handleBreakResponse(snoozed: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                Button(action: {
                    timerService.takeBreakNow()
                }) {
                    Label("Take a break now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Settings...") {
                    openSettings()
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: 290)
    }

    private var timerColor: Color {
        if timerService.isBreakActive {
            return .green
        } else if timerService.isPaused {
            return .secondary
        } else {
            return .primary
        }
    }

    private var timerStatusSubtitle: String {
        if timerService.isBreakActive {
            return "👀 Look 20 feet away!"
        } else if timerService.isPaused {
            return "Paused — away from screen"
        } else {
            return "Until \(persistence.settings.breakDurationSeconds)-second break"
        }
    }

    private func openSettings() {
        SettingsWindowManager.shared.show(
            persistence: persistence,
            presenceService: presenceService
        )
    }
}
