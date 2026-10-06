import '../models.dart';
import 'ocr_kit.dart';

/// Slim OCR facade for the scan flow.
///
/// Delegates to the platform-native engine ([OcrKit.recognizeNative]):
/// Apple Vision on iOS/macOS, Google ML Kit on Android. No model setup.
class DocOcr {
  DocOcr._();

  /// Read text from a single image path (see [DocPage.bestPath]).
  static Future<OcrResult> read(
    String imagePath, {
    List<String> languages = const [],
  }) {
    return OcrKit.recognizeNative(imagePath, languages: languages);
  }

  /// Read a batch (e.g. [DocSession.exportPaths]) with progress.
  ///
  /// A failed page yields an [OcrResult] with `error` set instead of
  /// throwing, so one bad photo never kills a multi-page job.
  static Future<List<OcrResult>> readAll(
    List<String> imagePaths, {
    List<String> languages = const [],
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <OcrResult>[];
    for (var i = 0; i < imagePaths.length; i++) {
      try {
        results.add(await read(imagePaths[i], languages: languages));
      } catch (e) {
        results.add(OcrResult(
          results: [],
          count: 0,
          inferenceTimeMs: 0,
          imageWidth: 0,
          imageHeight: 0,
          error: e.toString(),
        ));
      }
      onProgress?.call(i + 1, imagePaths.length);
    }
    return results;
  }
}
