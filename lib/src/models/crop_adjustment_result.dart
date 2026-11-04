import 'package:document_scan/document_scan.dart';
import 'scanned_document_page.dart';

/// The result returned from [CropAdjustmentScreen], containing both the cropped
/// documents and the source image geometry for re-cropping and multi-page review.
class CropAdjustmentResult {
  const CropAdjustmentResult({
    required this.document,
    required this.baseDocument,
    required this.originalImagePath,
    required this.corners,
    this.filter = ScanFilter.enhance,
    this.rotationDegrees = 0,
  });

  /// The processed document with the user's selected filter applied.
  final ScannedDocument document;

  /// The perspective-corrected document with [ScanFilter.none] applied,
  /// used for subsequent non-destructive filter switching.
  final ScannedDocument baseDocument;

  /// Absolute file path to the uncropped original high-resolution photo.
  final String originalImagePath;

  /// The 4 corner coordinates (normalized 0..1) used for this crop.
  final DocumentCorners corners;

  /// The filter applied to [document].
  final ScanFilter filter;

  /// Rotation applied in degrees (0, 90, 180, 270).
  final int rotationDegrees;

  /// Converts this result into a [ScannedDocumentPage] representation.
  ScannedDocumentPage toScannedDocumentPage() {
    return ScannedDocumentPage(
      originalImagePath: originalImagePath,
      corners: corners,
      document: document,
      baseDocument: baseDocument,
      filter: filter,
      rotationDegrees: rotationDegrees,
    );
  }
}
