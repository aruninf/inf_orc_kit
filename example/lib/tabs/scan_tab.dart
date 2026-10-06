import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:inf_orc_kit/inf_orc_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Full scan flow demo: pick → adjust corners → enhance → OCR.
///
/// Shows how [QuadEditor], [warpQuadToRect], [enhanceImage], [DocSession]
/// and [DocOcr] fit together. Swap the picker for your camera screen and
/// [FullFrameEdgeDetector] for a real detector to go live.
class ScanTab extends StatefulWidget {
  const ScanTab({super.key});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  final ImagePicker _picker = ImagePicker();
  final DocSession _session = DocSession();

  Uint8List? _bytes;
  ui.Image? _image;
  DocumentQuad? _quad;
  EnhancePreset _preset = EnhancePreset.document;
  Uint8List? _enhanced;
  OcrResult? _ocr;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _enhanced = null;
      _ocr = null;
    });
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);
      final size = Size(
          image.width.toDouble(), image.height.toDouble());
      final quad = await const FullFrameEdgeDetector()
          .detect(imageSize: size, imageBytes: bytes);
      setState(() {
        _bytes = bytes;
        _image = image;
        _quad = quad;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _enhance() async {
    final bytes = _bytes;
    final quad = _quad;
    if (bytes == null || quad == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final warped = warpQuadToRect(bytes, quad);
      final enhanced = enhanceImage(warped,
          options: EnhanceOptions.preset(_preset));
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(enhanced);
      _session.addPage(out.path, quad: quad);
      setState(() => _enhanced = enhanced);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runOcr() async {
    if (_session.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await DocOcr.readAll(_session.exportPaths());
      setState(() => _ocr = results.isEmpty ? null : results.first);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick image'),
            ),
            const SizedBox(width: 8),
            Text('${_session.length} page(s)'),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: const TextStyle(color: Colors.red)),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_bytes != null && _quad != null) ...[
          const SizedBox(height: 12),
          const Text('1. Drag corners to the document edges'),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: QuadEditor(
              imageSize: Size(_image!.width.toDouble(),
                  _image!.height.toDouble()),
              quad: _quad!,
              onChanged: (q) => setState(() => _quad = q),
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 12),
          const Text('2. Pick a clean-up style, then enhance'),
          DropdownButton<EnhancePreset>(
            value: _preset,
            items: EnhancePreset.values
                .map((p) =>
                    DropdownMenuItem(value: p, child: Text(p.name)))
                .toList(),
            onChanged: (p) =>
                setState(() => _preset = p ?? _preset),
          ),
          ElevatedButton.icon(
            onPressed: _busy ? null : _enhance,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Enhance'),
          ),
        ],
        if (_enhanced != null) ...[
          const SizedBox(height: 12),
          const Text('3. Enhanced result'),
          Image.memory(_enhanced!),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _busy ? null : _runOcr,
            icon: const Icon(Icons.text_fields),
            label: const Text('Run OCR'),
          ),
        ],
        if (_ocr != null) ...[
          const SizedBox(height: 12),
          const Text('4. Recognized text'),
          SelectableText(_ocr!.hasError
              ? 'Error: ${_ocr!.error}'
              : _ocr!.fullText),
        ],
      ],
    );
  }
}
