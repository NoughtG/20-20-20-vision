import Foundation
import Observation
import CoreGraphics
import AppKit

/// Core countdown timer with idle-aware pausing, active break duration countdown, Notch HUD support,
/// and screen sleep/wake lifecycle management.
@Observable
@MainActor
final class TimerService {
    // MARK: - Public state

    /// Seconds remaining until next break notification.
    private(set) var secondsRemaining: Int = 0

    /// Seconds remaining in current active break.
    private(set) var breakSecondsRemaining: Int = 0

    /// Whether the countdown is currently paused due to idle/absence.
    private(set) var isPaused: Bool = false

    /// Whether the timer is currently in a snooze countdown.
    private(set) var isSnoozed: Bool = false

    /// Whether the display is currently asleep / locked.
    private(set) var isScreenOff: Bool = false

    /// Total seconds the current interval has spent paused.
    private(set) var currentPausedSeconds: Int = 0

    /// Whether a break is currently active (user is looking away).
    private(set) var isBreakActive: Bool = false

    // MARK: - Dependencies

    private let persistence: PersistenceService
    private let notificationService: NotificationService
    private var timer: Timer?

    /// Tracks if user was away so we can reset interval when face returns.
    private var wasAway: Bool = false

    /// Injected by PresenceService. True if a face is detected.
    var faceDetected: Bool = true {
        didSet {
            handlePresenceStateChange(oldValue: oldValue, newValue: faceDetected)
        }
    }

    init(persistence: PersistenceService, notificationService: NotificationService) {
        self.persistence = persistence
        self.notificationService = notificationService
        resetCountdown()
        setupScreenSleepObservers()
    }

    // MARK: - Timer control

    func start() {
        resetCountdown()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Reset work countdown using latest settings
    func resetCountdown() {
        secondsRemaining = persistence.settings.intervalMinutes * 60
        breakSecondsRemaining = 0
        currentPausedSeconds = 0
        isPaused = false
        isBreakActive = false
        isSnoozed = false
        wasAway = false
        NotchHUDManager.shared.hide()
    }

    /// User requested an immediate break.
    func takeBreakNow() {
        triggerBreak()
    }

    /// Called when the user responds to a break notification.
    func handleBreakResponse(snoozed: Bool) {
        if snoozed {
            isBreakActive = false
            breakSecondsRemaining = 0
            isSnoozed = true
            NotchHUDManager.shared.hide()
            persistence.updateLastEvent { event in
                event.respondedAt = Date()
                event.wasSkipped = true
            }
            // Set snooze countdown (e.g. 5:00) without being clamped by work interval
            secondsRemaining = persistence.settings.snoozeMinutes * 60
        } else {
            completeBreak()
        }
    }

    // MARK: - Presence State Changes

    private func handlePresenceStateChange(oldValue: Bool, newValue: Bool) {
        guard persistence.settings.presenceDetectionEnabled else { return }

        if !newValue {
            // No face detected -> mark away & pause immediately
            wasAway = true
            isPaused = true
        } else if wasAway && newValue {
            // Face returned after being away -> reset interval as requested
            wasAway = false
            isPaused = false
            resetCountdown()
        }
    }

    // MARK: - Screen Sleep & Wake Lifecycle

    private func setupScreenSleepObservers() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenSleep()
            }
        }

        center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenSleep()
            }
        }

        center.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenSleep()
            }
        }

        center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenWake()
            }
        }

        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenWake()
            }
        }

        center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenWake()
            }
        }
    }

    private func handleScreenSleep() {
        isScreenOff = true
        NotchHUDManager.shared.hide()
    }

    private func handleScreenWake() {
        isScreenOff = false
        // When screen wakes up: restart (not pause) countdown from fresh interval
        resetCountdown()
    }

    // MARK: - Private

    private func tick() {
        // Freeze countdown when display is off
        guard !isScreenOff else { return }

        if isBreakActive {
            // Count down the break duration
            breakSecondsRemaining -= 1
            if breakSecondsRemaining <= 0 {
                completeBreak()
            }
            return
        }

        // Only clamp to intervalMinutes when NOT in an active snooze!
        if !isSnoozed {
            let maxSeconds = persistence.settings.intervalMinutes * 60
            if secondsRemaining > maxSeconds {
                secondsRemaining = maxSeconds
            }
        }

        let shouldPause = checkShouldPause()
        isPaused = shouldPause

        if shouldPause {
            currentPausedSeconds += 1
            return
        }

        secondsRemaining -= 1

        if secondsRemaining <= 0 {
            triggerBreak()
        }
    }

    private func triggerBreak() {
        isBreakActive = true
        isSnoozed = false
        breakSecondsRemaining = persistence.settings.breakDurationSeconds

        // Show floating Notch / Island HUD
        NotchHUDManager.shared.show(timerService: self, persistence: persistence)

        // Log the break event
        let event = BreakEvent(
            scheduledAt: Date(),
            pausedSeconds: currentPausedSeconds
        )
        persistence.addEvent(event)

        // Fire notification & sound chime (if enabled)
        let soundEnabled = persistence.settings.soundEnabled
        let duration = persistence.settings.breakDurationSeconds
        
        if soundEnabled {
            notificationService.playBreakStartSound()
        }
        
        if persistence.settings.notificationsEnabled {
            notificationService.sendBreakNotification(
                soundEnabled: soundEnabled,
                durationSeconds: duration
            )
        }

        currentPausedSeconds = 0
    }

    private func completeBreak() {
        isBreakActive = false
        isSnoozed = false
        breakSecondsRemaining = 0
        NotchHUDManager.shared.hide()

        // Mark event as completed
        persistence.updateLastEvent { event in
            event.respondedAt = Date()
            event.wasSkipped = false
        }

        // Play completion chime & notice
        let soundEnabled = persistence.settings.soundEnabled
        if soundEnabled {
            notificationService.playBreakCompleteSound()
        }
        if persistence.settings.notificationsEnabled {
            notificationService.sendBreakCompletedNotification(soundEnabled: soundEnabled)
        }

        // Start next work interval
        secondsRemaining = persistence.settings.intervalMinutes * 60
        currentPausedSeconds = 0
        isPaused = false
    }

    /// Determines if the countdown should pause.
    private func checkShouldPause() -> Bool {
        let settings = persistence.settings

        // 1. Presence Detection Mode (Camera-driven)
        if settings.presenceDetectionEnabled {
            // No face detected -> PAUSE IMMEDIATELY
            if !faceDetected {
                return true
            }
            // Face detected -> user is present -> do NOT pause
            return false
        }

        // 2. Standard Idle Mode (Camera off)
        guard settings.idlePauseEnabled else { return false }
        let idleTime = getIdleTimeSeconds()
        let idleThreshold = Double(settings.idleThresholdSeconds)
        return idleTime > idleThreshold
    }

    /// Returns seconds since last keyboard or mouse input.
    private func getIdleTimeSeconds() -> Double {
        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        let keyIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        let scrollIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .scrollWheel
        )
        let clickIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .leftMouseDown
        )
        return min(mouseIdle, keyIdle, scrollIdle, clickIdle)
    }

    // MARK: - Formatted display

    var formattedTimeRemaining: String {
        if isBreakActive {
            let seconds = max(0, breakSecondsRemaining)
            return String(format: "0:%02d", seconds)
        } else {
            let minutes = max(0, secondsRemaining) / 60
            let seconds = max(0, secondsRemaining) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var statusText: String {
        if isBreakActive {
            return "👀 Look 20 feet away: 0:\(String(format: "%02d", max(0, breakSecondsRemaining)))"
        } else if isPaused {
            return "⏸ Paused (Away)"
        } else if isSnoozed {
            return "💤 Snoozed for \(formattedTimeRemaining)"
        } else {
            return "Next break in \(formattedTimeRemaining)"
        }
    }
}
