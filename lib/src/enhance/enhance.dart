import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../capture/document_quad.dart';
import '../capture/perspective.dart';

/// One-tap clean-up styles for [enhanceImage].
enum EnhancePreset {
  /// Color kept, mild contrast. Good default for photos of documents.
  document,

  /// Grayscale + stronger contrast. Receipts, invoices, faded print.
  receipt,

  /// Color kept, gentle contrast. IDs, cards, anything with a photo.
  idCard,

  /// Grayscale + max contrast. Small or low-ink text.
  blackWhite,
}

/// Tuning knobs for [enhanceImage].
class EnhanceOptions {
  final bool grayscale;
  final double contrast;
  final double brightness;
  final int quality;
  final int maxSide;

  const EnhanceOptions({
    this.grayscale = true,
    this.contrast = 1.2,
    this.brightness = 0.0,
    this.quality = 92,
    this.maxSide = 2000,
  });

  factory EnhanceOptions.preset(EnhancePreset preset) {
    switch (preset) {
      case EnhancePreset.document:
        return const EnhanceOptions(
            grayscale: false, contrast: 1.15);
      case EnhancePreset.receipt:
        return const EnhanceOptions(
            grayscale: true, contrast: 1.5, brightness: 0.05);
      case EnhancePreset.idCard:
        return const EnhanceOptions(
            grayscale: false, contrast: 1.1);
      case EnhancePreset.blackWhite:
        return const EnhanceOptions(
            grayscale: true, contrast: 1.8, brightness: 0.08);
    }
  }
}

/// Straighten [imageBytes] along [quad] (in image pixels) into an upright
/// rectangle. Pure Dart (inverse-map + bilinear sampling), no native code.
///
/// [maxSide] caps the output's long side to bound memory/time.
Uint8List warpQuadToRect(
  Uint8List imageBytes,
  DocumentQuad quad, {
  int maxSide = 2000,
  int quality = 92,
}) {
  final src = img.decodeImage(imageBytes);
  if (src == null) throw ArgumentError('Could not decode image bytes');

  var dstSize = Perspective.destinationSize(quad);
  final longSide = math.max(dstSize.width, dstSize.height);
  if (longSide > maxSide) {
    final s = maxSide / longSide;
    dstSize = dstSize * s;
  }

  final h = Perspective.homography(quad, dstSize);
  final inv = Perspective.invert(h);
  final w = dstSize.width.round().clamp(1, 8000);
  final hh = dstSize.height.round().clamp(1, 8000);
  final dst = img.Image(width: w, height: hh);

  for (var y = 0; y < hh; y++) {
    for (var x = 0; x < w; x++) {
      // Map through pixel centers for a stable result.
      final p = Perspective.transformPoint(
          Offset(x + 0.5, y + 0.5), inv);
      dst.setPixel(x, y, _bilinear(src, p.dx - 0.5, p.dy - 0.5));
    }
  }
  return img.encodeJpg(dst, quality: quality);
}

/// Clean up document photo bytes: optional downscale, grayscale,
/// contrast/brightness. Returns JPEG bytes.
Uint8List enhanceImage(
  Uint8List imageBytes, {
  EnhanceOptions options = const EnhanceOptions(),
}) {
  var src = img.decodeImage(imageBytes);
  if (src == null) throw ArgumentError('Could not decode image bytes');

  final longSide = math.max(src.width, src.height);
  if (longSide > options.maxSide) {
    final s = options.maxSide / longSide;
    src = img.copyResize(src,
        width: (src.width * s).round(),
        height: (src.height * s).round());
  }
  if (options.grayscale) src = img.grayscale(src);
  if (options.contrast != 1.0 || options.brightness != 0.0) {
    src = img.adjustColor(src,
        contrast: options.contrast, brightness: options.brightness);
  }
  return img.encodeJpg(src, quality: options.quality);
}

img.Color _bilinear(img.Image src, double x, double y) {
  final x0 = x.floor().clamp(0, src.width - 1);
  final y0 = y.floor().clamp(0, src.height - 1);
  final x1 = (x0 + 1).clamp(0, src.width - 1);
  final y1 = (y0 + 1).clamp(0, src.height - 1);
  final fx = (x - x0).clamp(0.0, 1.0);
  final fy = (y - y0).clamp(0.0, 1.0);

  final a = src.getPixel(x0, y0);
  final b = src.getPixel(x1, y0);
  final c = src.getPixel(x0, y1);
  final d = src.getPixel(x1, y1);

  int mix(num v00, num v10, num v01, num v11) =>
      (v00 * (1 - fx) * (1 - fy) +
              v10 * fx * (1 - fy) +
              v01 * (1 - fx) * fy +
              v11 * fx * fy)
          .round()
          .clamp(0, 255);

  return img.ColorRgb8(mix(a.r, b.r, c.r, d.r), mix(a.g, b.g, c.g, d.g),
      mix(a.b, b.b, c.b, d.b));
}
