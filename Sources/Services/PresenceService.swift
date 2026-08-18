import Foundation
import Observation
@preconcurrency import AVFoundation
import Vision
import AppKit

/// Opt-in camera-based face presence detection.
/// Samples a single frame every 60 seconds, runs VNDetectFaceRectanglesRequest,
/// then immediately shuts down the camera and discards the frame.
/// Pauses checks completely when the screen is asleep or locked.
@Observable
@MainActor
final class PresenceService: NSObject {
    // MARK: - Public state

    /// Whether a face was detected in the most recent sample.
    private(set) var faceDetected: Bool = false

    /// User-readable description of last check result.
    private(set) var lastSampleResult: String = "No checks run yet"

    /// Timestamp of the last sample check.
    private(set) var lastSampleTimestamp: Date?

    /// Whether the camera is currently capturing a sample.
    private(set) var isSampling: Bool = false

    /// Whether the menu bar eye icon is animating a blink.
    private(set) var isBlinking: Bool = false

    /// Blink animation frame (0: open, 1: closed, 2: open, 3: closed, 4: open).
    private(set) var blinkFrame: Int = 0

    /// Whether the service is actively running.
    private(set) var isRunning: Bool = false

    /// Whether the screen is currently asleep.
    private(set) var isScreenOff: Bool = false

    // MARK: - Private

    private var samplingTimer: Timer?
    private var activeDelegate: PhotoCaptureDelegate?

    override init() {
        super.init()
        setupScreenSleepObservers()
    }

    // MARK: - Permission

    /// Request camera access. Returns true if granted.
    static func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Start / Stop

    func start() async {
        guard !isRunning else { return }

        let granted = await Self.requestCameraPermission()
        guard granted else {
            print("Farsight: Camera permission not granted for presence detection.")
            lastSampleResult = "Camera permission denied"
            return
        }

        isRunning = true
        scheduleSample(initialDelay: 1.5)
    }

    func stop() {
        samplingTimer?.invalidate()
        samplingTimer = nil
        activeDelegate = nil
        isRunning = false
        isSampling = false
        isBlinking = false
        blinkFrame = 0
        faceDetected = false
        lastSampleResult = "Disabled"
    }

    /// Trigger an immediate manual presence check (useful for testing in Settings).
    func testPresenceNow() {
        guard !isScreenOff else { return }
        guard isRunning else {
            Task {
                await start()
                takeSingleSnapshot()
            }
            return
        }
        takeSingleSnapshot()
    }

    // MARK: - Screen Sleep & Wake Observers

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
        samplingTimer?.invalidate()
        samplingTimer = nil
        isSampling = false
    }

    private func handleScreenWake() {
        isScreenOff = false
        if isRunning {
            scheduleSample(initialDelay: 2.0)
        }
    }

    // MARK: - Sampling (Fixed 60-second Interval)

    private func scheduleSample(initialDelay: Double? = nil) {
        guard isRunning, !isScreenOff else { return }
        samplingTimer?.invalidate()

        let interval = initialDelay ?? 60.0 // Exactly 60 seconds
        samplingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.takeSingleSnapshot()
            }
        }
    }

    private func takeSingleSnapshot() {
        guard isRunning || !lastSampleResult.isEmpty, !isSampling, !isScreenOff else { return }

        isSampling = true
        triggerBlinkAnimation()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let session = AVCaptureSession()
            session.sessionPreset = .photo

            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                Task { @MainActor in
                    self?.handleSampleResult(faceDetected: false, errorMessage: "No camera found")
                }
                return
            }
            session.addInput(input)

            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                Task { @MainActor in
                    self?.handleSampleResult(faceDetected: false, errorMessage: "Capture output failed")
                }
                return
            }
            session.addOutput(output)

            session.startRunning()

            // Allow camera sensor 400ms to adjust auto-exposure and white balance
            Thread.sleep(forTimeInterval: 0.4)

            let delegate = PhotoCaptureDelegate { detected in
                // IMMEDIATELY stop session to extinguish camera indicator LED
                session.stopRunning()
                Task { @MainActor in
                    self?.handleSampleResult(faceDetected: detected, errorMessage: nil)
                }
            }

            Task { @MainActor in
                self?.activeDelegate = delegate
            }

            let settings = AVCapturePhotoSettings()
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    /// Triggers a visible double-blink animation in the menu bar icon.
    private func triggerBlinkAnimation() {
        isBlinking = true
        blinkFrame = 0

        Task {
            for frame in 1...4 {
                try? await Task.sleep(nanoseconds: 140_000_000)
                self.blinkFrame = frame
            }
            try? await Task.sleep(nanoseconds: 140_000_000)
            self.isBlinking = false
            self.blinkFrame = 0
        }
    }

    private func handleSampleResult(faceDetected: Bool, errorMessage: String?) {
        self.faceDetected = faceDetected
        self.isSampling = false
        self.activeDelegate = nil
        self.lastSampleTimestamp = Date()

        if let error = errorMessage {
            self.lastSampleResult = error
        } else {
            self.lastSampleResult = faceDetected ? "Face detected ✓" : "No face detected ✗"
        }

        if isRunning, !isScreenOff {
            scheduleSample()
        }
    }
}

// MARK: - Photo Capture Delegate

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Bool) -> Void

    init(completion: @escaping @Sendable (Bool) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            print("Farsight: Photo capture error: \(error)")
            completion(false)
            return
        }

        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3

        if let cgImage = photo.cgImageRepresentation() {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let faces = request.results ?? []
                completion(!faces.isEmpty)
            } catch {
                print("Farsight: Vision face detection error: \(error)")
                completion(false)
            }
        } else if let pixelBuffer = photo.pixelBuffer {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
                let faces = request.results ?? []
                completion(!faces.isEmpty)
            } catch {
                print("Farsight: Vision face detection error: \(error)")
                completion(false)
            }
        } else {
            completion(false)
        }
    }
}
