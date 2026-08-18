import Foundation

/// User-configurable settings for break reminders.
/// Persisted as a single JSON blob in UserDefaults.
struct BreakSettings: Codable, Equatable, Sendable {
    var intervalMinutes: Int = 20
    var breakDurationSeconds: Int = 20
    var idlePauseEnabled: Bool = true
    var idleThresholdSeconds: Int = 60 // Default 1 min for responsive idle pause
    var presenceDetectionEnabled: Bool = false
    var soundEnabled: Bool = true
    var notificationsEnabled: Bool = true // Optional macOS banner notifications
    var notchHUDEnabled: Bool = true // Notch / Island break animation HUD
    var launchAtLogin: Bool = true
    var snoozeMinutes: Int = 5

    // Migration helper for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case intervalMinutes, breakDurationSeconds, idlePauseEnabled
        case idleThresholdSeconds, idleThresholdMinutes
        case presenceDetectionEnabled, soundEnabled, notificationsEnabled
        case notchHUDEnabled, launchAtLogin, snoozeMinutes
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 20
        breakDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .breakDurationSeconds) ?? 20
        idlePauseEnabled = try container.decodeIfPresent(Bool.self, forKey: .idlePauseEnabled) ?? true
        
        if let secs = try container.decodeIfPresent(Int.self, forKey: .idleThresholdSeconds) {
            idleThresholdSeconds = secs
        } else if let mins = try container.decodeIfPresent(Int.self, forKey: .idleThresholdMinutes) {
            idleThresholdSeconds = mins * 60
        } else {
            idleThresholdSeconds = 60
        }
        
        presenceDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .presenceDetectionEnabled) ?? false
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        notchHUDEnabled = try container.decodeIfPresent(Bool.self, forKey: .notchHUDEnabled) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        snoozeMinutes = try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intervalMinutes, forKey: .intervalMinutes)
        try container.encode(breakDurationSeconds, forKey: .breakDurationSeconds)
        try container.encode(idlePauseEnabled, forKey: .idlePauseEnabled)
        try container.encode(idleThresholdSeconds, forKey: .idleThresholdSeconds)
        try container.encode(presenceDetectionEnabled, forKey: .presenceDetectionEnabled)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(notchHUDEnabled, forKey: .notchHUDEnabled)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(snoozeMinutes, forKey: .snoozeMinutes)
    }
}
