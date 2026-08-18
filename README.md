# Farsight — 20-20-20 Break Reminder for Mac

A native macOS menu bar app enforcing the **20-20-20 rule** (every 20 minutes, look at something 20 feet away for 20 seconds) with intelligent idle and camera presence detection.

---

## Key Features

- **Menu Bar Only:** Lives exclusively in your macOS menu bar with no Dock clutter (`.accessory` activation policy).
- **Idle-Aware Countdown:** Automatically pauses countdown when you are away from keyboard and mouse (`CGEventSource`).
- **Local Face Presence Detection (Opt-in):** Low-frequency camera sampling (1 single frame every 30–60s) via `AVFoundation` and `Vision` (`VNDetectFaceRectanglesRequest`).
  - Distinguishes between "stepped away" vs "reading / watching video with hands off keyboard".
  - **100% Private:** Frames are processed locally in memory and immediately discarded. Never recorded, stored, or transmitted anywhere.
- **Gentle Notifications:** Non-intrusive `UserNotifications` with quick **Done** and **Snooze** actions.
- **Streak Tracking:** Computes daily streaks of completed breaks.
- **Shareable Streak Image:** Render and share your streak card via the native macOS share sheet.
- **Configurable Settings:** Custom break intervals, break duration, snooze length, sound alert toggle, and launch-at-login.

---

## How to Build & Run

### Prerequisites
- macOS 14 (Sonoma) or later
- Swift 6+ (Command Line Tools or Xcode)

### Run App
To build into a proper macOS `.app` bundle and launch:
```bash
cd Farsight
./build-app.sh
open Farsight.app
```

---

## Architecture & Data Storage

- **Language & Frameworks:** Swift 6, SwiftUI, Observation (`@Observable`), CoreGraphics, AVFoundation, Vision, UserNotifications, ServiceManagement.
- **Settings Storage:** Persisted to `UserDefaults` under key `FarsightBreakSettings`.
- **Break Events Storage:** Saved to `~/Library/Application Support/Farsight/break_events.json`.
