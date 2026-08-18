import Foundation

/// A single break reminder event, logged each time a notification fires.
struct BreakEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let scheduledAt: Date
    var respondedAt: Date?
    var wasSkipped: Bool
    var pausedSeconds: Int

    init(
        id: UUID = UUID(),
        scheduledAt: Date = Date(),
        respondedAt: Date? = nil,
        wasSkipped: Bool = false,
        pausedSeconds: Int = 0
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.respondedAt = respondedAt
        self.wasSkipped = wasSkipped
        self.pausedSeconds = pausedSeconds
    }
}
