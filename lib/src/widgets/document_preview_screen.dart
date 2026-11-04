import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

import '../controller/document_scanner_controller.dart';

/// Result returned from [DocumentPreviewScreen] back to the crop adjustment screen.
class DocumentPreviewResult {
  const DocumentPreviewResult({
    this.document,
    this.isRetake = false,
  });

  /// The finalized document confirmed by the user.
  final ScannedDocument? document;

  /// Whether the user requested to retake the photo entirely.
  final bool isRetake;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPreviewResult &&
          runtimeType == other.runtimeType &&
          document == other.document &&
          isRetake == other.isRetake;

  @override
  int get hashCode => Object.hash(document, isRetake);

  @override
  String toString() =>
      'DocumentPreviewResult(isRetake: $isRetake, hasDoc: ${document != null})';
}

/// Screen allowing users to inspect the final cropped, deskewed, and filtered
/// document before confirming and saving it.
///
/// Features:
/// - Pinch-to-zoom interactive document inspection.
/// - 90° clockwise rotation.
/// - Non-destructive filter switching (Original, Enhance, Magic Color, B&W, Grayscale, Sharpen).
/// - Re-crop action to return to corner adjustment.
/// - Retake action to discard and return to camera preview.
class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({
    super.key,
    required this.initialDocument,
    required this.baseUnfilteredDocument,
    required this.controller,
    this.initialFilter = ScanFilter.enhance,
    this.imageFilters = const [
      ScanFilter.none,
      ScanFilter.enhance,
      ScanFilter.magicColor,
      ScanFilter.blackWhite,
      ScanFilter.grayscale,
      ScanFilter.sharpen,
    ],
    this.appBarTitle = 'Document Preview',
  });

  /// The initially processed document to display.
  final ScannedDocument initialDocument;

  /// The perspective-corrected document with [ScanFilter.none], used for non-destructive filter switching.
  final ScannedDocument baseUnfilteredDocument;

  /// Active controller providing filter and rotation operations.
  final DocumentScannerController controller;

  /// The filter currently applied to [initialDocument].
  final ScanFilter initialFilter;

  /// List of filters available in the filter selector.
  final List<ScanFilter> imageFilters;

  /// Title displayed in the top bar.
  final String appBarTitle;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  late ScannedDocument _currentDoc;
  late ScannedDocument _baseDoc;
  late ScanFilter _selectedFilter;
  late final List<ScanFilter> _filters;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.initialDocument;
    _baseDoc = widget.baseUnfilteredDocument;
    _selectedFilter = widget.initialFilter;

    // Deduplicate filters and ensure initial filter is included
    final unique = widget.imageFilters.toSet().toList();
    if (unique.isEmpty) {
      unique.addAll(const [
        ScanFilter.none,
        ScanFilter.enhance,
        ScanFilter.magicColor,
        ScanFilter.blackWhite,
        ScanFilter.grayscale,
        ScanFilter.sharpen,
      ]);
    }
    if (!unique.contains(_selectedFilter)) {
      unique.insert(0, _selectedFilter);
    }
    _filters = unique;
  }

  Future<void> _handleRotate() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final rotatedCurrent = await widget.controller.rotateDocument(_currentDoc, degrees: 90);
      final rotatedBase = await widget.controller.rotateDocument(_baseDoc, degrees: 90);

      if (mounted && rotatedCurrent != null && rotatedBase != null) {
        setState(() {
          _currentDoc = rotatedCurrent;
          _baseDoc = rotatedBase;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rotate document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFilterChanged(ScanFilter filter) async {
    if (_isProcessing || _selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
      _isProcessing = true;
    });

    try {
      if (filter == ScanFilter.none) {
        setState(() => _currentDoc = _baseDoc);
      } else {
        final filtered = await widget.controller.applyFilterToDocument(_baseDoc, filter);
        if (mounted && filtered != null) {
          setState(() => _currentDoc = filtered);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply filter: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _getFilterLabel(ScanFilter filter) {
    switch (filter) {
      case ScanFilter.none:
        return 'Original';
      case ScanFilter.enhance:
        return 'Enhance';
      case ScanFilter.magicColor:
        return 'Magic Color';
      case ScanFilter.blackWhite:
        return 'Black & White';
      case ScanFilter.grayscale:
        return 'Grayscale';
      case ScanFilter.sharpen:
        return 'Sharpen';
    }
  }

  void _onConfirm() {
    Navigator.of(context).pop(
      DocumentPreviewResult(document: _currentDoc, isRetake: false),
    );
  }

  void _onRetake() {
    Navigator.of(context).pop(
      const DocumentPreviewResult(isRetake: true),
    );
  }

  void _onReCrop() {
    // Pop back to CropAdjustmentScreen with null document so user can re-adjust handles
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate 90°',
            onPressed: _isProcessing ? null : _handleRotate,
          ),
          IconButton(
            icon: const Icon(Icons.crop),
            tooltip: 'Adjust Crop',
            onPressed: _isProcessing ? null : _onReCrop,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview area with pinch-to-zoom
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.memory(
                          _currentDoc.bytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // Processing spinner overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Applying...',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Filter selector bar
            if (_filters.length > 1)
              Container(
                color: Colors.grey[900],
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(_getFilterLabel(filter)),
                          selected: isSelected,
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          onSelected: (selected) {
                            if (selected) {
                              _handleFilterChanged(filter);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Bottom action bar (Retake + Confirm)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                      onPressed: _isProcessing ? null : _onRetake,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm'),
                      onPressed: _isProcessing ? null : _onConfirm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

