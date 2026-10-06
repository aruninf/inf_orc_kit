import 'dart:math' as math;
import 'dart:ui';

import 'document_quad.dart';

/// Pure-Dart perspective math for document capture.
///
/// No native dependency: compute the destination size + 3x3 homography
/// here, then warp pixels where you like (Canvas, `image` package,
/// platform channel, OpenCV later). Keeps your future pub lightweight.
class Perspective {
  const Perspective._();

  /// Destination size preserving document aspect from edge lengths.
  /// [scale] lets you cap output (e.g. max 2000px side) without distorting.
  static Size destinationSize(DocumentQuad quad, {double scale = 1.0}) {
    double dist(Offset a, Offset b) => (a - b).distance;
    final top = dist(quad.topLeft, quad.topRight);
    final bottom = dist(quad.bottomLeft, quad.bottomRight);
    final left = dist(quad.topLeft, quad.bottomLeft);
    final right = dist(quad.topRight, quad.bottomRight);
    final w = math.max(top, bottom) * scale;
    final h = math.max(left, right) * scale;
    return Size(w.clamp(1.0, 10000.0), h.clamp(1.0, 10000.0));
  }

  /// 3x3 homography mapping [quad] -> upright rect of size [dst].
  /// Returned row-major: [h11,h12,h13, h21,h22,h23, h31,h32,h33].
  /// Throws [ArgumentError] on degenerate (zero-area / non-convex) quads.
  static List<double> homography(DocumentQuad quad, Size dst) {
    if (!quad.isConvex || quad.area < 1e-6) {
      throw ArgumentError('Degenerate quad: need convex quad with area > 0');
    }
    final src = quad.points;
    final dw = dst.width;
    final dh = dst.height;
    final dstPts = [
      Offset.zero,
      Offset(dw, 0),
      Offset(dw, dh),
      Offset(0, dh),
    ];
    return _solveHomography(src, dstPts);
  }

  /// Map a point through row-major 3x3 homography [h].
  static Offset transformPoint(Offset p, List<double> h) {
    assert(h.length == 9);
    final w = h[6] * p.dx + h[7] * p.dy + h[8];
    if (w.abs() < 1e-12) return Offset.zero;
    return Offset(
      (h[0] * p.dx + h[1] * p.dy + h[2]) / w,
      (h[3] * p.dx + h[4] * p.dy + h[5]) / w,
    );
  }

  /// Inverse of row-major 3x3 homography (for mapping OCR boxes back).
  static List<double> invert(List<double> h) {
    assert(h.length == 9);
    final a = h[0], b = h[1], c = h[2];
    final d = h[3], e = h[4], f = h[5];
    final g = h[6], hh = h[7], i = h[8];
    final det = a * (e * i - f * hh) - b * (d * i - f * g) + c * (d * hh - e * g);
    if (det.abs() < 1e-12) {
      throw ArgumentError('Non-invertible homography');
    }
    final inv = 1 / det;
    return [
      (e * i - f * hh) * inv,
      (c * hh - b * i) * inv,
      (b * f - c * e) * inv,
      (f * g - d * i) * inv,
      (a * i - c * g) * inv,
      (c * d - a * f) * inv,
      (d * hh - e * g) * inv,
      (b * g - a * hh) * inv,
      (a * e - b * d) * inv,
    ];
  }

  // Direct Linear Transform for 4 point correspondences.
  static List<double> _solveHomography(
      List<Offset> src, List<Offset> dst) {
    // Build 8x8 linear system A*h = b (h33 = 1).
    final a = List.generate(8, (_) => List.filled(8, 0.0));
    final b = List.filled(8, 0.0);
    for (var k = 0; k < 4; k++) {
      final x = src[k].dx, y = src[k].dy;
      final u = dst[k].dx, v = dst[k].dy;
      final r1 = k * 2, r2 = k * 2 + 1;
      a[r1][0] = x; a[r1][1] = y; a[r1][2] = 1;
      a[r1][6] = -u * x; a[r1][7] = -u * y;
      b[r1] = u;
      a[r2][3] = x; a[r2][4] = y; a[r2][5] = 1;
      a[r2][6] = -v * x; a[r2][7] = -v * y;
      b[r2] = v;
    }
    final h = _gaussianSolve(a, b);
    return [...h.sublist(0, 6), h[6], h[7], 1.0];
  }

  static List<double> _gaussianSolve(
      List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = a.map((r) => [...r, 0.0]).toList();
    for (var i = 0; i < n; i++) {
      m[i][n] = b[i];
    }
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
      final div = m[col][col];
      if (div.abs() < 1e-12) {
        throw ArgumentError('Singular homography system');
      }
      for (var j = col; j <= n; j++) {
        m[col][j] /= div;
      }
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final factor = m[r][col];
        for (var j = col; j <= n; j++) {
          m[r][j] -= factor * m[col][j];
        }
      }
    }
    return List.generate(n, (i) => m[i][n]);
  }
}
