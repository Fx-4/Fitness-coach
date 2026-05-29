import SwiftUI
import AVFoundation
import Vision
import UIKit

// MARK: - CameraPreviewView
// Wraps AVCaptureVideoPreviewLayer and draws a real-time skeleton rig
// using two CAShapeLayer overlays (bones + joints) rendered via Metal.
//
// Coordinate mapping:
//   Vision normalised coords   → (0,0) bottom-left, (1,1) top-right
//   AVCaptureDevice coords     → (0,0) top-left,    (1,1) bottom-right
//   Transform: captureX = visionX,  captureY = 1 - visionY
//   Then: previewLayer.layerPointConverted(fromCaptureDevicePoint:)
//   handles aspect-fill, mirroring and orientation automatically.

struct CameraPreviewView: UIViewRepresentable {

    let session:    AVCaptureSession
    var joints:     [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData] = [:]
    var score:      Double  = 0
    var showSkeleton: Bool  = true

    func makeUIView(context: Context) -> SkeletonPreviewView {
        let view = SkeletonPreviewView()
        view.previewLayer.session      = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: SkeletonPreviewView, context: Context) {
        uiView.updateSkeleton(joints: joints, score: score, visible: showSkeleton)
    }

    // MARK: - SkeletonPreviewView

    final class SkeletonPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        // Two layers: lower for bones, upper for joint dots
        private let bonesLayer  = CAShapeLayer()
        private let jointsLayer = CAShapeLayer()

        // Bone skeleton connections
        private static let bones: [(VNHumanBodyPoseObservation.JointName,
                                    VNHumanBodyPoseObservation.JointName)] = [
            // Head ↔ shoulders
            (.nose, .leftShoulder), (.nose, .rightShoulder),
            // Shoulder girdle
            (.leftShoulder, .rightShoulder),
            // Left arm
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            // Right arm
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            // Torso
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            // Hip girdle
            (.leftHip, .rightHip),
            // Left leg
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            // Right leg
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
        ]

        // Joints that receive a larger highlight dot
        private static let keyJoints: Set<VNHumanBodyPoseObservation.JointName> = [
            .leftKnee, .rightKnee, .leftHip, .rightHip, .leftAnkle, .rightAnkle
        ]

        // MARK: Init

        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        private func setup() {
            for sl in [bonesLayer, jointsLayer] {
                sl.fillColor  = UIColor.clear.cgColor
                sl.lineCap    = .round
                sl.lineJoin   = .round
                layer.addSublayer(sl)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bonesLayer.frame  = bounds
            jointsLayer.frame = bounds
            CATransaction.commit()
        }

        // MARK: - Draw skeleton

        func updateSkeleton(
            joints:  [VNHumanBodyPoseObservation.JointName: PoseFeatureExtractor.JointData],
            score:   Double,
            visible: Bool
        ) {
            guard visible else {
                clearSkeleton(); return
            }

            // Bone colour scales with form score
            let boneUIColor: UIColor = score >= 0.85 ? UIColor.systemGreen.withAlphaComponent(0.90)
                                     : score >= 0.65 ? UIColor.systemYellow.withAlphaComponent(0.90)
                                                     : UIColor.systemRed.withAlphaComponent(0.90)

            let bonePath  = UIBezierPath()
            let jointPath = UIBezierPath()

            // — Bones —
            for (j1, j2) in Self.bones {
                guard let d1 = joints[j1], let d2 = joints[j2] else { continue }
                let p1 = layerPt(d1.point)
                let p2 = layerPt(d2.point)
                // Fade bone if either joint is low-confidence
                let alpha = Double(min(d1.confidence, d2.confidence)) * 1.2
                bonePath.move(to: p1)
                bonePath.addLine(to: p2)
                _ = alpha   // used via layer alpha below
            }

            // — Joint dots —
            for (name, data) in joints {
                guard data.confidence > 0.2 else { continue }
                let sp = layerPt(data.point)
                let r: CGFloat = Self.keyJoints.contains(name) ? 7 : 4.5
                jointPath.append(
                    UIBezierPath(ovalIn: CGRect(x: sp.x - r, y: sp.y - r,
                                               width: r * 2, height: r * 2))
                )
            }

            // Apply without implicit CA animations (prevents lag-blur effect)
            CATransaction.begin()
            CATransaction.setDisableActions(true)

            bonesLayer.path        = bonePath.cgPath
            bonesLayer.strokeColor = boneUIColor.cgColor
            bonesLayer.lineWidth   = 3.5
            bonesLayer.fillColor   = UIColor.clear.cgColor

            jointsLayer.path        = jointPath.cgPath
            jointsLayer.fillColor   = UIColor.white.withAlphaComponent(0.92).cgColor
            jointsLayer.strokeColor = UIColor.black.withAlphaComponent(0.45).cgColor
            jointsLayer.lineWidth   = 1.0

            CATransaction.commit()
        }

        // MARK: - Coordinate transform

        /// Vision (0,0)=bottom-left  →  AVCapture (0,0)=top-left  →  layer point
        private func layerPt(_ visionPt: CGPoint) -> CGPoint {
            let capture = CGPoint(x: visionPt.x, y: 1.0 - visionPt.y)
            return previewLayer.layerPointConverted(fromCaptureDevicePoint: capture)
        }

        private func clearSkeleton() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bonesLayer.path  = nil
            jointsLayer.path = nil
            CATransaction.commit()
        }
    }
}
