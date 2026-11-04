import 'dart:io';
import 'package:document_scan/document_scan.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class to persist processed [ScannedDocument] images to disk files.
class DocumentFileSaver {
  const DocumentFileSaver._();

  /// Writes [document.bytes] to a file on disk.
  ///
  /// If [directory] is omitted, defaults to the application's temporary cache directory.
  ///
  /// Returns the absolute path of the saved file.
  static Future<String> saveScannedDocument(
    ScannedDocument document, {
    int index = 0,
    String format = 'jpg',
    Directory? directory,
  }) async {
    final targetDir = directory ?? await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${targetDir.path}/scanned_doc_${timestamp}_$index.$format');
    await file.writeAsBytes(document.bytes, flush: true);
    return file.path;
  }
}

