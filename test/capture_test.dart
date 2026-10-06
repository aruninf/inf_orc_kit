import 'dart:ui';

import 'package:inf_orc_kit/inf_orc_kit.dart';
import 'package:flutter_test/flutter_test.dart';

DocumentQuad rectQuad(double l, double t, double r, double b) {
  return DocumentQuad(
    topLeft: Offset(l, t),
    topRight: Offset(r, t),
    bottomRight: Offset(r, b),
    bottomLeft: Offset(l, b),
  );
}

void main() {
  group('DocumentQuad', () {
    test('area + coverage + convex', () {
      final q = rectQuad(0, 0, 200, 100);
      expect(q.area, 20000);
      expect(q.coverage(const Size(400, 400)), closeTo(0.125, 1e-9));
      expect(q.isConvex, isTrue);
      expect(q.skewDegrees, closeTo(0, 1e-9));
    });

    test('non-convex rejected', () {
      const q = DocumentQuad(
        topLeft: Offset(0, 0),
        topRight: Offset(100, 0),
        bottomRight: Offset(0, 100),
        bottomLeft: Offset(100, 100),
      );
      expect(q.isConvex, isFalse);
    });

    test('fromUnordered reorders', () {
      final q = DocumentQuad.fromUnordered(const [
        Offset(200, 100),
        Offset(0, 100),
        Offset(200, 0),
        Offset(0, 0),
      ]);
      expect(q.topLeft, const Offset(0, 0));
      expect(q.bottomRight, const Offset(200, 100));
    });

    test('scale + lerp + distance', () {
      final q = rectQuad(0, 0, 100, 100);
      final scaled = q.scale(const Size(100, 100), const Size(200, 200));
      expect(scaled.topLeft, const Offset(0, 0));
      expect(scaled.bottomRight, const Offset(200, 200));
      final other = rectQuad(10, 0, 110, 100);
      expect(q.distanceTo(other), 10);
      final mid = q.lerp(other, 0.5);
      expect(mid.topLeft.dx, 5);
    });

    test('json round trip', () {
      final q = rectQuad(10, 20, 110, 120);
      final back = DocumentQuad.fromJson(q.toJson());
      expect(back.bottomRight, const Offset(110, 120));
    });
  });

  group('Perspective', () {
    test('identity quad -> rect maps corners', () {
      final q = rectQuad(0, 0, 200, 100);
      final h = Perspective.homography(q, const Size(200, 100));
      final p0 = Perspective.transformPoint(const Offset(0, 0), h);
      expect(p0.dx, closeTo(0, 1e-6));
      expect(p0.dy, closeTo(0, 1e-6));
      final p1 = Perspective.transformPoint(const Offset(200, 100), h);
      expect(p1.dx, closeTo(200, 1e-6));
      expect(p1.dy, closeTo(100, 1e-6));
    });

    test('skewed quad maps to upright + invertible', () {
      const q = DocumentQuad(
        topLeft: Offset(10, 5),
        topRight: Offset(190, 0),
        bottomRight: Offset(200, 100),
        bottomLeft: Offset(0, 95),
      );
      const dst = Size(180, 100);
      final h = Perspective.homography(q, dst);
      final inv = Perspective.invert(h);
      final center = Perspective.transformPoint(const Offset(100, 50), h);
      final back = Perspective.transformPoint(center, inv);
      expect(back.dx, closeTo(100, 1e-4));
      expect(back.dy, closeTo(50, 1e-4));
    });

    test('destinationSize uses max edges', () {
      final q = rectQuad(0, 0, 300, 100);
      expect(Perspective.destinationSize(q), const Size(300, 100));
    });

    test('degenerate throws', () {
      const q = DocumentQuad(
        topLeft: Offset(0, 0),
        topRight: Offset(0, 0),
        bottomRight: Offset(0, 0),
        bottomLeft: Offset(0, 0),
      );
      expect(() => Perspective.homography(q, const Size(100, 100)),
          throwsArgumentError);
    });
  });

  group('CapturePolicy + Session', () {
    const img = Size(1000, 1000);

    test('move closer when tiny', () {
      const policy = CapturePolicy();
      final q = rectQuad(450, 450, 550, 550); // 1% coverage
      final res = policy.evaluate(quad: q, imageSize: img);
      expect(res.feedback, CaptureFeedback.moveCloser);
      expect(res.canCapture, isFalse);
    });

    test('good quad passes', () {
      const policy = CapturePolicy();
      final q = rectQuad(200, 200, 800, 800);
      final res = policy.evaluate(quad: q, imageSize: img, motionPx: 2);
      expect(res.feedback, CaptureFeedback.goodToCapture);
      expect(res.canCapture, isTrue);
    });

    test('null quad -> noDocument', () {
      const policy = CapturePolicy();
      final res = policy.evaluate(quad: null, imageSize: img);
      expect(res.feedback, CaptureFeedback.noDocument);
    });

    test('session requires steady frames then ready', () {
      final session = DocCaptureSession(steadyFramesRequired: 3);
      final q = rectQuad(200, 200, 800, 800);
      expect(session.onFrame(null, img), CaptureState.searching);
      // First quad frame: motion gate keeps it searching/stabilizing, not ready.
      var s = session.onFrame(q, img);
      expect(s, isNot(CaptureState.ready));
      for (var i = 0; i < 5; i++) {
        s = session.onFrame(q, img);
      }
      expect(s, CaptureState.ready);
      session.markCaptured();
      expect(session.state, CaptureState.captured);
      session.reset();
      expect(session.state, CaptureState.searching);
    });
  });

  group('OcrResult compat', () {
    test('textLines alias works', () {
      final r = OcrResult(
        results: [
          TextLine(x1: 0, y1: 0, x2: 10, y2: 10, score: 0.9, text: 'hi'),
        ],
        count: 1,
        inferenceTimeMs: 1,
        imageWidth: 100,
        imageHeight: 100,
      );
      expect(r.textLines.length, 1);
      expect(r.fullText, 'hi');
    });
  });
}
