import 'dart:ui';

import 'package:inf_orc_kit/inf_orc_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocPage', () {
    test('bestPath prefers enhanced', () {
      final p = DocPage(imagePath: 'a.jpg');
      expect(p.bestPath, 'a.jpg');
      expect(p.isEnhanced, isFalse);
      final e = p.copyWith(enhancedPath: 'a_clean.jpg');
      expect(e.bestPath, 'a_clean.jpg');
      expect(e.id, p.id);
    });

    test('json round trip', () {
      final p = DocPage(
        imagePath: 'a.jpg',
        quad: DocumentQuad(
          topLeft: const Offset(10, 10),
          topRight: const Offset(100, 10),
          bottomRight: const Offset(100, 140),
          bottomLeft: const Offset(10, 140),
        ),
        enhancedPath: 'a_clean.jpg',
      );
      final back = DocPage.fromJson(p.toJson());
      expect(back.id, p.id);
      expect(back.bestPath, 'a_clean.jpg');
      expect(back.quad!.bottomRight, const Offset(100, 140));
    });
  });

  group('DocSession', () {
    test('add / update / remove / reorder / export', () {
      final s = DocSession();
      expect(s.isEmpty, isTrue);
      final a = s.addPage('a.jpg');
      final b = s.addPage('b.jpg');
      expect(s.length, 2);

      s.updatePage(b.copyWith(enhancedPath: 'b_clean.jpg'));
      expect(s.exportPaths(), ['a.jpg', 'b_clean.jpg']);
      expect(s.exportPaths(preferEnhanced: false), ['a.jpg', 'b.jpg']);

      s.movePage(1, 0);
      expect(s.pages.first.id, b.id);

      expect(s.removePage(a.id), isTrue);
      expect(s.removePage('nope'), isFalse);
      expect(s.length, 1);

      expect(() => s.movePage(5, 0), throwsRangeError);
      s.clear();
      expect(s.isEmpty, isTrue);
    });
  });

  group('EdgeDetector', () {
    test('full-frame fallback insets quad', () async {
      const d = FullFrameEdgeDetector();
      final q = await d.detect(imageSize: const Size(1000, 800));
      expect(q, isNotNull);
      expect(q!.coverage(const Size(1000, 800)), greaterThan(0.8));
      expect(q.isConvex, isTrue);

      expect(await d.detect(imageSize: Size.zero), isNull);
    });
  });
}
