import SwiftUI
import AVFoundation
import Vision
import Combine

@MainActor
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Camera state
    @Published var poseFeedback: PoseFeedback? = nil
    @Published var isCameraRunning = false
    @Published var cameraError: String? = nil
    @Published var selectedExercise: String = "Squat"

    // MARK: - Session state
    @Published var isSessionActive   = false
    @Published var elapsedSeconds    = 0
    @Published var repCount          = 0
    @Published var repsByExercise: [String: Int] = [:]
    @Published var avgFormScore: Double = 0.0
    @Published var showFinishSheet   = false

    let session = AVCaptureSession()
    private let videoOutput       = AVCaptureVideoDataOutput()
    private let analysisService   = FormAnalysisService.shared

    private var timerCancellable: AnyCancellable?
    private var sessionStartDate  = Date()
    private var formScoreSum      = 0.0
    private var formScoreCount    = 0

    // MARK: - Computed

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Rough estimate: ~7 kcal / min for moderate bodyweight work
    var estimatedCalories: Double { Double(elapsedSeconds) / 60.0 * 7.0 }

    // MARK: - Init

    override init() {
        super.init()
        videoOutput.setSampleBufferDelegate(self, queue: .global(qos: .userInitiated))
    }

    // MARK: - Camera lifecycle

    func startCamera() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            cameraError = "Camera access denied. Enable in Settings."
            return
        }

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                cameraError = "Camera access denied."
                return
            }
        }

        await analysisService.setExercise(selectedExercise)
        configureSession()

        let captureSession = session
        Task.detached(priority: .userInitiated) { [weak self] in
            captureSession.startRunning()
            guard let vm = self else { return }
            await MainActor.run { vm.isCameraRunning = true }
        }
    }

    func stopCamera() {
        endSessionTimerIfNeeded()
        let captureSession = session
        Task.detached(priority: .background) { [weak self] in
            captureSession.stopRunning()
            guard let vm = self else { return }
            Task { @MainActor in vm.isCameraRunning = false }
        }
    }

    func updateExercise(_ name: String) {
        selectedExercise = name
        Task { await analysisService.setExercise(name) }
    }

    // MARK: - Session control

    func startSession() {
        isSessionActive   = true
        sessionStartDate  = Date()
        elapsedSeconds    = 0
        repCount          = 0
        repsByExercise    = [:]
        formScoreSum      = 0
        formScoreCount    = 0
        avgFormScore      = 0

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
    }

    func stopForFinish() {
        endSessionTimerIfNeeded()
        showFinishSheet = true
    }

    func saveSession(calories: Double, notes: String, store: AppDataStore) {
        isSessionActive   = false
        showFinishSheet   = false

        let sets: [ExerciseSet] = repsByExercise.compactMap { name, reps in
            guard reps > 0 else { return nil }
            return ExerciseSet(
                exerciseName: name,
                muscleGroup: muscleGroupFor(name),
                reps: reps,
                sets: 1,
                durationSeconds: 0,
                completedAt: Date(),
                formScore: avgFormScore > 0 ? avgFormScore : nil
            )
        }

        var ws = WorkoutSession()
        ws.startedAt            = sessionStartDate
        ws.completedAt          = Date()
        ws.workoutType          = .strength
        ws.activeCaloriesBurned = calories
        ws.durationSeconds      = elapsedSeconds
        ws.notes                = notes
        ws.difficulty           = avgFormScore > 0.85 ? .hard : avgFormScore > 0.6 ? .moderate : .easy
        ws.isCompleted          = true
        ws.exerciseSets         = sets

        store.addSession(ws)

        elapsedSeconds    = 0
        repCount          = 0
        repsByExercise    = [:]
        avgFormScore      = 0
    }

    // MARK: - Private helpers

    private func endSessionTimerIfNeeded() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func muscleGroupFor(_ exercise: String) -> MuscleGroup {
        switch exercise.lowercased() {
        case "squat":           return .quads
        case "lunge":           return .glutes
        case "push-up", "push up": return .chest
        case "plank":           return .core
        case "deadlift":        return .hamstrings
        case "burpee":          return .fullBody
        default:                return .fullBody
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            cameraError = "Could not access front camera."
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video) {
                connection.isVideoMirrored = true
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()
    }

    nonisolated private static func visionOrientation(
        for connection: AVCaptureConnection
    ) -> CGImagePropertyOrientation {
        let mirrored = connection.isVideoMirrored
        switch connection.videoOrientation {
        case .portrait:            return mirrored ? .leftMirrored  : .right
        case .portraitUpsideDown:  return mirrored ? .rightMirrored : .left
        case .landscapeRight:      return mirrored ? .upMirrored    : .down
        case .landscapeLeft:       return mirrored ? .downMirrored  : .up
        @unknown default:          return mirrored ? .leftMirrored  : .right
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let orientation = CameraViewModel.visionOrientation(for: connection)

        Task { [weak self] in
            guard let self else { return }
            let feedback = await analysisService.analyze(pixelBuffer: pixelBuffer,
                                                         orientation: orientation)
            await MainActor.run {
                self.poseFeedback = feedback

                // Rep + score tracking only during active session
                if self.isSessionActive {
                    if feedback.repCompleted {
                        self.repCount += 1
                        self.repsByExercise[self.selectedExercise, default: 0] += 1
                    }
                    if feedback.score > 0 {
                        self.formScoreSum   += feedback.score
                        self.formScoreCount += 1
                        self.avgFormScore    = self.formScoreSum / Double(self.formScoreCount)
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }
}
