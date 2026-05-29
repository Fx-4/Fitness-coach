import Vision
import CoreGraphics
import Darwin

// MARK: - PoseFeatureExtractor
// ─────────────────────────────────────────────────────────────────────────────
// Slide: BodyPose → PoseFeatureExtractor → SquatFormClassifier.mlmodel
//
// This layer converts raw VNHumanBodyPoseObservation into a typed Features
// struct.  When you swap in a real .mlmodel, this struct becomes the model's
// MultiArray input — input names, shapes and units are documented here.
// ─────────────────────────────────────────────────────────────────────────────

struct PoseFeatureExtractor {

    // MARK: - Output type (= Core ML model input contract)

    struct Features {
        // ── Joint angles (degrees, 0–180) ────────────────────────────────
        /// hip → knee → ankle
        let leftKneeAngle:    Double
        let rightKneeAngle:   Double
        /// shoulder → hip → knee
        let leftHipAngle:     Double
        let rightHipAngle:    Double
        /// shoulder → elbow → wrist
        let leftElbowAngle:   Double
        let rightElbowAngle:  Double

        // ── Spatial ratios (0–1, normalized to frame height/width) ───────
        /// |shoulder_mid_x – hip_mid_x| — 0 = upright, >0 = leaning
        let spineLean:        Double
        /// Normalized y-position of hip midpoint (Vision y: 0=bottom, 1=top)
        let hipHeight:        Double
        let shoulderHeight:   Double
        /// hipWidth / shoulderWidth — >1 means hips wider than shoulders
        let hipShoulderRatio: Double

        // ── Confidence summary ────────────────────────────────────────────
        let minJointConfidence: Double
        let visibleJointCount:  Int
    }

    // MARK: - Public interface

    /// Returns extracted features (nil if critical joints are missing) AND
    /// a full joint map with coordinates + per-joint confidence for rendering.
    func extract(
        from observation: VNHumanBodyPoseObservation
    ) -> (features: Features?, joints: [VNHumanBodyPoseObservation.JointName: JointData]) {

        // Collect all available joints (accept anything above 10% confidence
        // so the skeleton always draws as much as it can)
        var joints: [VNHumanBodyPoseObservation.JointName: JointData] = [:]
        for name in Self.allJoints {
            if let p = try? observation.recognizedPoint(name), p.confidence > 0.1 {
                joints[name] = JointData(point: CGPoint(x: p.x, y: p.y),
                                         confidence: p.confidence)
            }
        }

        // Critical joints needed for lower-body analysis
        guard
            let lHip   = joints[.leftHip],
            let rHip   = joints[.rightHip],
            let lKnee  = joints[.leftKnee],
            let rKnee  = joints[.rightKnee],
            let lAnkle = joints[.leftAnkle],
            let rAnkle = joints[.rightAnkle]
        else {
            return (nil, joints)
        }

        let lShoulder = joints[.leftShoulder]?.point
        let rShoulder = joints[.rightShoulder]?.point
        let lElbow    = joints[.leftElbow]?.point
        let rElbow    = joints[.rightElbow]?.point
        let lWrist    = joints[.leftWrist]?.point
        let rWrist    = joints[.rightWrist]?.point

        // Angles
        let lKneeAng  = angle(a: lHip.point, v: lKnee.point,  b: lAnkle.point)
        let rKneeAng  = angle(a: rHip.point, v: rKnee.point,  b: rAnkle.point)

        let lHipAng   = lShoulder != nil
            ? angle(a: lShoulder!, v: lHip.point,  b: lKnee.point)  : 180
        let rHipAng   = rShoulder != nil
            ? angle(a: rShoulder!, v: rHip.point,  b: rKnee.point)  : 180

        let lElbowAng = (lShoulder != nil && lElbow != nil && lWrist != nil)
            ? angle(a: lShoulder!, v: lElbow!, b: lWrist!) : 180
        let rElbowAng = (rShoulder != nil && rElbow != nil && rWrist != nil)
            ? angle(a: rShoulder!, v: rElbow!, b: rWrist!) : 180

        // Spatial
        let hipMidX      = (lHip.point.x + rHip.point.x) / 2
        let sMidX        = ((lShoulder?.x ?? hipMidX) + (rShoulder?.x ?? hipMidX)) / 2
        let spineLean    = abs(sMidX - hipMidX)

        let hipHeight    = (lHip.point.y  + rHip.point.y)  / 2
        let shoulderH    = ((lShoulder?.y ?? 0) + (rShoulder?.y ?? 0)) / 2

        let hipW         = abs(lHip.point.x   - rHip.point.x)
        let shoulderW    = abs((lShoulder?.x ?? lHip.point.x) - (rShoulder?.x ?? rHip.point.x))
        let hsRatio      = shoulderW > 0 ? hipW / shoulderW : 1.0

        let minConf  = joints.values.map { Double($0.confidence) }.min() ?? 0
        let visible  = joints.count

        return (
            Features(
                leftKneeAngle:    lKneeAng,
                rightKneeAngle:   rKneeAng,
                leftHipAngle:     lHipAng,
                rightHipAngle:    rHipAng,
                leftElbowAngle:   lElbowAng,
                rightElbowAngle:  rElbowAng,
                spineLean:        spineLean,
                hipHeight:        hipHeight,
                shoulderHeight:   shoulderH,
                hipShoulderRatio: hsRatio,
                minJointConfidence: minConf,
                visibleJointCount: visible
            ),
            joints
        )
    }

    // MARK: - Joint data

    struct JointData {
        let point:      CGPoint
        let confidence: Float
    }

    // MARK: - Helpers

    private static let allJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle
    ]

    private func angle(a: CGPoint, v: CGPoint, b: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - v.x, dy: a.y - v.y)
        let v2 = CGVector(dx: b.x - v.x, dy: b.y - v.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
                * sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        guard mag > 0 else { return 0 }
        return acos(max(-1, min(1, dot / mag))) * (180 / .pi)
    }
}
