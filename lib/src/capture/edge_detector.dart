import 'dart:typed_data';
import 'dart:ui';

import '../capture/document_quad.dart';

/// Finds document corners in a photo.
///
/// Kept as an interface on purpose: ship [FullFrameEdgeDetector] today
/// (manual adjust via [QuadEditor]), drop in an ML Kit / Vision / OpenCV
/// implementation later without changing calling code.
///
/// Coordinate space: [imageSize] pixels, same as [DocumentQuad].
abstract class EdgeDetector {
  Future<DocumentQuad?> detect({
    required Size imageSize,
    String? imagePath,
    Uint8List? imageBytes,
  });
}

/// Fallback detector: assumes the document fills the frame.
///
/// Returns a slightly inset quad so users immediately see something to
/// drag in [QuadEditor]. Score is intentionally modest (0.5) so quality
/// gates treat it as "needs confirmation".
class FullFrameEdgeDetector implements EdgeDetector {
  /// Inset as a fraction of min(imageSize.width, imageSize.height).
  final double insetFraction;

  const FullFrameEdgeDetector({this.insetFraction = 0.04});

  @override
  Future<DocumentQuad?> detect({
    required Size imageSize,
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    if (imageSize.width <= 0 || imageSize.height <= 0) return null;
    final m = imageSize.shortestSide * insetFraction;
    return DocumentQuad(
      topLeft: Offset(m, m),
      topRight: Offset(imageSize.width - m, m),
      bottomRight: Offset(imageSize.width - m, imageSize.height - m),
      bottomLeft: Offset(m, imageSize.height - m),
      score: 0.5,
    );
  }
}
