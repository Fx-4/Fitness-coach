import Vision
import CoreImage
import Foundation
import ImageIO

// MARK: - FormAnalysisService
// ─────────────────────────────────────────────────────────────────────────────
// Pipeline (matches lesson slides):
//   Camera frame
//     → VNDetectHumanBodyPoseRequest           (Vision framework)
//     → PoseFeatureExtractor.extract()         (angles, ratios, heights)
//     → SquatFormClassifier.classify()         (for squat exercise)
//     → PoseFeedback                           (score, label, joints for rig)
// ─────────────────────────────────────────────────────────────────────────────

actor FormAnalysisService {
    static let shared = FormAnalysisService()
    private init() {}

    private var currentExercise: String = "Squat"
    private var smoothedScore: Double?
    private var repPhase: RepPhase = .up

    private enum RepPhase { case up, down }

    private let extractor  = PoseFeatureExtractor()
    private let squat      = SquatFormClassifier()

    // Pre-created request — reusing avoids re-allocation each frame
    private let poseRequest = VNDetectHumanBodyPoseRequest()

    func setExercise(_ name: String) {
        currentExercise = name
        repPhase        = .up
        smoothedScore   = nil
    }

    // MARK: - Main entry

    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async -> PoseFeedback {

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation:   orientation,
            options:       [:]
        )

        do {
            try handler.perform([poseRequest])
        } catch {
            return PoseFeedback(score: 0, issues: ["Pose detection failed"], joints: [:])
        }

        guard let observation = poseRequest.results?.first else {
            return PoseFeedback(score: 0, issues: ["No person detected"], joints: [:])
        }

        let (features, joints) = extractor.extract(from: observation)

        let raw = dispatch(exercise: currentExercise, features: features, joints: joints)
        return stabilize(raw)
    }

    // MARK: - Exercise dispatch

    private func dispatch(
        exercise: String,
        features: PoseFeatureExtractor.Features?,
        joints:   [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    ) -> PoseFeedback {
        switch exercise.lowercased() {
        case "squat":                  return evaluateSquat(features: features, joints: joints)
        case "lunge":                  return evaluateLunge(features: features, joints: joints)
        case "push-up", "push up":     return evaluatePushUp(features: features, joints: joints)
        case "plank":                  return evaluatePlank(features: features, joints: joints)
        case "deadlift":               return evaluateDeadlift(features: features, joints: joints)
        case "burpee":                 return evaluateBurpee(features: features, joints: joints)
        default:                       return PoseFeedback(score: 0.8, issues: [], joints: joints)
        }
    }

    // MARK: - Squat (SquatFormClassifier pipeline)

    private func evaluateSquat(
        features: PoseFeatureExtractor.Features?,
        joints:   [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    ) -> PoseFeedback {

        guard let features else {
            return PoseFeedback(
                score: 0.5, issues: ["Lower body not fully visible"], joints: joints,
                classifierLabel: SquatFormClassifier.Label.bodyNotVisible
            )
        }

        let (label, conf) = squat.classify(features: features)

        // Rep counting uses avg knee angle
        var repCompleted = false
        let avgKnee = (features.leftKneeAngle + features.rightKneeAngle) / 2.0
        if avgKnee < 105 && repPhase == .up  { repPhase = .down }
        if avgKnee > 140 && repPhase == .down { repPhase = .up; repCompleted = true }

        switch label {
        case .goodForm:
            return PoseFeedback(
                score: conf, issues: [], joints: joints,
                repCompleted: repCompleted, classifierLabel: label
            )
        case .tooShallow:
            return PoseFeedback(
                score: conf * 0.55,
                issues: ["Squat deeper — aim for 90° knee angle"],
                joints: joints, repCompleted: repCompleted, classifierLabel: label
            )
        case .kneeIssue:
            return PoseFeedback(
                score: conf * 0.50,
                issues: ["Knee alignment — keep knees tracking over toes"],
                joints: joints, repCompleted: repCompleted, classifierLabel: label
            )
        case .lowConfidence:
            return PoseFeedback(
                score: 0.5, issues: ["Move into frame — full body needed"],
                joints: joints, classifierLabel: label
            )
        case .bodyNotVisible:
            return PoseFeedback(
                score: 0.5, issues: ["Lower body not fully visible"],
                joints: joints, classifierLabel: label
            )
        }
    }

    // MARK: - Lunge

    private func evaluateLunge(
        features: PoseFeatureExtractor.Features?,
        joints:   [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    ) -> PoseFeedback {
        var issues: [String] = []; var score = 1.0; var repCompleted = false
        guard let f = features else {
            return PoseFeedback(score: 0.5, issues: ["Lower body not fully visible"], joints: joints)
        }
        let avgKnee = (f.leftKneeAngle + f.rightKneeAngle) / 2.0
        if avgKnee < 115 && repPhase == .up  { repPhase = .down }
        if avgKnee > 135 && repPhase == .down { repPhase = .up; repCompleted = true }
        if avgKnee > 115 && repPhase == .up { issues.append("Lunge deeper — front knee to 90°"); score -= 0.2 }
        if f.spineLean > 0.12 { issues.append("Keep torso upright"); score -= 0.15 }
        return PoseFeedback(score: max(0, score), issues: issues,
                            joints: joints, repCompleted: repCompleted)
    }

    // MARK: - Push-Up

    private func evaluatePushUp(
        features: PoseFeatureExtractor.Features?,
        joints:   [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    ) -> PoseFeedback {
        var issues: [String] = []; var score = 1.0; var repCompleted = false
        guard let f = features else {
            return PoseFeedback(score: 0.5, issues: ["Upper body not fully visible"], joints: joints)
        }
        let avgElbow = (f.leftElbowAngle + f.rightElbowAngle) / 2.0
        if avgElbow < 80  && repPhase == .up  { repPhase = .down }
        if avgElbow > 130 && repPhase == .down { repPhase = .up; repCompleted = true }
        if avgElbow > 80 && repPhase == .up { issues.append("Lower chest closer to ground"); score -= 0.25 }
        if f.spineLean > 0.10 { issues.append("Keep hips level — avoid sagging"); score -= 0.2 }
        return PoseFeedback(score: max(0, score), issues: issues,
                            joints: joints, repCompleted: repCompleted)
    }

    // MARK: - Plank

    private func evaluatePlank(
        features: PoseFeatureExtractor.Features?,
        joints:   [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    ) -> PoseFeedback {
        var issues: [String] = []; var score = 1.0
        guard let f = features else {
            return PoseFeedback(score: 0.5, issues: ["Full body not visible"], joints: joints)
        }
        let bodyLineDev = abs(f.hipHeight - ((f.shoulderHeight + 0.05) / 2))
        if bodyLineDev > 0.08 { issues.append("Align hips with shoulders and ankles"); score -= 0.3 }
        if f.spineLean > 0.08 { issues.append("Keep body in a straight line"); score -= 0.2 }
        return PoseFeedback(score: max(0, score), issues: issues, joints: joints)
    }

    // MARK: - Deadlift

    private func evaluateDeadlift(
        features: PoseFeatureExtractor.Features?,
        joints:   [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    ) -> PoseFeedback {
        var issues: [String] = []; var score = 1.0; var repCompleted = false
        guard let f = features else {
            return PoseFeedback(score: 0.5, issues: ["Full body not visible"], joints: joints)
        }
        let avgHip = (f.leftHipAngle + f.rightHipAngle) / 2.0
        if avgHip < 120 && repPhase == .up  { repPhase = .down }
        if avgHip > 138 && repPhase == .down { repPhase = .up; repCompleted = true }
        if f.spineLean > 0.20 { issues.append("Keep back straight — avoid rounding"); score -= 0.3 }
        return PoseFeedback(score: max(0, score), issues: issues,
                            joints: joints, repCompleted: repCompleted)
    }

    // MARK: - Burpee

    private func evaluateBurpee(
        features: PoseFeatureExtractor.Features?,
        joints:   [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    ) -> PoseFeedback {
        var repCompleted = false
        guard let f = features else {
            return PoseFeedback(score: 0.5, issues: ["Full body not visible"], joints: joints)
        }
        let vertDiff = abs(f.shoulderHeight - f.hipHeight)
        if vertDiff < 0.18 && repPhase == .up  { repPhase = .down }
        if vertDiff > 0.18 && repPhase == .down { repPhase = .up; repCompleted = true }
        return PoseFeedback(score: 0.85, issues: [], joints: joints, repCompleted: repCompleted)
    }

    // MARK: - Score smoothing (exponential moving average)

    private func stabilize(_ fb: PoseFeedback) -> PoseFeedback {
        guard fb.score > 0 else { smoothedScore = nil; return fb }
        let alpha = 0.35
        let next: Double
        if let prev = smoothedScore {
            next = prev * (1 - alpha) + fb.score * alpha
        } else {
            next = fb.score
        }
        smoothedScore = next
        return PoseFeedback(score: next, issues: fb.issues, joints: fb.joints,
                            repCompleted: fb.repCompleted, classifierLabel: fb.classifierLabel)
    }
}

// MARK: - PoseFeedback

struct PoseFeedback: Sendable {
    let score:          Double      // 0 (poor) – 1 (perfect)
    let issues:         [String]
    /// All visible joints — used for skeleton rig and feature extraction
    let joints:         [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData]
    var repCompleted:   Bool = false
    /// Non-nil for Squat; comes from SquatFormClassifier
    var classifierLabel: SquatFormClassifier.Label? = nil

    // Backwards-compat shortcut for landmark CGPoints
    var landmarks: [VNHumanBodyPoseObservation.JointName: CGPoint] {
        joints.mapValues { $0.point }
    }

    var grade: String {
        switch score {
        case 0.85...: return "Excellent"
        case 0.65...: return "Good"
        case 0.40...: return "Needs work"
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
