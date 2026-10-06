import 'dart:typed_data';

import 'package:inf_orc_kit/inf_orc_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _testJpg({int w = 32, int h = 24}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixel(x, y,
          img.ColorRgb8((x * 8) % 256, (y * 10) % 256, 128));
    }
  }
  return img.encodeJpg(im);
}

DocumentQuad _full(int w, int h) => DocumentQuad(
      topLeft: Offset.zero,
      topRight: Offset(w.toDouble(), 0),
      bottomRight: Offset(w.toDouble(), h.toDouble()),
      bottomLeft: Offset(0, h.toDouble()),
    );

void main() {
  group('warpQuadToRect', () {
    test('identity quad keeps size', () {
      final bytes = _testJpg();
      final out = warpQuadToRect(bytes, _full(32, 24));
      final back = img.decodeImage(out)!;
      expect(back.width, 32);
      expect(back.height, 24);
    });

    test('skewed quad warps to upright rect', () {
      final bytes = _testJpg(w: 40, h: 30);
      const quad = DocumentQuad(
        topLeft: Offset(4, 2),
        topRight: Offset(36, 0),
        bottomRight: Offset(38, 28),
        bottomLeft: Offset(2, 26),
      );
      final out = warpQuadToRect(bytes, quad);
      final back = img.decodeImage(out)!;
      // Destination ~= max edge lengths.
      expect(back.width, greaterThan(25));
      expect(back.height, greaterThan(20));
    });

    test('maxSide caps output', () {
      final bytes = _testJpg(w: 64, h: 48);
      final out =
          warpQuadToRect(bytes, _full(64, 48), maxSide: 32);
      final back = img.decodeImage(out)!;
      expect(back.width <= 32 && back.height <= 32, isTrue);
    });

    test('bad bytes throw', () {
      expect(
          () => warpQuadToRect(
              Uint8List.fromList([1, 2, 3]), _full(10, 10)),
          throwsArgumentError);
    });
  });

  group('enhanceImage', () {
    test('returns decodable jpeg', () {
      final out = enhanceImage(_testJpg());
      expect(img.decodeImage(out), isNotNull);
    });

    test('presets produce output', () {
      final bytes = _testJpg();
      for (final p in EnhancePreset.values) {
        final out = enhanceImage(bytes,
            options: EnhanceOptions.preset(p));
        expect(img.decodeImage(out), isNotNull);
      }
    });
  });
}
