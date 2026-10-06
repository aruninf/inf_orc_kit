## 1.2.0

* New scan foundation: `DocPage`, `DocSession` (multi-page), `EdgeDetector` interface + full-frame fallback, `DocOcr` batch facade
* New `QuadEditor` widget for drag-to-adjust document corners
* New pure-Dart enhance pipeline: `warpQuadToRect` (perspective straighten), `enhanceImage` with presets (document/receipt/idCard/blackWhite)
* Move `OcrKit` into `src/ocr/`, barrel is now export-only
* Example: new Scan tab (pick → adjust → enhance → OCR)

## 1.1.0

* Add pure-Dart document capture core (`DocumentQuad`, `Perspective`, `CapturePolicy`, `DocCaptureSession`) — no native deps, extractable as own pub
* Fix Android namespace, add pub topics
* Add `OcrResult.textLines` alias (README compat), decouple `kie_extractor` from `flutter/material`
* Add `test/capture_test.dart`
* Fix README license (Apache-2.0) + API table

## 1.0.0

* Initial release
* Native OCR using Apple Vision (iOS) and Google ML Kit (Android)
* Layout Detection using ONNX Runtime with PP-DocLayout model
* Real-time camera OCR support
* Key Information Extraction (KIE) for dates, phone numbers, amounts
* Invoice scanner demo (Taiwan e-invoice format)
* Quotation scanner demo with Layout Detection + OCR
* iOS: Core ML Execution Provider for faster inference
* Memory management: `OcrKit.releaseLayout()` to free resources
