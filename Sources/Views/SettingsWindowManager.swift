import SwiftUI
import AppKit

/// Manages the presentation and lifecycle of the Settings window.
/// Automatically dismisses open MenuBarExtra popovers when opened,
/// and auto-closes whenever the user taps/clicks outside the window.
@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()

    private var window: NSWindow?

    func show(persistence: PersistenceService, presenceService: PresenceService) {
        // Dismiss any open MenuBarExtra popover windows
        for w in NSApp.windows where w !== self.window {
            let className = w.className
            if className.contains("MenuBarExtra") || className.contains("Popover") || className.contains("Panel") {
                w.orderOut(nil)
            }
        }

        if let existingWindow = window {
            existingWindow.center()
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            persistence: persistence,
            presenceService: presenceService
        )
        .padding()

        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Farsight Settings"
        newWindow.styleMask = [.titled, .closable]
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.delegate = self
        
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    /// Auto-close the settings window whenever user clicks away / switches context
    func windowDidResignKey(_ notification: Notification) {
        window?.orderOut(nil)
        window = nil
    }
}
