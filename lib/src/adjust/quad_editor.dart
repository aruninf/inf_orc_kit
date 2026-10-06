import 'package:flutter/material.dart';

import '../capture/document_quad.dart';

/// Interactive document-corner editor ("edge adjust").
///
/// Overlays a draggable quadrilateral on your image (pass it as [child],
/// e.g. `Image.file`). Users drag the 4 handles; every move reports the
/// updated quad in [imageSize] pixels via [onChanged].
///
/// The widget is controlled: it never mutates [quad] itself, so it plugs
/// straight into [DocCaptureSession], [EdgeDetector] output, or any state
/// management you like.
class QuadEditor extends StatefulWidget {
  /// Full image size in pixels — the coordinate space of [quad].
  final Size imageSize;

  /// Current corners in [imageSize] pixels.
  final DocumentQuad quad;

  final ValueChanged<DocumentQuad>? onChanged;

  /// Image shown under the overlay.
  final Widget? child;

  final double handleRadius;
  final Color lineColor;
  final Color handleColor;

  const QuadEditor({
    super.key,
    required this.imageSize,
    required this.quad,
    this.onChanged,
    this.child,
    this.handleRadius = 18,
    this.lineColor = const Color(0xFF00E676),
    this.handleColor = Colors.white,
  });

  @override
  State<QuadEditor> createState() => _QuadEditorState();
}

class _QuadEditorState extends State<QuadEditor> {
  int? _activeCorner;

  double get _scaleX => _boxSize.width / widget.imageSize.width;
  double get _scaleY => _boxSize.height / widget.imageSize.height;

  Size _boxSize = Size.zero;

  Offset _toDisplay(Offset p) =>
      Offset(p.dx * _scaleX, p.dy * _scaleY);

  Offset _toImage(Offset p) =>
      Offset((p.dx / _scaleX).clamp(0, widget.imageSize.width),
          (p.dy / _scaleY).clamp(0, widget.imageSize.height));

  void _updateQuad(List<Offset> displayPoints) {
    final imgPts = displayPoints.map(_toImage).toList();
    widget.onChanged?.call(DocumentQuad(
      topLeft: imgPts[0],
      topRight: imgPts[1],
      bottomRight: imgPts[2],
      bottomLeft: imgPts[3],
      score: widget.quad.score,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Contain-fit mapping so handles track the visible image.
        final fit = _containScale(
            widget.imageSize,
            Size(constraints.maxWidth, constraints.maxHeight));
        _boxSize = Size(
            widget.imageSize.width * fit, widget.imageSize.height * fit);
        final pts =
            widget.quad.points.map(_toDisplay).toList();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            var best = -1;
            var bestDist = widget.handleRadius * 1.5;
            for (var i = 0; i < pts.length; i++) {
              final dist = (pts[i] - d.localPosition).distance;
              if (dist < bestDist) {
                bestDist = dist;
                best = i;
              }
            }
            setState(() => _activeCorner = best < 0 ? null : best);
          },
          onPanUpdate: (d) {
            final corner = _activeCorner;
            if (corner == null) return;
            final next = [...pts]..[corner] = d.localPosition;
            _updateQuad(next);
          },
          onPanEnd: (_) => setState(() => _activeCorner = null),
          onPanCancel: () => setState(() => _activeCorner = null),
          child: SizedBox(
            width: _boxSize.width,
            height: _boxSize.height,
            child: Stack(
              children: [
                if (widget.child != null)
                  Positioned.fill(child: widget.child!),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _QuadPainter(
                      points: pts,
                      handleRadius: widget.handleRadius,
                      lineColor: widget.lineColor,
                      handleColor: widget.handleColor,
                      activeCorner: _activeCorner,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _containScale(Size src, Size dst) {
    if (src.width <= 0 || src.height <= 0) return 1;
    if (!dst.isFinite) return 1;
    return (dst.width / src.width < dst.height / src.height)
        ? dst.width / src.width
        : dst.height / src.height;
  }
}

class _QuadPainter extends CustomPainter {
  final List<Offset> points;
  final double handleRadius;
  final Color lineColor;
  final Color handleColor;
  final int? activeCorner;

  _QuadPainter({
    required this.points,
    required this.handleRadius,
    required this.lineColor,
    required this.handleColor,
    required this.activeCorner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < 4; i++) {
      final r = i == activeCorner ? handleRadius * 1.25 : handleRadius;
      canvas.drawCircle(
          points[i], r, Paint()..color = handleColor);
      canvas.drawCircle(points[i], r,
          Paint()..color = lineColor..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(covariant _QuadPainter old) =>
      old.points != points ||
      old.activeCorner != activeCorner ||
      old.lineColor != lineColor ||
      old.handleColor != handleColor;
}
