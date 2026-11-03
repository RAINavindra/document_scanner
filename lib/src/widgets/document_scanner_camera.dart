import 'package:camera/camera.dart';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controller/document_scanner_controller.dart';
import '../models/overlay_style.dart';
import '../models/scanner_state.dart';
import 'crop_adjustment_screen.dart';
import 'quad_overlay_painter.dart';

/// Full-featured camera preview widget with real-time document edge detection,
/// status badges, flash/auto-capture controls, and capture actions.
class DocumentScannerCamera extends StatefulWidget {
  const DocumentScannerCamera({
    super.key,
    required this.controller,
    this.overlayStyle = const OverlayStyle(),
    this.openCropScreenOnCapture = true,
    this.onScanned,
    this.onError,
    this.appBarTitle = 'Scan Document',
    this.showTopControls = true,
    this.initialFilter = ScanFilter.enhance,
    this.imageFilters = const [
      ScanFilter.none,
      ScanFilter.enhance,
      ScanFilter.magicColor,
      ScanFilter.blackWhite,
      ScanFilter.grayscale,
      ScanFilter.sharpen,
    ],
    this.edgeColor,
    this.steadyEdgeColor,
    this.fillColor,
    this.isGalleryImportAllowed = false,
    this.bottomTrailingWidget,
    this.onClose,
  });

  /// The active scanner controller.
  final DocumentScannerController controller;

  /// Customization style for the polygon overlay.
  final OverlayStyle overlayStyle;

  /// Whether to automatically transition to [CropAdjustmentScreen] upon capture.
  final bool openCropScreenOnCapture;

  /// Callback fired when a document has been successfully captured and cropped.
  final ValueChanged<ScannedDocument>? onScanned;

  /// Callback fired when an error occurs.
  final ValueChanged<String>? onError;

  /// Title displayed in the top bar.
  final String appBarTitle;

  /// Whether to show the top controls bar (flash, auto-capture, close).
  final bool showTopControls;

  /// List of filters to apply to the captured image.
  final List<ScanFilter> imageFilters;

  /// Filter selected by default.
  final ScanFilter initialFilter;

  /// Optional shortcut to override the detected edge and line color.
  /// When provided, this overrides [overlayStyle.borderColor] and harmonizes
  /// default fill and grid line colors.
  final Color? edgeColor;

  /// Optional shortcut to override the edge color when document is held steady.
  /// When provided, this overrides [overlayStyle.steadyBorderColor].
  final Color? steadyEdgeColor;

  /// Optional shortcut to override the quad fill color.
  /// When provided, this overrides [overlayStyle.fillColor].
  final Color? fillColor;

  /// Whether to allow the user to import and scan existing images from the device gallery.
  final bool isGalleryImportAllowed;

  /// Optional widget displayed on the bottom right (e.g. Done button in multi-page flow).
  final Widget? bottomTrailingWidget;

  /// Callback when the close/back button is tapped.
  /// If null, defaults to `Navigator.of(context).maybePop()`.
  final VoidCallback? onClose;

  @override
  State<DocumentScannerCamera> createState() => _DocumentScannerCameraState();
}

class _DocumentScannerCameraState extends State<DocumentScannerCamera>
    with WidgetsBindingObserver {
  bool _isCapturingLocally = false;

  OverlayStyle get _effectiveOverlayStyle {
    var style = widget.overlayStyle;
    if (widget.edgeColor != null) {
      style = style.copyWith(
        borderColor: widget.edgeColor,
        fillColor: widget.fillColor ?? widget.edgeColor!.withValues(alpha: 0.2),
        gridColor: widget.edgeColor!.withValues(alpha: 0.15),
      );
    }
    if (widget.steadyEdgeColor != null) {
      style = style.copyWith(steadyBorderColor: widget.steadyEdgeColor);
    }
    if (widget.fillColor != null) {
      style = style.copyWith(fillColor: widget.fillColor);
    }
    return style;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerUpdate);
    widget.controller.onAutoCaptureTriggered = _onAutoCaptureTriggered;

    if (!widget.controller.isInitialized) {
      widget.controller.initialize();
    }
  }

  void _onAutoCaptureTriggered() {
    if (!mounted || widget.controller.state != ScannerState.previewing) return;
    _handleCapture();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerUpdate);
    widget.controller.onAutoCaptureTriggered = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Re-bind camera stream when resuming app
    if (lifecycleState == AppLifecycleState.resumed &&
        widget.controller.isInitialized &&
        widget.controller.state == ScannerState.previewing) {
      widget.controller.resumePreview();
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    if (widget.controller.state == ScannerState.error &&
        widget.controller.errorMessage != null) {
      widget.onError?.call(widget.controller.errorMessage!);
    }

    setState(() {});
  }

  Future<void> _handleCapture() async {
    if (_isCapturingLocally ||
        widget.controller.state != ScannerState.previewing) {
      return;
    }
    _isCapturingLocally = true;

    try {
      if (widget.openCropScreenOnCapture) {
        // Save stream corners as a fallback before stopping stream and taking photo
        final streamCorners = widget.controller.detectedCorners;

        // 1. Take still photo without immediate crop
        final imagePath = await widget.controller.takePhoto();
        if (!mounted || imagePath == null) return;

        // Re-detect on the actual still image for accurate corners on full-res image
        final detector = DocumentDetector();
        final fileCorners = await detector.detect(
          ScanInput.file(imagePath),
          sensitivity: DetectionSensitivity.lenient,
        );

        // 2. Open manual corner adjustment screen
        final corners =
            fileCorners ??
            streamCorners ??
            const DocumentCorners(
              topLeft: (x: 0.08, y: 0.08),
              topRight: (x: 0.92, y: 0.08),
              bottomRight: (x: 0.92, y: 0.92),
              bottomLeft: (x: 0.08, y: 0.92),
            );

        if (!mounted) return;

        final result = await Navigator.of(context).push<ScannedDocument>(
          MaterialPageRoute(
            builder: (_) => CropAdjustmentScreen(
              imagePath: imagePath,
              initialCorners: corners,
              controller: widget.controller,
              overlayStyle: _effectiveOverlayStyle,
              onCropped: (doc) {
                Navigator.of(context).pop(doc);
              },
              imageFilters: widget.imageFilters,
              initialFilter: widget.initialFilter,
            ),
          ),
        );

        if (result != null && mounted) {
          widget.onScanned?.call(result);
        } else if (mounted) {
          // If user backed out, resume camera preview
          await widget.controller.resumePreview();
        }
      } else {
        // Crop directly with detected corners
        final doc = await widget.controller.captureAndProcess();
        if (doc != null && mounted) {
          widget.onScanned?.call(doc);
        }
      }
    } finally {
      _isCapturingLocally = false;
    }
  }

  Future<void> _handleGalleryImport() async {
    if (_isCapturingLocally) return;
    _isCapturingLocally = true;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted || pickedFile == null) return;

      // 1. Detect corners on the picked still image
      final detector = DocumentDetector();
      final fileCorners = await detector.detect(
        ScanInput.file(pickedFile.path),
        sensitivity: DetectionSensitivity.lenient,
      );

      final corners = fileCorners ??
          const DocumentCorners(
            topLeft: (x: 0.08, y: 0.08),
            topRight: (x: 0.92, y: 0.08),
            bottomRight: (x: 0.92, y: 0.92),
            bottomLeft: (x: 0.08, y: 0.92),
          );

      if (!mounted) return;

      // 2. Open manual corner adjustment screen
      final result = await Navigator.of(context).push<ScannedDocument>(
        MaterialPageRoute(
          builder: (_) => CropAdjustmentScreen(
            imagePath: pickedFile.path,
            initialCorners: corners,
            controller: widget.controller,
            overlayStyle: _effectiveOverlayStyle,
            onCropped: (doc) {
              Navigator.of(context).pop(doc);
            },
            imageFilters: widget.imageFilters,
            initialFilter: widget.initialFilter,
          ),
        ),
      );

      if (result != null && mounted) {
        widget.onScanned?.call(result);
      } else if (mounted) {
        await widget.controller.resumePreview();
      }
    } catch (e) {
      debugPrint('Error importing image from gallery: $e');
      widget.onError?.call('Failed to import image from gallery: $e');
    } finally {
      _isCapturingLocally = false;
    }
  }

  Widget _buildStatusBadge() {
    final status = widget.controller.autoCaptureStatus;
    final hasCorners = widget.controller.detectedCorners != null;

    final String label;
    final Color bgColor;
    final IconData icon;

    if (widget.controller.state == ScannerState.capturing) {
      label = 'Capturing photo...';
      bgColor = Colors.blueAccent;
      icon = Icons.camera;
    } else if (widget.controller.state == ScannerState.processing) {
      label = 'Processing document...';
      bgColor = Colors.deepPurpleAccent;
      icon = Icons.auto_fix_high;
    } else if (status == AutoCaptureStatus.ready &&
        widget.controller.enableAutoCapture) {
      label = 'Holding steady! Capturing...';
      bgColor = _effectiveOverlayStyle.steadyBorderColor;
      icon = Icons.check_circle;
    } else if (hasCorners) {
      label = widget.controller.enableAutoCapture
          ? 'Hold steady for auto-capture'
          : 'Document detected';
      bgColor = _effectiveOverlayStyle.borderColor;
      icon = Icons.document_scanner;
    } else {
      label = 'Align document in view';
      bgColor = Colors.black54;
      icon = Icons.crop_free;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.controller.cameraController;

    if (widget.controller.state == ScannerState.error) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.controller.errorMessage ?? 'An error occurred',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => widget.controller.initialize(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (camera == null || !camera.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Starting camera...',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final isSteady =
        widget.controller.autoCaptureStatus == AutoCaptureStatus.ready;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera live preview with real-time edge detection quad overlay
          Center(
            child: CameraPreview(
              camera,
              child: widget.controller.detectedCorners != null
                  ? CustomPaint(
                      painter: QuadOverlayPainter(
                        corners: widget.controller.detectedCorners!,
                        style: _effectiveOverlayStyle,
                        isSteady: isSteady,
                      ),
                    )
                  : null,
            ),
          ),

          // 3. Top controls bar
          if (widget.showTopControls)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onClose ??
                          () => Navigator.of(context).maybePop(),
                    ),
                  ),

                  // Center title
                  Text(
                    widget.appBarTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),

                  // Right actions (Flash & Auto-capture)
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(
                            widget.controller.isFlashOn
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: widget.controller.isFlashOn
                                ? Colors.amber
                                : Colors.white,
                          ),
                          onPressed: widget.controller.toggleFlash,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(
                            widget.controller.enableAutoCapture
                                ? Icons.auto_awesome
                                : Icons.touch_app,
                            color: widget.controller.enableAutoCapture
                                ? Colors.cyanAccent
                                : Colors.white54,
                          ),
                          tooltip: widget.controller.enableAutoCapture
                              ? 'Auto-capture enabled'
                              : 'Manual capture mode',
                          onPressed: widget.controller.toggleAutoCapture,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 4. Center-top status badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 0,
            right: 0,
            child: Center(child: _buildStatusBadge()),
          ),

          // 5. Bottom controls (Gallery + Shutter + Trailing widget)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 20,
            right: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center shutter capture button
                GestureDetector(
                  onTap:
                      (widget.controller.state == ScannerState.previewing &&
                          !_isCapturingLocally)
                      ? _handleCapture
                      : null,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSteady
                            ? _effectiveOverlayStyle.steadyBorderColor
                            : Colors.white,
                        width: 4.0,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSteady
                              ? _effectiveOverlayStyle.steadyBorderColor
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black87,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

                // Left: Gallery import button
                if (widget.isGalleryImportAllowed)
                  Positioned(
                    left: 4,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Import from Gallery',
                        onPressed: (!_isCapturingLocally &&
                                widget.controller.state ==
                                    ScannerState.previewing)
                            ? _handleGalleryImport
                            : null,
                      ),
                    ),
                  ),

                // Right: Optional trailing widget (e.g. Done button in multi-page flow)
                if (widget.bottomTrailingWidget != null)
                  Positioned(
                    right: 4,
                    child: widget.bottomTrailingWidget!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
