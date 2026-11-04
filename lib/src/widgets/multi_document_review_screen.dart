import 'dart:io';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

import '../controller/document_scanner_controller.dart';
import '../models/crop_adjustment_result.dart';
import '../models/overlay_style.dart';
import '../models/scanned_document_page.dart';
import '../utils/file_saver.dart';
import 'crop_adjustment_screen.dart';

/// Screen allowing users to inspect and review all scanned pages before final confirmation.
///
/// Features:
/// - Swipeable [PageView] with pinch-to-zoom interactive document inspection.
/// - Thumbnail strip for quick jump between pages.
/// - Re-crop action to re-adjust document corners from the original raw photo.
/// - 90° clockwise rotation.
/// - Non-destructive filter switcher with optional "Apply to all pages".
/// - Delete individual page with auto-return if empty.
/// - "+ Add Page" action to return to camera and capture additional pages.
/// - Final confirmation saving all documents to disk and returning local file paths.
class MultiDocumentReviewScreen extends StatefulWidget {
  const MultiDocumentReviewScreen({
    super.key,
    required this.pages,
    required this.controller,
    this.imageFilters = const [
      ScanFilter.none,
      ScanFilter.enhance,
      ScanFilter.magicColor,
      ScanFilter.blackWhite,
      ScanFilter.grayscale,
      ScanFilter.sharpen,
    ],
    this.overlayStyle = const OverlayStyle(),
    this.appBarTitle = 'Review Documents',
    this.noOfPages,
    this.outputDirectory,
  });

  /// The list of pages scanned during this session.
  final List<ScannedDocumentPage> pages;

  /// Scanner controller used to execute crop, rotate, and filter operations.
  final DocumentScannerController controller;

  /// Available filters to switch between.
  final List<ScanFilter> imageFilters;

  /// Style applied when re-opening [CropAdjustmentScreen].
  final OverlayStyle overlayStyle;

  /// Title displayed in the app bar.
  final String appBarTitle;

  /// Maximum number of pages allowed in this session.
  final int? noOfPages;

  /// Optional custom directory where saved document files will be written.
  /// If null, defaults to the temporary directory.
  final Directory? outputDirectory;

  @override
  State<MultiDocumentReviewScreen> createState() =>
      _MultiDocumentReviewScreenState();
}

class _MultiDocumentReviewScreenState extends State<MultiDocumentReviewScreen> {
  late final List<ScannedDocumentPage> _pages;
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pages = List<ScannedDocumentPage>.from(widget.pages);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ScannedDocumentPage get _currentPage => _pages[_currentIndex];

  Future<void> _handleReCrop() async {
    if (_isProcessing || _pages.isEmpty) return;

    final page = _currentPage;
    final result = await Navigator.of(context).push<CropAdjustmentResult>(
      MaterialPageRoute(
        builder: (_) => CropAdjustmentScreen(
          imagePath: page.originalImagePath,
          initialCorners: page.corners,
          controller: widget.controller,
          initialFilter: page.filter,
          imageFilters: widget.imageFilters,
          overlayStyle: widget.overlayStyle,
          showPreviewConfirmation: false,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      ScannedDocument updatedDoc = result.document;
      ScannedDocument updatedBase = result.baseDocument;

      // Re-apply any existing rotation to the newly cropped document
      if (page.rotationDegrees != 0) {
        final rotDoc = await widget.controller.rotateDocument(
          updatedDoc,
          degrees: page.rotationDegrees,
        );
        final rotBase = await widget.controller.rotateDocument(
          updatedBase,
          degrees: page.rotationDegrees,
        );
        if (rotDoc != null && rotBase != null) {
          updatedDoc = rotDoc;
          updatedBase = rotBase;
        }
      }

      setState(() {
        _pages[_currentIndex] = page.copyWith(
          corners: result.corners,
          document: updatedDoc,
          baseDocument: updatedBase,
          filter: result.filter,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update crop: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRotate() async {
    if (_isProcessing || _pages.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final page = _currentPage;
      final rotDoc = await widget.controller.rotateDocument(
        page.document,
        degrees: 90,
      );
      final rotBase = await widget.controller.rotateDocument(
        page.baseDocument,
        degrees: 90,
      );

      if (mounted && rotDoc != null && rotBase != null) {
        setState(() {
          _pages[_currentIndex] = page.copyWith(
            document: rotDoc,
            baseDocument: rotBase,
            rotationDegrees: (page.rotationDegrees + 90) % 360,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rotate: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showFilterSelector() async {
    if (_isProcessing || _pages.isEmpty) return;

    final currentFilter = _currentPage.filter;
    var applyToAll = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Choose Filter',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: applyToAll,
                              activeColor: Theme.of(context).colorScheme.primary,
                              onChanged: (val) {
                                setModalState(() => applyToAll = val ?? false);
                              },
                            ),
                            const Text(
                              'Apply to all',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.imageFilters.map((f) {
                        final isSelected = f == currentFilter;
                        return ChoiceChip(
                          label: Text(_filterName(f)),
                          selected: isSelected,
                          onSelected: (_) async {
                            Navigator.of(ctx).pop();
                            await _applyFilter(f, applyToAll: applyToAll);
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: Colors.black45,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _applyFilter(ScanFilter filter, {bool applyToAll = false}) async {
    setState(() => _isProcessing = true);
    try {
      if (applyToAll) {
        for (var i = 0; i < _pages.length; i++) {
          final p = _pages[i];
          final filtered = filter == ScanFilter.none
              ? p.baseDocument
              : await widget.controller.applyFilterToDocument(p.baseDocument, filter);
          if (filtered != null) {
            _pages[i] = p.copyWith(document: filtered, filter: filter);
          }
        }
      } else {
        final p = _currentPage;
        final filtered = filter == ScanFilter.none
            ? p.baseDocument
            : await widget.controller.applyFilterToDocument(p.baseDocument, filter);
        if (filtered != null) {
          _pages[_currentIndex] = p.copyWith(document: filtered, filter: filter);
        }
      }
      setState(() {});
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

  Future<void> _handleDelete() async {
    if (_pages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Page?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete Page ${_currentIndex + 1}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _pages.removeAt(_currentIndex);
        if (_currentIndex >= _pages.length && _pages.isNotEmpty) {
          _currentIndex = _pages.length - 1;
        }
      });

      if (_pages.isEmpty) {
        // All pages deleted -> return to camera scanner
        Navigator.of(context).pop(_pages);
      } else {
        _pageController.jumpToPage(_currentIndex);
      }
    }
  }

  Future<void> _handleConfirmAll() async {
    if (_isSaving || _pages.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final savedPaths = <String>[];
      for (var i = 0; i < _pages.length; i++) {
        final path = await DocumentFileSaver.saveScannedDocument(
          _pages[i].document,
          index: i,
          directory: widget.outputDirectory,
        );
        savedPaths.add(path);
      }

      if (mounted) {
        Navigator.of(context).pop(savedPaths);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save documents: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _filterName(ScanFilter filter) {
    switch (filter) {
      case ScanFilter.none:
        return 'Original';
      case ScanFilter.enhance:
        return 'Enhance';
      case ScanFilter.magicColor:
        return 'Magic';
      case ScanFilter.blackWhite:
        return 'B&W';
      case ScanFilter.grayscale:
        return 'Gray';
      case ScanFilter.sharpen:
        return 'Sharpen';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_pages);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back to camera',
            onPressed: () => Navigator.of(context).pop(_pages),
          ),
        title: Text(
          '${widget.appBarTitle} (${_currentIndex + 1}/${_pages.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: _handleConfirmAll,
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Confirm (${_pages.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              // 1. Full-size PageView with Pinch-to-Zoom inspection
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              page.document.bytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 2. Action Toolbar for the current page
              Container(
                color: Colors.grey[900]!.withValues(alpha: 0.95),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      icon: Icons.crop,
                      label: 'Re-crop',
                      onTap: _handleReCrop,
                    ),
                    _buildActionButton(
                      icon: Icons.rotate_right,
                      label: 'Rotate',
                      onTap: _handleRotate,
                    ),
                    _buildActionButton(
                      icon: Icons.auto_fix_high,
                      label: 'Filter',
                      onTap: _showFilterSelector,
                    ),
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: Colors.redAccent,
                      onTap: _handleDelete,
                    ),
                  ],
                ),
              ),

              // 3. Bottom Thumbnail Carousel Strip with "+ Add" button
              Container(
                height: 84,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    // Rightmost item: "+ Add Page" button (hidden when noOfPages limit is reached)
                    if (index == _pages.length) {
                      final isLimitReached = widget.noOfPages != null &&
                          _pages.length >= widget.noOfPages!;
                      if (isLimitReached) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () => Navigator.of(context).pop(_pages),
                        child: Container(
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: Colors.white70, size: 20),
                              SizedBox(height: 2),
                              Text(
                                'Add',
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final page = _pages[index];
                    final isSelected = index == _currentIndex;

                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white24,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.memory(
                                page.document.bytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Loading overlay during isolates / file operations
          if (_isProcessing || _isSaving)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _isSaving ? 'Saving documents...' : 'Processing...',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
