import '../capture/document_quad.dart';

/// One scanned document page.
///
/// A page starts as a photo ([imagePath]) and optionally gains a detected
/// or user-adjusted [quad] and an [enhancedPath] (straightened + cleaned).
/// OCR results are intentionally NOT stored here — run [DocOcr] on
/// [bestPath] whenever you need text, so pages stay lightweight.
class DocPage {
  /// Stable id, unique within a session.
  final String id;

  /// Original photo path.
  final String imagePath;

  /// Document corners in original photo pixels (null = full frame).
  final DocumentQuad? quad;

  /// Enhanced (warped + cleaned) image path, if produced.
  final String? enhancedPath;

  final DateTime createdAt;

  DocPage({
    String? id,
    required this.imagePath,
    this.quad,
    this.enhancedPath,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  /// Path OCR/enhance steps should prefer.
  String get bestPath => enhancedPath ?? imagePath;

  bool get isEnhanced => enhancedPath != null;

  DocPage copyWith({
    String? imagePath,
    DocumentQuad? quad,
    String? enhancedPath,
  }) {
    return DocPage(
      id: id,
      imagePath: imagePath ?? this.imagePath,
      quad: quad ?? this.quad,
      enhancedPath: enhancedPath ?? this.enhancedPath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'quad': quad?.toJson(),
        'enhancedPath': enhancedPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DocPage.fromJson(Map<String, dynamic> json) {
    final quadJson = json['quad'];
    return DocPage(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      quad: quadJson == null
          ? null
          : DocumentQuad.fromJson(
              (quadJson as Map).cast<String, dynamic>()),
      enhancedPath: json['enhancedPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
