# inf_orc_kit

On-device document AI for Flutter: snap a document, extract its text, understand its layout. Everything runs locally on the phone — no server, no internet needed.

What it does:
- **Reads text from photos** — uses the phone's built-in OCR (Apple Vision on iOS, Google ML Kit on Android), with word-level bounding boxes and confidence scores.
- **Understands page layout** — an ONNX model finds tables, text blocks, titles, figures and headers so you can OCR just the region you care about.
- **Captures clean document shots** — pure-Dart helpers for document corners (`DocumentQuad`), perspective straightening (homography), shot-quality checks (coverage, skew, steadiness) and an auto-capture state machine.
- **Pulls out key facts** — generic extractors for dates, phone numbers, amounts, emails, URLs and label→value pairs (e.g. "Total" → "$42.50") without any cloud service.

## Demo Video

[![Demo Video](https://img.youtube.com/vi/s70GC92Ir4Q/maxresdefault.jpg)](https://www.youtube.com/watch?v=s70GC92Ir4Q)

The demo includes 3 examples:
1. **Real-time text search** - Find specific text strings in camera view
2. **Real-time KIE** - Extract specific types (dates, phone numbers, amounts)
3. **Doc scan** - Pick a photo, drag corners to the edges, enhance, OCR

> Screenshots and branding are being refreshed for `inf_orc_kit`.

## Features

- **Native OCR Engine**: Apple Vision (iOS) and Google ML Kit (Android) for text recognition with bounding boxes and confidence scores — no model download needed
- **Layout Detection**: ONNX-based document layout analysis to identify tables, text blocks, titles, and figures
- **Document Capture (pure Dart, no native deps)**: `DocumentQuad` corner model, perspective homography, quality gates (coverage/skew/motion), and `DocCaptureSession` auto-capture FSM
- **Key Information Extraction**: generic regex, spatial (label→value) and layout-region extractors
- **Edge AI**: all processing runs locally on device — no internet required
- **Cross-platform**: iOS and Android

## Supported Platforms

| Platform | OCR Engine | Layout Detection | Native Library |
|----------|------------|------------------|----------------|
| iOS | Apple Vision | ONNX Runtime + OpenCV | Static (.a) |
| Android | Google ML Kit | ONNX Runtime + OpenCV | Dynamic (.so) |

## Installation

Takes about 2 minutes. No API keys, no accounts, no cloud setup.

### 1. Add the package

```bash
dart pub add inf_orc_kit
```

or manually in `pubspec.yaml`:

```yaml
dependencies:
  inf_orc_kit: ^1.2.0
```

Then import one file — everything is exported from the barrel:

```dart
import 'package:inf_orc_kit/inf_orc_kit.dart';
```

### 2. Platform setup (required for camera + gallery)

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan documents and recognize text.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pick document images for OCR.</string>
```

Then:

```bash
cd ios && pod install
```

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

Requires `minSdk 21+`. No Gradle changes needed.

### 3. Layout model (optional — only for table/region detection)

Plain OCR and document capture need **no model**. Only download this if you use `OcrKit.detectLayout`:

| Model | Size | Description |
|-------|------|-------------|
| pp_doclayout_l.onnx | 123 MB | Layout detection model |

Get it from [GitHub Releases](https://github.com/aruninf/inf_orc_kit/releases), put it in `assets/`, and register it:

```yaml
flutter:
  assets:
    - assets/pp_doclayout_l.onnx
```

## Integrate in 5 minutes

### Recipe 1 — Read text from a photo (1 line)

```dart
import 'package:inf_orc_kit/inf_orc_kit.dart';

// Vision on iOS, ML Kit on Android. No init, no model.
final result = await DocOcr.read('/path/to/image.jpg');

print(result.fullText);
for (final line in result.textLines) {
  print('${line.text} (confidence: ${line.score})');
}
```

### Recipe 2 — Scan a document (adjust → enhance → OCR)

```dart
// 1. Find corners (swap in your ML Kit / Vision detector later)
final quad = await const FullFrameEdgeDetector()
    .detect(imageSize: imageSize, imageBytes: bytes);

// 2. Let the user drag corners, then straighten + clean
QuadEditor( // a widget: pass your Image as `child`
  imageSize: imageSize,
  quad: quad,
  onChanged: (q) => setState(() => quad = q),
);
final warped = warpQuadToRect(bytes, quad);
final clean = enhanceImage(
  warped, options: EnhanceOptions.preset(EnhancePreset.receipt));

// 3. Multi-page session + batch OCR with progress
session.addPage(savedPath, quad: quad);
final texts = await DocOcr.readAll(
  session.exportPaths(),
  onProgress: (done, total) => setState(() => progress = done / total),
);
```

### Recipe 3 — Pull out key facts

```dart
final kie = SimpleKieExtractor().extract(result);
for (final e in kie.entities) {
  print('${e.type.label}: ${e.value}');
}
// Label → value pairs, e.g. "Total" → "$42.50":
final spatial = SpatialKieExtractor().extract(result);
```

### Layout Detection (opt-in)

```dart
// Initialize layout model
OcrKit.init('/path/to/pp_doclayout_l.onnx');

// Detect document layout
final layout = OcrKit.detectLayout('/path/to/document.jpg');

for (final region in layout.detections) {
  print('${region.className}: (${region.x1}, ${region.y1}) - (${region.x2}, ${region.y2})');
}

// Release model when done to free memory
OcrKit.releaseLayout();
```

> **Note (iOS)**: Layout detection uses Core ML Execution Provider for faster inference, but consumes more memory (~1.5GB). Always call `OcrKit.releaseLayout()` when you no longer need layout detection to free memory. To disable Core ML and use CPU only (lower memory, slower speed), modify `src/detect/doc_detector.cpp` and rebuild the static library.

Supported layout classes: `Text`, `Title`, `Figure`, `Figure caption`, `Table`, `Table caption`, `Header`, `Footer`, `Reference`, `Equation`

### Combined: Layout + OCR

```dart
// Step 1: Detect layout to find table regions
final layout = OcrKit.detectLayout(imagePath);
final tableRegions = layout.detections.where((d) => d.className == 'Table');

// Step 2: Run OCR on the entire image
final ocrResult = await OcrKit.recognizeNative(imagePath);

// Step 3: Filter OCR results within table regions
for (final table in tableRegions) {
  final tableTexts = ocrResult.textLines.where((line) {
    // Check if text is within table bounding box
    return line.rect.overlaps(Rect.fromLTRB(table.x1, table.y1, table.x2, table.y2));
  });
  print('Table content: ${tableTexts.map((t) => t.text).join(' ')}');
}
```

## Example App

The example app includes 3 tabs demonstrating different use cases:

### Tab 1: OCR

Basic OCR demonstration:
- Pick image from gallery or capture with camera
- Display recognized text with bounding boxes
- Show confidence scores for each text line

### Tab 2: KIE (Key Information Extraction)

Simple regex-based entity extraction:
- Extract dates, amounts, phone numbers from OCR results
- Demonstrates how to post-process OCR output

### Tab 3: Scan (pick → adjust → enhance → OCR)

End-to-end document flow:
- Pick a photo, auto-placed corners via `FullFrameEdgeDetector`
- Drag corners with `QuadEditor`, straighten + clean with `warpQuadToRect` / `enhanceImage`
- Collect pages in `DocSession`, read them with `DocOcr.readAll`

```dart
// 1. Detect (swap in your ML Kit / Vision detector later)
final quad = await const FullFrameEdgeDetector()
    .detect(imageSize: imageSize, imageBytes: bytes);

// 2. Let the user adjust, then straighten + clean
final warped = warpQuadToRect(bytes, quad);
final clean = enhanceImage(
    warped, options: EnhanceOptions.preset(EnhancePreset.receipt));

// 3. Multi-page + OCR
session.addPage(savedPath, quad: quad);
final texts = await DocOcr.readAll(session.exportPaths());
```

## How to Build Your Own Document Scanner

The KIE demo shows the pattern for building custom document scanners:

1. **Define your extraction rules** - Create an extractor class (see `kie_extractor.dart`: `SimpleKieExtractor`, `SpatialKieExtractor`, `LayoutKieExtractor`)

2. **Use regex patterns** - Define patterns for the fields you want to extract:
```dart
// Example: Extract order number like "ORD-2024-001234"
final orderPattern = RegExp(r'ORD-\d{4}-\d{6}');
final match = orderPattern.firstMatch(ocrResult.fullText);
```

3. **Use Layout Detection** (optional) - For structured documents with tables:
```dart
// Find table regions first
final tables = layout.detections.where((d) => d.className == 'Table');
// Then extract data from table area only
```

4. **Handle confidence scores** - Filter low-confidence results:
```dart
final reliableText = ocrResult.textLines.where((line) => line.score > 0.8);
```

## Project Structure

```
lib/
  inf_orc_kit.dart                  # Barrel: exports the whole public API
  src/
    ocr/ocr_kit.dart                # OcrKit: native OCR + layout detection
    models.dart                     # Data models (TextLine, OcrResult, LayoutResult)
    ocr_service.dart                # Async OCR service with isolate support
    kie_extractor.dart              # Key information extraction (regex + spatial + layout)
    capture/                        # Pure-Dart document capture (quad, perspective, quality, session)
    adjust/quad_editor.dart         # Drag-to-adjust corner overlay widget
    enhance/enhance.dart            # Perspective warp + clean-up presets
    pages/doc_session.dart          # Multi-page scan session
    ocr/doc_ocr.dart                # Slim OCR facade with batch + progress
    core/doc_page.dart              # Single scanned-page model

src/                                # Native C++ code (FFI)
  native_lib.cpp                    # FFI exported functions
  detect/
    doc_detector.cpp                # Layout detection with ONNX
  ocr/
    ocr_engine.cpp                  # OCR engine (backup, not used by default)

ios/
  Classes/
    OcrKitPlugin.m                  # iOS plugin entry
    VisionOcr.m                     # Apple Vision OCR implementation
  static_libs/                      # Pre-built static libraries (.a)
  Frameworks/                       # ONNX Runtime & OpenCV frameworks

android/
  src/main/
    kotlin/.../OcrKitPlugin.kt      # Android plugin (ML Kit OCR)
    jniLibs/                        # Pre-built dynamic libraries (.so)
    cpp/include/                    # ONNX Runtime & OpenCV headers
```

## API Reference

### OcrKit

| Method | Description |
|--------|-------------|
| `init(modelPath)` | Initialize ONNX layout model |
| `detectLayout(imagePath)` | Detect document layout regions |
| `recognizeNative(imagePath)` | OCR using native engine (Vision/ML Kit) |
| `recognizeText(imagePath)` | OCR using ONNX model (requires `initOcr`) |
| `releaseLayout()` / `releaseOcr()` | Free native model memory |

### Document Capture (pure Dart)

| Class | Description |
|-------|-------------|
| `DocumentQuad` | 4-corner doc polygon: area, coverage, convexity, smoothing |
| `Perspective` | Homography + `destinationSize` + inverse mapping for OCR boxes |
| `CapturePolicy` | Quality gates: coverage, skew, motion, blur |
| `DocCaptureSession` | `searching → stabilizing → ready → captured` auto-capture FSM |

```dart
import 'package:inf_orc_kit/inf_orc_kit.dart';

final session = DocCaptureSession(steadyFramesRequired: 8);

// Per camera frame (wire your own detector: ML Kit, Vision, contours):
final state = session.onFrame(detectedQuad, imageSize);
if (state == CaptureState.ready) {
  final quad = session.quad!;
  final dst = Perspective.destinationSize(quad);
  final h = Perspective.homography(quad, dst);
  // warp pixels to dst, then: await OcrKit.recognizeNative(croppedPath);
  session.markCaptured();
}
```

### OcrResult

| Property | Type | Description |
|----------|------|-------------|
| `fullText` | String | Concatenated text from all lines |
| `textLines` | List\<TextLine\> | Individual text lines with positions |
| `imageWidth` | int | Source image width |
| `imageHeight` | int | Source image height |

### TextLine

| Property | Type | Description |
|----------|------|-------------|
| `text` | String | Recognized text content |
| `score` | double | Confidence score (0.0 - 1.0) |
| `rect` | Rect | Bounding box position |
| `wordBoxes` | List\<Rect\> | Word-level bounding boxes |

### LayoutResult

| Property | Type | Description |
|----------|------|-------------|
| `detections` | List\<LayoutDetection\> | Detected regions |
| `count` | int | Number of detected regions |

### LayoutDetection

| Property | Type | Description |
|----------|------|-------------|
| `className` | String | Region type (Table, Text, Title, Figure, etc.) |
| `x1, y1, x2, y2` | double | Bounding box coordinates |
| `score` | double | Detection confidence |

## Building from Source

### Prerequisites

- Flutter SDK 3.7+
- Xcode 14+ (for iOS)
- Android NDK (for Android)

### Build Commands

```bash
# Run example app
cd example && flutter run

# Analyze code
flutter analyze

# Build Android native library (.so)
./scripts/build_android_so.sh

# Build iOS static library (.a)
./scripts/build_ios_static.sh
```

## Author

**Arun Infinity**
- GitHub: https://github.com/aruninf
- Project: https://github.com/aruninf/inf_orc_kit

Based on `flutter_ocr_kit` by Robert Chuang.

## License

Apache License 2.0 (see LICENSE)
