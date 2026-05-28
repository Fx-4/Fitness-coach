import Vision
import CoreImage
import Foundation
import ImageIO

/// Runs VNDetectHumanBodyPoseRequest on camera frames and converts results
/// to a `PoseFeedback` value type before crossing to @MainActor callers.
actor FormAnalysisService {
    static let shared = FormAnalysisService()
    private init() {}

    private var currentExercise: String = ""
    private var smoothedScore: Double?
    private var repPhase: RepPhase = .up

    private enum RepPhase { case up, down }

    func setExercise(_ name: String) {
        currentExercise = name
        repPhase = .up          // reset rep phase when switching exercise
        smoothedScore = nil
    }

    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async -> PoseFeedback {
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try handler.perform([request])
        } catch {
            return PoseFeedback(score: 0, issues: ["Pose detection failed"], landmarks: [:])
        }

        guard let observation = request.results?.first else {
            return PoseFeedback(score: 0, issues: ["No person detected"], landmarks: [:])
        }

        return stabilize(evaluate(observation: observation, exercise: currentExercise))
    }

    // MARK: - Dispatch

    private func evaluate(
        observation: VNHumanBodyPoseObservation,
        exercise: String
    ) -> PoseFeedback {
        let landmarks = extractLandmarks(from: observation)

        switch exercise.lowercased() {
        case "squat":
            return evaluateSquat(landmarks: landmarks)
        case "lunge":
            return evaluateLunge(landmarks: landmarks)
        case "push-up", "push up":
            return evaluatePushUp(landmarks: landmarks)
        case "plank":
            return evaluatePlank(landmarks: landmarks)
        case "deadlift":
            return evaluateDeadlift(landmarks: landmarks)
        case "burpee":
            return evaluateBurpee(landmarks: landmarks)
        default:
            return evaluateGenericPosture(landmarks: landmarks)
        }
    }

    // MARK: - Landmark extraction

    private func extractLandmarks(
        from observation: VNHumanBodyPoseObservation
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var result: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        let joints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow, .leftWrist, .rightWrist,
            .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        for joint in joints {
            if let point = try? observation.recognizedPoint(joint),
               point.confidence > 0.5 {
                result[joint] = CGPoint(x: point.x, y: point.y)
            }
        }
        return result
    }

    // MARK: - Squat

    private func evaluateSquat(
        landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseFeedback {
        var issues: [String] = []
        var score = 1.0
        var repCompleted = false

        guard
            let leftHip   = landmarks[.leftHip],
            let leftKnee  = landmarks[.leftKnee],
            let leftAnkle = landmarks[.leftAnkle]
        else {
            return PoseFeedback(score: 0.5, issues: ["Lower body not fully visible"], landmarks: landmarks)
        }

        let kneeAngle = angle(a: leftHip, vertex: leftKnee, b: leftAnkle)

        // Rep: descend below 105°, then rise above 140°  (forgiving for beginners)
        if kneeAngle < 105 && repPhase == .up  { repPhase = .down }
        if kneeAngle > 140 && repPhase == .down { repPhase = .up; repCompleted = true }

        if kneeAngle > 105 && repPhase == .up {
            issues.append("Squat deeper — aim for 90° knee angle")
            score -= 0.2
        }

        if let leftShoulder = landmarks[.leftShoulder] {
            let torsoLean = abs(leftShoulder.x - leftHip.x)
            if torsoLean > 0.15 {
                issues.append("Keep chest tall — reduce forward lean")
                score -= 0.15
            }
        }

        return PoseFeedback(score: max(0, score), issues: issues,
                            landmarks: landmarks, repCompleted: repCompleted)
    }

    // MARK: - Lunge

    private func evaluateLunge(
        landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseFeedback {
        var issues: [String] = []
        var score = 1.0
        var repCompleted = false

        guard
            let leftHip   = landmarks[.leftHip],
            let leftKnee  = landmarks[.leftKnee],
            let leftAnkle = landmarks[.leftAnkle]
        else {
            return PoseFeedback(score: 0.5, issues: ["Lower body not fully visible"], landmarks: landmarks)
        }

        let kneeAngle = angle(a: leftHip, vertex: leftKnee, b: leftAnkle)

        // Lunge: generous thresholds — movement is harder to camera-detect
        if kneeAngle < 115 && repPhase == .up  { repPhase = .down }
        if kneeAngle > 135 && repPhase == .down { repPhase = .up; repCompleted = true }

        if kneeAngle > 115 && repPhase == .up {
            issues.append("Lunge deeper — front knee to 90°")
            score -= 0.2
        }
        if let leftShoulder = landmarks[.leftShoulder] {
            if abs(leftShoulder.x - leftHip.x) > 0.12 {
                issues.append("Keep torso upright")
                score -= 0.15
            }
        }

        return PoseFeedback(score: max(0, score), issues: issues,
                            landmarks: landmarks, repCompleted: repCompleted)
    }

    // MARK: - Push-Up

    private func evaluatePushUp(
        landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseFeedback {
        var issues: [String] = []
        var score = 1.0
        var repCompleted = false

        guard
            let leftShoulder = landmarks[.leftShoulder],
            let leftElbow    = landmarks[.leftElbow],
            let leftWrist    = landmarks[.leftWrist]
        else {
            return PoseFeedback(score: 0.5, issues: ["Upper body not fully visible"], landmarks: landmarks)
        }

        let elbowAngle = angle(a: leftShoulder, vertex: leftElbow, b: leftWrist)

        // Rep: elbow folds below 80°, then extends past 130°  (slight loosening)
        if elbowAngle < 80  && repPhase == .up  { repPhase = .down }
        if elbowAngle > 130 && repPhase == .down { repPhase = .up; repCompleted = true }

        if elbowAngle > 80 && repPhase == .up {
            issues.append("Lower your chest closer to the ground")
            score -= 0.25
        }
        if let leftHip = landmarks[.leftHip],
           abs(leftHip.y - leftShoulder.y) > 0.1 {
            issues.append("Keep hips level — avoid sagging")
            score -= 0.2
        }

        return PoseFeedback(score: max(0, score), issues: issues,
                            landmarks: landmarks, repCompleted: repCompleted)
    }

    // MARK: - Plank  (time-based, no rep counting)

    private func evaluatePlank(
        landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseFeedback {
        var issues: [String] = []
        var score = 1.0

        guard
            let leftShoulder = landmarks[.leftShoulder],
            let leftHip      = landmarks[.leftHip],
            let leftAnkle    = landmarks[.leftAnkle]
        else {
            return PoseFeedback(score: 0.5, issues: ["Full body not visible"], landmarks: landmarks)
        }

        let bodyLineDeviation = abs(leftHip.y - ((leftShoulder.y + leftAnkle.y) / 2))
        if bodyLineDeviation > 0.08 {
            issues.append("Align hips with shoulders and ankles")
            score -= 0.3
        }

        return PoseFeedback(score: max(0, score), issues: issues,
                            landmarks: landmarks, repCompleted: false)
    }

    // MARK: - Deadlift

    private func evaluateDeadlift(
        landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseFeedback {
        var issues: [String] = []
        var score = 1.0
        var repCompleted = false

        guard
            let leftShoulder = landmarks[.leftShoulder],
            let leftHip      = landmarks[.leftHip],
            let leftKnee     = landmarks[.leftKnee]
        else {
            return PoseFeedback(score: 0.5, issues: ["Full body not visible"], landmarks: landmarks)
        }

        let hipAngle = angle(a: leftShoulder, vertex: leftHip, b: leftKnee)

        // Deadlift: very generous — hip hinge hard to detect from front camera
        if hipAngle < 120 && repPhase == .up  { repPhase = .down }
        if hipAngle > 138 && repPhase == .down { repPhase = .up; repCompleted = true }

        if abs(leftShoulder.x - leftHip.x) > 0.2 {
            issues.append("Keep back straight — avoid rounding")
            score -= 0.3
        }

        return PoseFeedback(score: max(0, score), issues: issues,
                            landmarks: landmarks, repCompleted: repCompleted)
    }

    // MARK: - Burpee

    private func evaluateBurpee(
        landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseFeedback {
        var repCompleted = false

        guard
            let leftShoulder = landmarks[.leftShoulder],
            let leftHip      = landmarks[.leftHip]
        else {
            return PoseFeedback(score: 0.5, issues: ["Full body not visible"], landmarks: landmarks)
        }

        // Burpee: wide range — complex movement, camera angle varies a lot
        let verticalDiff = abs(leftShoulder.y - leftHip.y)

        if verticalDiff < 0.18 && repPhase == .up  { repPhase = .down }
        if verticalDiff > 0.18 && repPhase == .down { repPhase = .up; repCompleted = true }

        return PoseFeedback(score: 0.85, issues: [],
                            landmarks: landmarks, repCompleted: repCompleted)
    }

    // MARK: - Generic posture

    private func evaluateGenericPosture(
        landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseFeedback {
        PoseFeedback(score: 0.8, issues: [], landmarks: landmarks, repCompleted: false)
    }

    // MARK: - Score smoothing

    private func stabilize(_ feedback: PoseFeedback) -> PoseFeedback {
        guard feedback.score > 0 else {
            smoothedScore = nil
            return feedback
        }

        let alpha = 0.35
        let nextScore: Double

        if let smoothedScore {
            nextScore = (smoothedScore * (1.0 - alpha)) + (feedback.score * alpha)
        } else {
            nextScore = feedback.score
        }

        self.smoothedScore = nextScore

        return PoseFeedback(
            score: nextScore,
            issues: feedback.issues,
            landmarks: feedback.landmarks,
            repCompleted: feedback.repCompleted   // pass through unchanged
        )
    }

    // MARK: - Math

    private func angle(a: CGPoint, vertex: CGPoint, b: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = sqrt(v1.dx * v1.dx + v1.dy * v1.dy) * sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        guard mag > 0 else { return 0 }
        return Darwin.acos(max(-1.0, min(1.0, dot / mag))) * (180.0 / Double.pi)
    }
}

// MARK: - PoseFeedback

struct PoseFeedback: Sendable {
    let score: Double          // 0 (poor) – 1 (perfect)
    let issues: [String]
    let landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint]
    var repCompleted: Bool = false   // true for exactly one frame when a rep finishes

    var grade: String {
        switch score {
        case 0.85...: return "Excellent"
        case 0.65...: return "Good"
        case 0.4...:  return "Needs work"
        default:      return "Poor"
        }
    }

    var gradeColor: String {
        switch score {
        case 0.85...: return "green"
        case 0.65...: return "yellow"
        default:      return "red"
        }
    }
}
