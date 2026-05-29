import Foundation

// MARK: - SquatFormClassifier
// ─────────────────────────────────────────────────────────────────────────────
// Slide: PoseFeatureExtractor → SquatFormClassifier.mlmodel
//         → goodForm / tooShallow / kneeIssue / lowConfidence
//
// Currently rule-based — same input/output contract as a Core ML classifier.
// To replace with a real .mlmodel:
//   1. Train on collected Features vectors labeled with SquatFormLabel
//   2. Export as MLClassifier in Create ML
//   3. Replace classify() body with:
//      let input = SquatFormClassifierInput(
//          leftKneeAngle: features.leftKneeAngle, ...)
//      let output = try model.prediction(input: input)
//      return (SquatFormLabel(rawValue: output.label) ?? .lowConfidence,
//              output.labelProbabilities[output.label] ?? 0)
//
// Input shape:   10 Double features (angles + ratios + heights)
// Output labels: "Good Form" | "Too Shallow" | "Knee Alignment" |
//                "Low Confidence" | "Body Not Visible"
// ─────────────────────────────────────────────────────────────────────────────

struct SquatFormClassifier {

    // MARK: - Output labels

    enum Label: String, Sendable, CaseIterable {
        case goodForm       = "Good Form"
        case tooShallow     = "Too Shallow"
        case kneeIssue      = "Knee Alignment"
        case lowConfidence  = "Low Confidence"
        case bodyNotVisible = "Body Not Visible"

        var systemImage: String {
            switch self {
            case .goodForm:       return "checkmark.circle.fill"
            case .tooShallow:     return "arrow.down.circle.fill"
            case .kneeIssue:      return "exclamationmark.triangle.fill"
            case .lowConfidence:  return "eye.slash"
            case .bodyNotVisible: return "person.slash"
            }
        }

        var color: String {   // matches PoseFeedback.gradeColor convention
            switch self {
            case .goodForm:                      return "green"
            case .tooShallow, .kneeIssue:        return "yellow"
            case .lowConfidence, .bodyNotVisible: return "red"
            }
        }
    }

    // MARK: - Thresholds (tune before replacing with trained .mlmodel)

    private enum T {
        static let minVisibleJoints  = 7        // need most of body visible
        static let minConfidence     = 0.40     // per-joint Vision confidence
        static let goodDepthAngle    = 110.0    // deg — at or below = good depth
        static let shallowAngle      = 128.0    // deg — above = too shallow
        static let kneeAsymmetry     = 18.0     // deg — left/right diff = knee issue
    }

    // MARK: - Classification

    func classify(
        features: PoseFeatureExtractor.Features
    ) -> (label: Label, confidence: Double) {

        // ── Guard: enough visible joints ──────────────────────────────────
        if features.visibleJointCount < T.minVisibleJoints ||
           features.minJointConfidence < T.minConfidence {
            return (.lowConfidence, 0.3)
        }

        let avgKnee = (features.leftKneeAngle + features.rightKneeAngle) / 2.0

        // ── 1. Squat not deep enough ──────────────────────────────────────
        if avgKnee > T.shallowAngle {
            let severity = min(1.0, (avgKnee - T.shallowAngle) / 30.0)
            return (.tooShallow, 0.55 + severity * 0.40)
        }

        // ── 2. Knee alignment issue (asymmetry = valgus / varus) ─────────
        let asymmetry = abs(features.leftKneeAngle - features.rightKneeAngle)
        if asymmetry > T.kneeAsymmetry {
            let severity = min(1.0, asymmetry / 40.0)
            return (.kneeIssue, 0.55 + severity * 0.40)
        }

        // ── 3. Good form ─────────────────────────────────────────────────
        // Confidence scales with depth quality and symmetry
        let depthScore    = max(0, (T.shallowAngle - avgKnee) / T.shallowAngle)
        let symmetryScore = max(0, 1.0 - asymmetry / T.kneeAsymmetry)
        let overall       = depthScore * 0.6 + symmetryScore * 0.4
        return (.goodForm, 0.65 + overall * 0.35)
    }
}
