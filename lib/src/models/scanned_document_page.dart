import 'package:document_scan/document_scan.dart';

/// Represents a single scanned document page in a scanning session,
/// keeping track of both the cropped output and the original source image
/// for re-cropping and non-destructive adjustments.
class ScannedDocumentPage {
  ScannedDocumentPage({
    required this.originalImagePath,
    required this.corners,
    required this.document,
    required this.baseDocument,
    this.filter = ScanFilter.enhance,
    this.rotationDegrees = 0,
  });

  /// Path to the original full-resolution photo (un-cropped source image on disk).
  final String originalImagePath;

  /// The document corners applied to crop the document from [originalImagePath].
  DocumentCorners corners;

  /// The currently active processed document (with filter & rotation applied).
  ScannedDocument document;

  /// The un-filtered perspective-corrected document (ScanFilter.none),
  /// used for non-destructive filter switching and rotation.
  ScannedDocument baseDocument;

  /// The currently selected filter.
  ScanFilter filter;

  /// Cumulative rotation in degrees (0, 90, 180, 270).
  int rotationDegrees;

  ScannedDocumentPage copyWith({
    String? originalImagePath,
    DocumentCorners? corners,
    ScannedDocument? document,
    ScannedDocument? baseDocument,
    ScanFilter? filter,
    int? rotationDegrees,
  }) {
    return ScannedDocumentPage(
      originalImagePath: originalImagePath ?? this.originalImagePath,
      corners: corners ?? this.corners,
      document: document ?? this.document,
      baseDocument: baseDocument ?? this.baseDocument,
      filter: filter ?? this.filter,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }
}

