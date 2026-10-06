import 'dart:math' as math;
import 'dart:ui';

/// A detected document quadrilateral in image pixel coordinates.
///
/// Order: [topLeft, topRight, bottomRight, bottomLeft].
/// This is the core primitive your future `flutter_doc_capture` pub
/// will pass around: detector -> tracker -> warper -> OCR.
class DocumentQuad {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
  final double score;

  const DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    this.score = 1.0,
  });

  List<Offset> get points => [topLeft, topRight, bottomRight, bottomLeft];

  /// Axis-aligned bounding box.
  Rect get bounds {
    final xs = points.map((p) => p.dx);
    final ys = points.map((p) => p.dy);
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  /// Polygon area via shoelace formula. Always >= 0.
  double get area {
    final p = points;
    double sum = 0;
    for (var i = 0; i < 4; i++) {
      final a = p[i];
      final b = p[(i + 1) % 4];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }

  /// Fraction of image area covered by the quad (0-1).
  double coverage(Size imageSize) {
    final img = imageSize.width * imageSize.height;
    if (img <= 0) return 0;
    return (area / img).clamp(0.0, 1.0);
  }

  /// True when polygon is convex (required for a valid perspective warp).
  bool get isConvex {
    final p = points;
    var sign = 0;
    for (var i = 0; i < 4; i++) {
      final a = p[i];
      final b = p[(i + 1) % 4];
      final c = p[(i + 2) % 4];
      final cross =
          (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
      final s = cross.sign.toInt();
      if (s == 0) continue;
      if (sign == 0) {
        sign = s;
      } else if (sign != s) {
        return false;
      }
    }
    return true;
  }

  /// Mean edge skew vs axis-aligned rectangle, in degrees.
  /// 0 = perfectly upright. Useful for "straighten phone" hints.
  double get skewDegrees {
    double angle(Offset a, Offset b) {
      return math.atan2(b.dy - a.dy, b.dx - a.dx) * 180 / math.pi;
    }

    final top = angle(topLeft, topRight);
    final bottom = angle(bottomLeft, bottomRight);
    final left = angle(topLeft, bottomLeft) - 90;
    final right = angle(topRight, bottomRight) - 90;
    return (top.abs() + bottom.abs() + left.abs() + right.abs()) / 4;
  }

  /// Scale quad from one image size to another (e.g. preview -> full res).
  DocumentQuad scale(Size from, Size to) {
    if (from.width <= 0 || from.height <= 0) return this;
    final sx = to.width / from.width;
    final sy = to.height / from.height;
    Offset s(Offset p) => Offset(p.dx * sx, p.dy * sy);
    return DocumentQuad(
      topLeft: s(topLeft),
      topRight: s(topRight),
      bottomRight: s(bottomRight),
      bottomLeft: s(bottomLeft),
      score: score,
    );
  }

  /// Temporal smoothing for live preview (reduces jitter).
  /// [t] 0 = keep this, 1 = snap to [other].
  DocumentQuad lerp(DocumentQuad other, double t) {
    Offset l(Offset a, Offset b) => Offset(
          a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t,
        );
    return DocumentQuad(
      topLeft: l(topLeft, other.topLeft),
      topRight: l(topRight, other.topRight),
      bottomRight: l(bottomRight, other.bottomRight),
      bottomLeft: l(bottomLeft, other.bottomLeft),
      score: score + (other.score - score) * t,
    );
  }

  /// Max corner displacement between frames (pixels). For motion gating.
  double distanceTo(DocumentQuad other) {
    var max = 0.0;
    for (var i = 0; i < 4; i++) {
      final d = (points[i] - other.points[i]).distance;
      if (d > max) max = d;
    }
    return max;
  }

  /// Reorder an unordered 4-point set into TL,TR,BR,BL.
  /// Sum/diff heuristic: TL=min sum, BR=max sum, TR=min diff, BL=max diff.
  factory DocumentQuad.fromUnordered(List<Offset> pts, {double score = 1.0}) {
    assert(pts.length == 4, 'Need exactly 4 points');
    Offset bySum(bool min) => pts.reduce(
        (a, b) => ((a.dx + a.dy) < (b.dx + b.dy)) == min ? a : b);
    Offset byDiff(bool min) => pts.reduce(
        (a, b) => ((a.dx - a.dy) < (b.dx - b.dy)) == min ? a : b);
    return DocumentQuad(
      topLeft: bySum(true),
      bottomRight: bySum(false),
      topRight: byDiff(true),
      bottomLeft: byDiff(false),
      score: score,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => [p.dx, p.dy]).toList(),
        'score': score,
      };

  factory DocumentQuad.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List)
        .map((p) => Offset(
            (p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    return DocumentQuad.fromUnordered(pts,
        score: (json['score'] as num?)?.toDouble() ?? 1.0);
  }
}
