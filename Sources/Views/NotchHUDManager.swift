import SwiftUI
import AppKit

/// Floating Notch / Island break HUD window displayed at the top of the screen during breaks.
@MainActor
final class NotchHUDManager: NSObject {
    static let shared = NotchHUDManager()

    private var hudPanel: NSPanel?

    func show(timerService: TimerService, persistence: PersistenceService) {
        guard persistence.settings.notchHUDEnabled else { return }

        if let existing = hudPanel {
            existing.orderFrontRegardless()
            return
        }

        let pillWidth: CGFloat = 385
        let pillHeight: CGFloat = 54
        let margin: CGFloat = 16

        // Window rect includes padding for shadow without square clipping
        let windowWidth = pillWidth + (margin * 2)
        let windowHeight = pillHeight + (margin * 2)

        var windowRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let xPos = screenRect.origin.x + (screenRect.width - windowWidth) / 2.0
            let yPos = screenRect.origin.y + screenRect.height - windowHeight - 4
            windowRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        }

        let panel = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Transparent root container view
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor

        // Native AppKit Visual Effect View (True Frosted Glass Capsule)
        let effectView = NSVisualEffectView(frame: NSRect(x: margin, y: margin, width: pillWidth, height: pillHeight))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = pillHeight / 2.0
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1.0
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor

        // Soft outer shadow on the pill layer
        let shadowLayer = CALayer()
        shadowLayer.frame = effectView.frame
        shadowLayer.cornerRadius = pillHeight / 2.0
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = 0.35
        shadowLayer.shadowRadius = 10
        shadowLayer.shadowOffset = CGSize(width: 0, height: -4)
        shadowLayer.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
        rootView.layer?.addSublayer(shadowLayer)

        // Embed SwiftUI Content
        let hudView = NotchHUDView(
            timerService: timerService,
            persistence: persistence
        )
        let hostingView = NSHostingView(rootView: hudView)
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        effectView.addSubview(hostingView)
        rootView.addSubview(effectView)

        panel.contentView = rootView
        panel.orderFrontRegardless()
        self.hudPanel = panel
    }

    func hide() {
        hudPanel?.orderOut(nil)
        hudPanel = nil
    }
}

/// SwiftUI View for the compact, perfectly balanced Notch Break HUD content
struct NotchHUDView: View {
    let timerService: TimerService
    let persistence: PersistenceService

    var body: some View {
        HStack(spacing: 10) {
            // Glowing Eye Indicator
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.22))
                    .frame(width: 32, height: 32)
                Image(systemName: "eye.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }

            // Text & Live Timer Row
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Look 20 feet away")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()

                    Text(timerService.formattedTimeRemaining)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.green.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .fixedSize()
                }

                Text("Relax your eye muscles")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .fixedSize()
            }

            Spacer(minLength: 4)

            // Actions
            HStack(spacing: 5) {
                Button("Done") {
                    timerService.handleBreakResponse(snoozed: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Button("Snooze") {
                    timerService.handleBreakResponse(snoozed: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
