import 'dart:ui';

import 'capture_quality.dart';
import 'document_quad.dart';

enum CaptureState { searching, stabilizing, ready, captured }

/// Camera-agnostic auto-capture state machine.
///
/// Feed one [DocumentQuad] per preview frame; the session handles
/// smoothing + stability counting. No camera plugin import here on
/// purpose — works with camera, image_picker, or stubbed detector.
class DocCaptureSession {
  final CapturePolicy policy;
  final int steadyFramesRequired;
  final double smoothing;

  DocumentQuad? _smoothed;
  DocumentQuad? _previous;
  int _steadyCount = 0;
  CaptureState _state = CaptureState.searching;
  CaptureQuality? _lastQuality;

  DocCaptureSession({
    this.policy = const CapturePolicy(),
    this.steadyFramesRequired = 8,
    this.smoothing = 0.35,
  });

  CaptureState get state => _state;
  DocumentQuad? get quad => _smoothed;
  CaptureQuality? get lastQuality => _lastQuality;
  int get steadyCount => _steadyCount;

  /// Process one frame. [imageSize] is full-frame pixels.
  CaptureState onFrame(DocumentQuad? detected, Size imageSize,
      {double? blurScore}) {
    if (detected == null) {
      _steadyCount = 0;
      _smoothed = null;
      _previous = null;
      _state = CaptureState.searching;
      _lastQuality = policy.evaluate(
          quad: null, imageSize: imageSize, blurScore: blurScore);
      return _state;
    }

    _smoothed = _smoothed == null
        ? detected
        : _smoothed!.lerp(detected, smoothing);
    final motion =
        _previous == null ? double.infinity : _smoothed!.distanceTo(_previous!);
    // First visible frame counts as motion; don't auto-capture on it.
    final gatedMotion = _previous == null ? 1e9 : motion;
    _previous = _smoothed;

    _lastQuality = policy.evaluate(
      quad: _smoothed!,
      imageSize: imageSize,
      motionPx: gatedMotion,
      blurScore: blurScore,
    );

    if (_lastQuality!.canCapture) {
      _steadyCount++;
    } else {
      _steadyCount = 0;
    }

    if (_state != CaptureState.captured) {
      if (_steadyCount >= steadyFramesRequired) {
        _state = CaptureState.ready;
      } else if (_steadyCount > 0) {
        _state = CaptureState.stabilizing;
      } else {
        _state = CaptureState.searching;
      }
    }
    return _state;
  }

  /// Call when shutter fires (auto or manual).
  void markCaptured() {
    _state = CaptureState.captured;
  }

  void reset() {
    _state = CaptureState.searching;
    _steadyCount = 0;
    _smoothed = null;
    _previous = null;
    _lastQuality = null;
  }
}
