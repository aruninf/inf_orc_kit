import '../capture/document_quad.dart';
import '../core/doc_page.dart';

/// In-memory multi-page scan session.
///
/// Owns an ordered list of [DocPage]s: add captures, reorder for the
/// final document, drop mistakes, then hand [exportPaths] to your PDF
/// builder / uploader. Pure Dart — no storage plugin required.
class DocSession {
  final List<DocPage> _pages = [];

  List<DocPage> get pages => List.unmodifiable(_pages);
  int get length => _pages.length;
  bool get isEmpty => _pages.isEmpty;
  bool get isNotEmpty => _pages.isNotEmpty;

  /// Append a capture. Returns the created page.
  DocPage addPage(String imagePath, {DocumentQuad? quad}) {
    final page = DocPage(imagePath: imagePath, quad: quad);
    _pages.add(page);
    return page;
  }

  /// Replace a page (e.g. after adjust/enhance). Returns false if unknown id.
  bool updatePage(DocPage page) {
    final i = _pages.indexWhere((p) => p.id == page.id);
    if (i < 0) return false;
    _pages[i] = page;
    return true;
  }

  /// Remove a page. Returns false if unknown id.
  bool removePage(String id) {
    final i = _pages.indexWhere((p) => p.id == id);
    if (i < 0) return false;
    _pages.removeAt(i);
    return true;
  }

  /// Move a page (for thumbnail-strip reorder UI).
  void movePage(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _pages.length ||
        newIndex < 0 ||
        newIndex >= _pages.length) {
      throw RangeError('Page index out of range');
    }
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
  }

  void clear() => _pages.clear();

  /// Paths for export/OCR. Prefers enhanced images when available.
  List<String> exportPaths({bool preferEnhanced = true}) => _pages
      .map((p) => preferEnhanced ? p.bestPath : p.imagePath)
      .toList();
}
