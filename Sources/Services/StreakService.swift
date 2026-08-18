import Foundation
import Observation

/// Calculates break streaks based on completed (non-skipped) BreakEvents.
@Observable
@MainActor
final class StreakService {
    private let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    /// Number of consecutive days with at least one non-skipped break event.
    var currentStreak: Int {
        calculateStreak(from: persistence.events)
    }

    /// Computes streak count given an array of BreakEvents.
    /// Consecutive days are evaluated backwards starting from today (or yesterday if today has no events yet).
    /// If a day has only skipped events, the streak breaks.
    func calculateStreak(from events: [BreakEvent]) -> Int {
        guard !events.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Group events by day
        var eventsByDay: [Date: [BreakEvent]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.scheduledAt)
            eventsByDay[day, default: []].append(event)
        }

        // Check today's events if any
        var streak = 0
        var checkDate = today

        let todayEvents = eventsByDay[today] ?? []
        if !todayEvents.isEmpty {
            let completedToday = todayEvents.contains { !$0.wasSkipped }
            if completedToday {
                streak += 1
            } else {
                // If today only has skipped events, streak is 0
                return 0
            }
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return streak
            }
            checkDate = yesterday
        } else {
            // Today has no events yet; check starting from yesterday
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            checkDate = yesterday
        }

        // Walk backwards day by day
        while true {
            guard let dayEvents = eventsByDay[checkDate], !dayEvents.isEmpty else {
                // No events on this day: streak chain ends
                break
            }

            let hasCompleted = dayEvents.contains { !$0.wasSkipped }
            if hasCompleted {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                // A day with only skipped events breaks the streak
                break
            }
        }

        return streak
    }
}
