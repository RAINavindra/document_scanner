import 'dart:io';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

import '../controller/document_scanner_controller.dart';
import '../models/overlay_style.dart';
import '../models/scanned_document_page.dart';
import '../utils/file_saver.dart';
import 'document_scanner_camera.dart';
import 'multi_document_review_screen.dart';

/// Full-screen document scanner flow supporting single-page and multi-page
/// batch scanning, gallery import, manual corner adjustment, and image filtering.
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({
    super.key,
    this.isGalleryImportAllowed = false,
    this.noOfPages = 1,
    this.edgeColor,
    this.steadyEdgeColor,
    this.fillColor,
    this.overlayStyle = const OverlayStyle(),
    this.initialFilter = ScanFilter.enhance,
    this.imageFilters,
    this.appBarTitle = 'Scan Document',
    this.showPreviewConfirmation = true,
    this.enableTapToFocus = true,
    this.showFlashlight,
    this.outputDirectory,
  });

  /// Whether to allow importing photos from the device gallery.
  final bool isGalleryImportAllowed;

  /// Maximum number of pages to scan. Defaults to 1 (single-page mode).
  /// If set to 1, completes and returns immediately after the first scan is confirmed.
  /// If > 1, allows batch scanning until the limit is reached or the user taps 'Done'.
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

  /// Whether to display a preview screen showing the cropped document before finalizing.
  final bool showPreviewConfirmation;

  /// Whether to allow the user to tap on the camera preview to focus and meter exposure.
  final bool enableTapToFocus;

  /// Explicit override to show/hide the flashlight toggle. If null, automatically detects
  /// whether the device camera has a physical flashlight unit.
  final bool? showFlashlight;

  /// Optional custom directory where saved document files will be written.
  /// If null, defaults to the temporary directory.
  final Directory? outputDirectory;

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  late final DocumentScannerController _controller;
  final List<ScannedDocumentPage> _scannedPages = [];
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

  Future<void> _handlePageScanned(ScannedDocumentPage page) async {
    setState(() {
      _scannedPages.add(page);
    });

    final effectiveLimit = widget.noOfPages ?? 1;
    final isSinglePage = effectiveLimit == 1;
    final reachedLimit = _scannedPages.length >= effectiveLimit;

    if (mounted) {
      if (isSinglePage) {
        // Single-page mode -> finalize directly
        await _saveAndFinish();
      } else if (reachedLimit) {
        // Reached limit in multi-page mode -> open review screen directly
        await _openReviewScreen();
      } else {
        // Multi-page batch mode -> resume camera stream for next document
        await _controller.resumePreview();
      }
    }
  }

  Future<void> _handleScanned(ScannedDocument document) async {
    // Fallback if onPageScanned wasn't triggered
    if (_scannedPages.isEmpty || _scannedPages.last.document != document) {
      final page = ScannedDocumentPage(
        originalImagePath: _controller.lastCapturedImagePath ?? '',
        corners: _controller.lastCropCorners ??
            const DocumentCorners(
              topLeft: (x: 0.08, y: 0.08),
              topRight: (x: 0.92, y: 0.08),
              bottomRight: (x: 0.92, y: 0.92),
              bottomLeft: (x: 0.08, y: 0.92),
            ),
        document: document,
        baseDocument: document,
        filter: widget.initialFilter,
      );
      await _handlePageScanned(page);
    }
  }

  Future<void> _openReviewScreen() async {
    if (_scannedPages.isEmpty) return;

    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => MultiDocumentReviewScreen(
          pages: _scannedPages,
          controller: _controller,
          noOfPages: widget.noOfPages,
          outputDirectory: widget.outputDirectory,
          imageFilters: widget.imageFilters ??
              const [
                ScanFilter.none,
                ScanFilter.enhance,
                ScanFilter.magicColor,
                ScanFilter.blackWhite,
                ScanFilter.grayscale,
                ScanFilter.sharpen,
              ],
          overlayStyle: widget.overlayStyle,
          appBarTitle: widget.appBarTitle,
        ),
      ),
    );

    if (result is List<String> && mounted) {
      // User confirmed all pages in review screen
      Navigator.of(context).pop(result);
    } else if (result is List<ScannedDocumentPage> && mounted) {
      // User deleted, rotated, re-cropped, or tapped "+ Add"
      setState(() {
        _scannedPages
          ..clear()
          ..addAll(result);
      });
      await _controller.resumePreview();
    } else if (mounted) {
      // User tapped back from review screen to scan more pages
      await _controller.resumePreview();
      setState(() {});
    }
  }

  Future<void> _saveAndFinish() async {
    if (_isSaving || _scannedPages.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final filePaths = <String>[];
      for (var i = 0; i < _scannedPages.length; i++) {
        final path = await DocumentFileSaver.saveScannedDocument(
          _scannedPages[i].document,
          index: i,
          directory: widget.outputDirectory,
        );
        filePaths.add(path);
      }
      if (mounted) {
        Navigator.of(context).pop(filePaths);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _title {
    if (widget.noOfPages != null && widget.noOfPages! > 1) {
      return '${widget.appBarTitle} (${_scannedPages.length}/${widget.noOfPages})';
    } else if (_scannedPages.isNotEmpty) {
      return '${widget.appBarTitle} (${_scannedPages.length})';
    }
    return widget.appBarTitle;
  }

  Widget? _buildDoneButton() {
    if (widget.noOfPages == 1 || _scannedPages.isEmpty) {
      return null;
    }

    return GestureDetector(
      onTap: _openReviewScreen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                _scannedPages.last.document.bytes,
                width: 22,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Review (${_scannedPages.length})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _scannedPages.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_scannedPages.isNotEmpty) {
          _openReviewScreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            DocumentScannerCamera(
              controller: _controller,
              appBarTitle: _title,
              isGalleryImportAllowed: widget.isGalleryImportAllowed,
              showPreviewConfirmation: widget.showPreviewConfirmation,
              enableTapToFocus: widget.enableTapToFocus,
              noOfPages: widget.noOfPages,
              currentPagesCount: _scannedPages.length,
              showFlashlight: widget.showFlashlight,
              onClose: () {
                if (_scannedPages.isNotEmpty) {
                  _openReviewScreen();
                } else {
                  Navigator.of(context).pop(null);
                }
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
              onPageScanned: _handlePageScanned,
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
