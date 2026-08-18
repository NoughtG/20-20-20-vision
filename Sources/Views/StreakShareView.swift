import SwiftUI
import AppKit

/// Card view rendered into an image for sharing streaks.
struct StreakShareCard: View {
    let streakDays: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                Text("Farsight")
                    .font(.title2.bold())
            }

            VStack(spacing: 4) {
                Text("\(streakDays)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text(streakDays == 1 ? "day streak" : "days streak")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }

            Text("Protecting my vision with the 20-20-20 rule")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 320, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

/// Helper to render the streak card to an NSImage and trigger sharing.
@MainActor
enum StreakShareHelper {
    static func shareStreak(streakDays: Int) {
        let card = StreakShareCard(streakDays: streakDays)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0 // Retina resolution

        guard let nsImage = renderer.nsImage else {
            print("Farsight: Failed to render streak image.")
            return
        }

        let sharingPicker = NSSharingServicePicker(items: [nsImage, "I'm on a \(streakDays)-day 20-20-20 eye break streak with Farsight!"])
        
        // Present sharing picker near mouse location or key window
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            let mouseLoc = NSEvent.mouseLocation
            let windowRect = window.convertFromScreen(NSRect(origin: mouseLoc, size: .zero))
            sharingPicker.show(relativeTo: windowRect, of: window.contentView ?? NSView(), preferredEdge: .minY)
        } else {
            // Fallback: create temporary invisible view to anchor picker
            let dummyView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            sharingPicker.show(relativeTo: dummyView.bounds, of: dummyView, preferredEdge: .minY)
        }
    }
}
