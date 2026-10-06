import 'dart:ui';

import 'document_quad.dart';

/// Human-readable capture guidance for overlay UI.
enum CaptureFeedback {
  moveCloser,
  moveAway,
  holdSteady,
  straighten,
  goodToCapture,
  noDocument,
}

/// Quality gate result for one camera frame.
class CaptureQuality {
  final CaptureFeedback feedback;
  final bool canCapture;
  final double coverage;
  final double skewDegrees;
  final double stabilityPx;

  const CaptureQuality({
    required this.feedback,
    required this.canCapture,
    required this.coverage,
    required this.skewDegrees,
    required this.stabilityPx,
  });
}

/// Tunable auto-capture policy. All pure Dart — wire any detector.
///
/// [minCoverage]/[maxCoverage]: document must fill enough of the frame
/// but not be cropped. [maxSkewDegrees]: reject tilted shots.
/// [maxMotionPx]: corner displacement between frames. [blurThreshold]:
/// optional 0-1 sharpness from your frame analyzer (1 = sharp).
class CapturePolicy {
  final double minCoverage;
  final double maxCoverage;
  final double maxSkewDegrees;
  final double maxMotionPx;
  final double minQuadScore;
  final double? blurThreshold;

  const CapturePolicy({
    this.minCoverage = 0.15,
    this.maxCoverage = 0.95,
    this.maxSkewDegrees = 12.0,
    this.maxMotionPx = 12.0,
    this.minQuadScore = 0.5,
    this.blurThreshold,
  });

  CaptureQuality evaluate({
    required DocumentQuad? quad,
    required Size imageSize,
    double motionPx = 0.0,
    double? blurScore,
  }) {
    if (quad == null || !quad.isConvex || quad.score < minQuadScore) {
      return const CaptureQuality(
        feedback: CaptureFeedback.noDocument,
        canCapture: false,
        coverage: 0,
        skewDegrees: 999,
        stabilityPx: double.infinity,
      );
    }
    final coverage = quad.coverage(imageSize);
    final skew = quad.skewDegrees;

    CaptureFeedback fb = CaptureFeedback.goodToCapture;
    if (coverage < minCoverage) {
      fb = CaptureFeedback.moveCloser;
    } else if (coverage > maxCoverage) {
      fb = CaptureFeedback.moveAway;
    } else if (motionPx > maxMotionPx) {
      fb = CaptureFeedback.holdSteady;
    } else if (skew > maxSkewDegrees) {
      fb = CaptureFeedback.straighten;
    } else if (blurThreshold != null &&
        blurScore != null &&
        blurScore < blurThreshold!) {
      fb = CaptureFeedback.holdSteady;
    }

    return CaptureQuality(
      feedback: fb,
      canCapture: fb == CaptureFeedback.goodToCapture,
      coverage: coverage,
      skewDegrees: skew,
      stabilityPx: motionPx,
    );
  }
}
