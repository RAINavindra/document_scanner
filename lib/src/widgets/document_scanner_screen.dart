import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

import '../controller/document_scanner_controller.dart';
import '../models/overlay_style.dart';
import '../utils/file_saver.dart';
import 'document_scanner_camera.dart';

/// Full-screen document scanner flow supporting single-page and multi-page
/// batch scanning, gallery import, manual corner adjustment, and image filtering.
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({
    super.key,
    this.isGalleryImportAllowed = false,
    this.noOfPages,
    this.edgeColor,
    this.steadyEdgeColor,
    this.fillColor,
    this.overlayStyle = const OverlayStyle(),
    this.initialFilter = ScanFilter.enhance,
    this.imageFilters,
    this.appBarTitle = 'Scan Document',
  });

  /// Whether to allow importing photos from the device gallery.
  final bool isGalleryImportAllowed;

  /// Maximum number of pages to scan.
  /// If set to 1, completes and returns immediately after the first scan.
  /// If null or > 1, allows batch scanning until the limit is reached or the user taps 'Done'.
  final int? noOfPages;

  /// Shortcut for the detected edge line color.
  final Color? edgeColor;

  /// Shortcut for the steady edge line color.
  final Color? steadyEdgeColor;

  /// Shortcut for the quad fill color.
  final Color? fillColor;

  /// Granular styling options for the overlay quad.
  final OverlayStyle overlayStyle;

  /// Filter selected by default.
  final ScanFilter initialFilter;

  /// Available filters in the adjustment screen.
  final List<ScanFilter>? imageFilters;

  /// Title displayed in the top bar.
  final String appBarTitle;

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  late final DocumentScannerController _controller;
  final List<String> _scannedFilePaths = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = DocumentScannerController(
      defaultFilter: widget.initialFilter,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScanned(ScannedDocument document) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final filePath = await DocumentFileSaver.saveScannedDocument(
        document,
        index: _scannedFilePaths.length,
      );

      _scannedFilePaths.add(filePath);

      // Check if session is complete
      final isSinglePage = widget.noOfPages == 1;
      final reachedLimit =
          widget.noOfPages != null && _scannedFilePaths.length >= widget.noOfPages!;

      if (mounted) {
        if (isSinglePage || reachedLimit) {
          Navigator.of(context).pop(_scannedFilePaths);
        } else {
          // Resume preview for next page
          await _controller.resumePreview();
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save document: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String get _title {
    if (widget.noOfPages != null && widget.noOfPages! > 1) {
      return '${widget.appBarTitle} (${_scannedFilePaths.length}/${widget.noOfPages})';
    } else if (_scannedFilePaths.isNotEmpty) {
      return '${widget.appBarTitle} (${_scannedFilePaths.length})';
    }
    return widget.appBarTitle;
  }

  Widget? _buildDoneButton() {
    if (widget.noOfPages == 1 || _scannedFilePaths.isEmpty) {
      return null;
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(_scannedFilePaths),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Done (${_scannedFilePaths.length})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.check, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(
          _scannedFilePaths.isNotEmpty ? _scannedFilePaths : null,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            DocumentScannerCamera(
              controller: _controller,
              appBarTitle: _title,
              isGalleryImportAllowed: widget.isGalleryImportAllowed,
              onClose: () {
                Navigator.of(context).pop(
                  _scannedFilePaths.isNotEmpty ? _scannedFilePaths : null,
                );
              },
              edgeColor: widget.edgeColor,
              steadyEdgeColor: widget.steadyEdgeColor,
              fillColor: widget.fillColor,
              overlayStyle: widget.overlayStyle,
              initialFilter: widget.initialFilter,
              imageFilters: widget.imageFilters ??
                  const [
                    ScanFilter.none,
                    ScanFilter.enhance,
                    ScanFilter.magicColor,
                    ScanFilter.blackWhite,
                    ScanFilter.grayscale,
                    ScanFilter.sharpen,
                  ],
              bottomTrailingWidget: _buildDoneButton(),
              onScanned: _handleScanned,
              onError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $error')),
                );
              },
            ),
            if (_isSaving)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Saving scanned page...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
