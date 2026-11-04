import 'dart:io';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

import '../controller/document_scanner_controller.dart';
import '../models/crop_adjustment_result.dart';
import '../models/overlay_style.dart';
import 'document_preview_screen.dart';
import 'quad_overlay_painter.dart';

/// Screen allowing users to manually adjust the 4 detected document corners
/// and select a processing filter before finalizing the scan.
class CropAdjustmentScreen extends StatefulWidget {
  const CropAdjustmentScreen({
    super.key,
    required this.imagePath,
    required this.initialCorners,
    required this.controller,
    this.overlayStyle = const OverlayStyle(
      showCornerDots: true,
      borderWidth: 2.0,
    ),
    this.initialFilter = ScanFilter.enhance,
    this.onCropped,
    this.imageFilters = const [
      ScanFilter.none,
      ScanFilter.enhance,
      ScanFilter.magicColor,
      ScanFilter.blackWhite,
      ScanFilter.grayscale,
      ScanFilter.sharpen,
    ],
    this.showPreviewConfirmation = true,
  });

  /// Path to the captured full-resolution image file.
  final String imagePath;

  /// The automatically detected corners (normalized 0..1).
  final DocumentCorners initialCorners;

  /// Scanner controller used to execute the perspective crop.
  final DocumentScannerController controller;

  /// Style applied to the adjustment polygon and handles.
  final OverlayStyle overlayStyle;

  /// Filter selected by default.
  final ScanFilter initialFilter;

  /// Callback invoked when the document has been cropped and processed.
  final ValueChanged<ScannedDocument>? onCropped;

  /// Available image filters to display in the selector.
  final List<ScanFilter> imageFilters;

  /// Whether to show the [DocumentPreviewScreen] after cropping before final confirmation.
  final bool showPreviewConfirmation;

  @override
  State<CropAdjustmentScreen> createState() => _CropAdjustmentScreenState();
}

class _CropAdjustmentScreenState extends State<CropAdjustmentScreen> {
  late ScanPoint _tl;
  late ScanPoint _tr;
  late ScanPoint _br;
  late ScanPoint _bl;
  late final List<ScanFilter> _filters;
  late ScanFilter _selectedFilter;
  bool _isProcessing = false;

  Size? _imageSize;

  // Active dragged corner index (0: TL, 1: TR, 2: BR, 3: BL) or null
  int? _activeCornerIndex;
  Offset? _dragPosition;

  @override
  void initState() {
    super.initState();
    _tl = widget.initialCorners.topLeft;
    _tr = widget.initialCorners.topRight;
    _br = widget.initialCorners.bottomRight;
    _bl = widget.initialCorners.bottomLeft;

    // 1. Deduplicate filters while preserving insertion order
    final unique = widget.imageFilters.toSet().toList();

    // 2. Fallback to default filters if list is empty
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

    // 3. Ensure initialFilter is present in the list
    if (!unique.contains(widget.initialFilter)) {
      unique.insert(0, widget.initialFilter);
    }

    _filters = unique;
    _selectedFilter = widget.initialFilter;
    _resolveImageSize();
  }

  void _resolveImageSize() {
    final image = FileImage(File(widget.imagePath));
    image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (ImageInfo info, bool _) {
              if (mounted) {
                setState(() {
                  _imageSize = Size(
                    info.image.width.toDouble(),
                    info.image.height.toDouble(),
                  );
                });
              }
            },
            onError: (dynamic error, StackTrace? stackTrace) {
              debugPrint('Error resolving image size: $error');
            },
          ),
        );
  }

  Rect _computeImageRect(Size container, Size imageSize) {
    if (imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        container.width <= 0 ||
        container.height <= 0) {
      return Offset.zero & container;
    }
    final containerAspect = container.width / container.height;
    final imageAspect = imageSize.width / imageSize.height;

    final double w, h;
    if (imageAspect > containerAspect) {
      w = container.width;
      h = container.width / imageAspect;
    } else {
      h = container.height;
      w = container.height * imageAspect;
    }

    return Rect.fromLTWH(
      (container.width - w) / 2,
      (container.height - h) / 2,
      w,
      h,
    );
  }

  DocumentCorners get _currentCorners => DocumentCorners(
    topLeft: _tl,
    topRight: _tr,
    bottomRight: _br,
    bottomLeft: _bl,
  );

  Future<void> _handleConfirm() async {
    setState(() => _isProcessing = true);
    try {
      if (widget.showPreviewConfirmation) {
        // 1. Crop base warped image with ScanFilter.none for non-destructive preview filtering
        final baseDoc = await widget.controller.cropFile(
          widget.imagePath,
          _currentCorners,
          filter: ScanFilter.none,
        );
        if (baseDoc == null || !mounted) return;

        // 2. Apply selected filter if different from none
        final initialFiltered = _selectedFilter == ScanFilter.none
            ? baseDoc
            : await widget.controller.applyFilterToDocument(baseDoc, _selectedFilter);
        if (initialFiltered == null || !mounted) return;

        // 3. Open DocumentPreviewScreen for user inspection and confirmation
        final result = await Navigator.of(context).push<DocumentPreviewResult>(
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(
              initialDocument: initialFiltered,
              baseUnfilteredDocument: baseDoc,
              controller: widget.controller,
              initialFilter: _selectedFilter,
              imageFilters: _filters,
            ),
          ),
        );

        if (!mounted || result == null) {
          // User chose to re-adjust crop corners — stay on this screen
          return;
        }

        if (result.isRetake) {
          // User chose to retake photo entirely
          widget.controller.resumePreview();
          Navigator.of(context).pop();
          return;
        }

        if (result.document != null) {
          final cropResult = CropAdjustmentResult(
            document: result.document!,
            baseDocument: baseDoc,
            originalImagePath: widget.imagePath,
            corners: _currentCorners,
            filter: _selectedFilter,
          );
          widget.onCropped?.call(result.document!);
          Navigator.of(context).pop(cropResult);
        }
      } else {
        // Direct crop without separate preview screen
        final baseDoc = await widget.controller.cropFile(
          widget.imagePath,
          _currentCorners,
          filter: ScanFilter.none,
        );
        final doc = _selectedFilter == ScanFilter.none
            ? baseDoc
            : (baseDoc != null
                ? await widget.controller.applyFilterToDocument(
                    baseDoc,
                    _selectedFilter,
                  )
                : null);

        if (mounted && doc != null) {
          final cropResult = CropAdjustmentResult(
            document: doc,
            baseDocument: baseDoc ?? doc,
            originalImagePath: widget.imagePath,
            corners: _currentCorners,
            filter: _selectedFilter,
          );
          widget.onCropped?.call(doc);
          Navigator.of(context).pop(cropResult);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _resetCorners() {
    setState(() {
      _tl = const (x: 0.05, y: 0.05);
      _tr = const (x: 0.95, y: 0.05);
      _br = const (x: 0.95, y: 0.95);
      _bl = const (x: 0.05, y: 0.95);
    });
  }

  void _updateCorner(int index, Offset delta, Rect imageRect) {
    final dx = imageRect.width > 0 ? delta.dx / imageRect.width : 0.0;
    final dy = imageRect.height > 0 ? delta.dy / imageRect.height : 0.0;

    setState(() {
      switch (index) {
        case 0:
          _tl = (
            x: (_tl.x + dx).clamp(0.0, 1.0),
            y: (_tl.y + dy).clamp(0.0, 1.0),
          );
          break;
        case 1:
          _tr = (
            x: (_tr.x + dx).clamp(0.0, 1.0),
            y: (_tr.y + dy).clamp(0.0, 1.0),
          );
          break;
        case 2:
          _br = (
            x: (_br.x + dx).clamp(0.0, 1.0),
            y: (_br.y + dy).clamp(0.0, 1.0),
          );
          break;
        case 3:
          _bl = (
            x: (_bl.x + dx).clamp(0.0, 1.0),
            y: (_bl.y + dy).clamp(0.0, 1.0),
          );
          break;
      }
    });
  }

  Widget _buildCornerHandle(int index, ScanPoint point, Rect imageRect) {
    const handleHitbox = 44.0;
    final pos = Offset(
      imageRect.left + point.x * imageRect.width,
      imageRect.top + point.y * imageRect.height,
    );

    return Positioned(
      left: pos.dx - (handleHitbox / 2),
      top: pos.dy - (handleHitbox / 2),
      width: handleHitbox,
      height: handleHitbox,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          setState(() {
            _activeCornerIndex = index;
            _dragPosition = pos;
          });
        },
        onPanUpdate: (details) {
          _updateCorner(index, details.delta, imageRect);
          setState(() {
            _dragPosition = Offset(
              details.globalPosition.dx,
              details.globalPosition.dy,
            );
          });
        },
        onPanEnd: (_) {
          setState(() {
            _activeCornerIndex = null;
            _dragPosition = null;
          });
        },
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: widget.overlayStyle.cornerDotColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.overlayStyle.borderColor,
                width: 3.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildFilterChip(ScanFilter filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(_getFilterLabel(filter)),
        selected: isSelected,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        onSelected: (selected) {
          // Ignore if already selected to prevent redundant rebuilds
          if (selected && _selectedFilter != filter) {
            setState(() => _selectedFilter = filter);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust Document Crop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_free),
            tooltip: 'Reset Corners',
            onPressed: _resetCorners,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview area with draggable corners
            Expanded(
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final imageRect = _imageSize != null
                          ? _computeImageRect(size, _imageSize!)
                          : (Offset.zero & size);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base image
                          InteractiveViewer(
                            panEnabled: false,
                            scaleEnabled: false,
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.contain,
                              width: size.width,
                              height: size.height,
                            ),
                          ),

                          // Real-time quad path
                          CustomPaint(
                            size: size,
                            painter: QuadOverlayPainter(
                              corners: _currentCorners,
                              style: widget.overlayStyle.copyWith(
                                fillColor: widget.overlayStyle.fillColor,
                                showCornerDots: false,
                              ),
                              imageRect: imageRect,
                            ),
                          ),

                          // Draggable corner handles
                          _buildCornerHandle(0, _tl, imageRect),
                          _buildCornerHandle(1, _tr, imageRect),
                          _buildCornerHandle(2, _br, imageRect),
                          _buildCornerHandle(3, _bl, imageRect),

                          // Magnifier glass while dragging
                          if (_activeCornerIndex != null &&
                              _dragPosition != null)
                            RawMagnifier(
                              focalPointOffset: const Offset(0, -50),
                              magnificationScale: 1.8,
                              size: const Size(90, 90),
                              decoration: MagnifierDecoration(
                                shape: const CircleBorder(
                                  side: BorderSide(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                shadows: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  // Processing overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Processing...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Filter selector
            if (_filters.length > 1)
              Container(
                color: Colors.grey[900],
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: _filters
                        .map((filter) => _buildFilterChip(filter))
                        .toList(),
                  ),
                ),
              ),

            // Bottom action buttons
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
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retake'),
                      onPressed: _isProcessing
                          ? null
                          : () {
                              widget.controller.resumePreview();
                              Navigator.of(context).pop();
                            },
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
                      icon: Icon(
                        widget.showPreviewConfirmation
                            ? Icons.arrow_forward
                            : Icons.check,
                      ),
                      label: Text(
                        widget.showPreviewConfirmation
                            ? 'Preview'
                            : 'Save Document',
                      ),
                      onPressed: _isProcessing ? null : _handleConfirm,
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
