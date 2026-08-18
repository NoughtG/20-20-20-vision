import SwiftUI
import ServiceManagement

/// Settings window allowing users to customize break intervals, idle & presence detection, and notifications.
struct SettingsView: View {
    @Bindable var persistence: PersistenceService
    let presenceService: PresenceService

    @State private var showingCameraAlert = false
    @State private var cameraPermissionFailed = false
    @State private var isTestingPresence = false

    var body: some View {
        Form {
            Section("Intervals & Durations") {
                Stepper(value: $persistence.settings.intervalMinutes, in: 1...120) {
                    HStack {
                        Text("Break Interval:")
                        Spacer()
                        Text("\(persistence.settings.intervalMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $persistence.settings.breakDurationSeconds, in: 10...300, step: 5) {
                    HStack {
                        Text("Break Duration:")
                        Spacer()
                        Text("\(persistence.settings.breakDurationSeconds) sec")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $persistence.settings.snoozeMinutes, in: 1...30) {
                    HStack {
                        Text("Snooze Duration:")
                        Spacer()
                        Text("\(persistence.settings.snoozeMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Idle & Presence Detection") {
                Toggle("Pause countdown when idle", isOn: $persistence.settings.idlePauseEnabled)

                if persistence.settings.idlePauseEnabled {
                    Picker("Idle Pause Threshold:", selection: $persistence.settings.idleThresholdSeconds) {
                        Text("15 seconds (Instant test)").tag(15)
                        Text("30 seconds").tag(30)
                        Text("45 seconds").tag(45)
                        Text("1 minute (Recommended)").tag(60)
                        Text("2 minutes").tag(120)
                        Text("3 minutes").tag(180)
                        Text("5 minutes").tag(300)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable presence detection (Camera)", isOn: Binding(
                        get: { persistence.settings.presenceDetectionEnabled },
                        set: { enabled in
                            handlePresenceToggle(enabled)
                        }
                    ))

                    Text("Checks for a face every 30-60 seconds to avoid falsely pausing breaks while you're reading or watching something. Nothing is ever recorded or stored.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if persistence.settings.presenceDetectionEnabled {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Status: \(presenceService.lastSampleResult)")
                                    .font(.caption.bold())
                                    .foregroundStyle(presenceService.faceDetected ? .green : .orange)

                                if let ts = presenceService.lastSampleTimestamp {
                                    Text("Last checked: \(ts.formatted(date: .omitted, time: .standard))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button("Test Camera Now") {
                                presenceService.testPresenceNow()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
            }

            Section("Visual & Audio Alerts") {
                Toggle("Floating Notch / Top Screen Break HUD", isOn: $persistence.settings.notchHUDEnabled)

                Toggle("Send macOS notification banner", isOn: $persistence.settings.notificationsEnabled)

                Toggle("Play sound chime on break start & complete", isOn: $persistence.settings.soundEnabled)

                Toggle("Launch at login", isOn: Binding(
                    get: { persistence.settings.launchAtLogin },
                    set: { enabled in
                        persistence.settings.launchAtLogin = enabled
                        updateLaunchAtLogin(enabled)
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 530)
        .alert("Camera Permission Required", isPresented: $cameraPermissionFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Presence detection requires camera access. Please allow camera permissions in System Settings > Privacy & Security > Camera.")
        }
    }

    private func handlePresenceToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await PresenceService.requestCameraPermission()
                if granted {
                    persistence.settings.presenceDetectionEnabled = true
                    await presenceService.start()
                } else {
                    persistence.settings.presenceDetectionEnabled = false
                    cameraPermissionFailed = true
                }
            }
        } else {
            persistence.settings.presenceDetectionEnabled = false
            presenceService.stop()
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Farsight: Launch at login update error: \(error)")
        }
    }
}
