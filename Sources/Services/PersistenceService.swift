import Foundation
import Observation

/// Handles persistence of BreakSettings (UserDefaults) and BreakEvent history (JSON file).
@Observable
@MainActor
final class PersistenceService {
    private static let settingsKey = "FarsightBreakSettings"
    private static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Farsight", isDirectory: true)
    }()
    private static let eventsFileURL: URL = {
        appSupportDir.appendingPathComponent("break_events.json")
    }()

    var settings: BreakSettings {
        didSet { saveSettings() }
    }
    private(set) var events: [BreakEvent]

    init() {
        self.settings = Self.loadSettings()
        self.events = Self.loadEvents()
    }

    // MARK: - Settings (UserDefaults)

    private static func loadSettings() -> BreakSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(BreakSettings.self, from: data) else {
            return BreakSettings()
        }
        return decoded
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
    }

    // MARK: - Break Events (JSON file)

    private static func loadEvents() -> [BreakEvent] {
        ensureDirectoryExists()
        guard let data = try? Data(contentsOf: eventsFileURL),
              let decoded = try? JSONDecoder().decode([BreakEvent].self, from: data) else {
            return []
        }
        return decoded
    }

    func addEvent(_ event: BreakEvent) {
        events.append(event)
        saveEvents()
    }

    func updateLastEvent(_ transform: (inout BreakEvent) -> Void) {
        guard !events.isEmpty else { return }
        var last = events[events.count - 1]
        transform(&last)
        events[events.count - 1] = last
        saveEvents()
    }

    private func saveEvents() {
        Self.ensureDirectoryExists()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: Self.eventsFileURL, options: .atomic)
    }

    private static func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
    }
}
