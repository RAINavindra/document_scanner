import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../models/scanner_state.dart';

/// Controller that coordinates camera preview, frame streaming,
/// document edge detection, and perspective-corrected cropping.
class DocumentScannerController extends ChangeNotifier {
  DocumentScannerController({
    this.resolution = ResolutionPreset.high,
    this.enableAutoCapture = true,
    this.defaultFilter = ScanFilter.enhance,
    this.minDetectionInterval = const Duration(milliseconds: 100),
    this.sensitivity = DetectionSensitivity.strict,
    this.requiredSteadyFrames = 3,
  }) : _autoCaptureAnalyzer = AutoCaptureAnalyzer(
         requiredSteadyFrames: requiredSteadyFrames,
       );

  /// Target camera resolution preset.
  final ResolutionPreset resolution;

  /// Whether auto-capture is enabled by default.
  bool enableAutoCapture;

  /// Default filter applied during document cropping.
  ScanFilter defaultFilter;

  /// Minimum interval between processed frames to avoid device overheating.
  final Duration minDetectionInterval;

  /// Edge detection sensitivity.
  final DetectionSensitivity sensitivity;

  /// Number of steady frames required before auto-capture triggers.
  final int requiredSteadyFrames;

  /// Optional callback invoked when auto-capture conditions are met.
  /// Typically handled by [DocumentScannerCamera] to transition to crop or process.
  VoidCallback? onAutoCaptureTriggered;

  // Dependencies
  final DocumentDetector _detector = DocumentDetector();
  final DocumentProcessor _processor = const DocumentProcessor();
  final CornerStabilizer _stabilizer = CornerStabilizer(smoothing: 0.7);
  final AutoCaptureAnalyzer _autoCaptureAnalyzer;

  // Stream management
  StreamController<ScanInput>? _frameStreamController;
  StreamSubscription<DetectionEvent>? _detectionSubscription;

  // Internal State
  CameraController? _cameraController;
  ScannerState _state = ScannerState.initializing;
  DocumentCorners? _detectedCorners;
  AutoCaptureStatus _autoCaptureStatus = AutoCaptureStatus.searching;
  ScannedDocument? _lastScannedDocument;
  String? _lastCapturedImagePath;
  DocumentCorners? _lastCropCorners;
  String? _errorMessage;
  bool _isFlashOn = false;
  bool _hasFlash = false;
  bool _isDisposed = false;
  bool _isCapturing = false;

  // Public Getters
  CameraController? get cameraController => _cameraController;
  ScannerState get state => _state;
  DocumentCorners? get detectedCorners => _detectedCorners;
  AutoCaptureStatus get autoCaptureStatus => _autoCaptureStatus;
  ScannedDocument? get lastScannedDocument => _lastScannedDocument;
  String? get lastCapturedImagePath => _lastCapturedImagePath;
  DocumentCorners? get lastCropCorners => _lastCropCorners;
  String? get errorMessage => _errorMessage;
  bool get isFlashOn => _isFlashOn;
  bool get hasFlash => _hasFlash;

  @visibleForTesting
  set hasFlash(bool value) => _hasFlash = value;

  bool get isInitialized {
    if (_isDisposed || _cameraController == null) return false;
    try {
      return _cameraController!.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Initializes camera hardware, requests permissions, and begins frame stream.
  Future<void> initialize() async {
    if (_isDisposed) return;
    _setState(ScannerState.initializing);

    try {
      // 1. Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _setError('Camera permission is required to scan documents.');
        return;
      }

      // 2. Discover cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setError('No cameras found on this device.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // 3. Initialize CameraController
      final imageFormatGroup = Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888;

      _cameraController = CameraController(
        backCamera,
        resolution,
        enableAudio: false,
        imageFormatGroup: imageFormatGroup,
      );

      await _cameraController!.initialize();

      if (_isDisposed) {
        await _cameraController?.dispose();
        return;
      }

      // 4. Probe flash availability
      await _checkFlashAvailability();

      if (_isDisposed) {
        await _cameraController?.dispose();
        return;
      }

      // 5. Set up detection stream
      _setupDetectionPipeline();

      // 6. Start camera frame stream
      await _cameraController!.startImageStream(_handleCameraFrame);

      _setState(ScannerState.previewing);
    } catch (e) {
      _setError('Failed to initialize camera: $e');
    }
  }

  void _setupDetectionPipeline() {
    _frameStreamController = StreamController<ScanInput>();

    _detectionSubscription = _detector
        .detectStream(
          _frameStreamController!.stream,
          stabilize: _stabilizer,
          minInterval: minDetectionInterval,
          sensitivity: sensitivity,
        )
        .listen(
          _handleDetectionEvent,
          onError: (Object error) {
            debugPrint('Document detection stream error: $error');
          },
        );
  }

  void _handleCameraFrame(CameraImage image) {
    if (_isDisposed ||
        _state != ScannerState.previewing ||
        _isCapturing ||
        _frameStreamController == null ||
        _frameStreamController!.isClosed) {
      return;
    }

    try {
      final rotation = _cameraController?.description.sensorOrientation ?? 0;
      final ScanInput input;

      if (image.planes.length >= 3) {
        // Android YUV 4:2:0 format
        input = ScanInput.yuvFrame(
          width: image.width,
          height: image.height,
          rotation: rotation,
          yBytes: image.planes[0].bytes,
          uBytes: image.planes[1].bytes,
          vBytes: image.planes[2].bytes,
          yRowStride: image.planes[0].bytesPerRow,
          uvRowStride: image.planes[1].bytesPerRow,
          uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
        );
      } else {
        // iOS single interleaved BGRA plane or other format
        input = ScanInput.bgraFrame(
          width: image.width,
          height: image.height,
          rotation: rotation,
          bytes: image.planes[0].bytes,
          bytesPerRow: image.planes[0].bytesPerRow,
        );
      }

      _frameStreamController!.add(input);
    } catch (e) {
      debugPrint('Error converting camera frame to ScanInput: $e');
    }
  }

  void _handleDetectionEvent(DetectionEvent event) {
    if (_isDisposed || _state != ScannerState.previewing || _isCapturing) return;

    final autoCaptureState = _autoCaptureAnalyzer.addEvent(event);
    _autoCaptureStatus = autoCaptureState.status;

    if (event is DetectionSuccess) {
      _detectedCorners = event.corners;
    } else if (event is DetectionEmpty || event is DetectionError) {
      _detectedCorners = null;
    }

    notifyListeners();

    // Check if auto-capture criteria are met
    if (enableAutoCapture &&
        autoCaptureState.shouldCapture &&
        !_isCapturing &&
        _state == ScannerState.previewing &&
        _detectedCorners != null) {
      if (onAutoCaptureTriggered != null) {
        onAutoCaptureTriggered!();
      } else {
        captureAndProcess();
      }
    }
  }

  /// Manually captures a high-resolution photo and crops the document.
  ///
  /// If [manualCorners] is omitted, the currently detected corners are used.
  Future<ScannedDocument?> captureAndProcess({
    DocumentCorners? manualCorners,
    ScanFilter? filter,
  }) async {
    final streamCorners = _detectedCorners;

    final imagePath = await takePhoto();
    if (imagePath == null) return null;

    _setState(ScannerState.processing);

    try {
      DocumentCorners? cornersToCrop = manualCorners;
      if (cornersToCrop == null) {
        final fileCorners = await _detector.detect(
          ScanInput.file(imagePath),
          sensitivity: DetectionSensitivity.lenient,
        );
        cornersToCrop = fileCorners ?? streamCorners;
      }

      final effectiveCorners = cornersToCrop ??
          const DocumentCorners(
            topLeft: (x: 0.0, y: 0.0),
            topRight: (x: 1.0, y: 0.0),
            bottomRight: (x: 1.0, y: 1.0),
            bottomLeft: (x: 0.0, y: 1.0),
          );
      _lastCropCorners = effectiveCorners;

      // Perform perspective correction & filtering on a background isolate
      final scannedDoc = await _processor.crop(
        ScanInput.file(imagePath),
        effectiveCorners,
        filter: filter ?? defaultFilter,
        background: true,
      );

      _lastScannedDocument = scannedDoc;
      _setState(ScannerState.done);
      return scannedDoc;
    } catch (e) {
      _setError('Failed to process document: $e');
      return null;
    }
  }

  /// Takes a still photo without immediately cropping it. Useful when
  /// navigating to a manual corner adjustment screen.
  Future<String?> takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }
    if (_isCapturing) return null;
    _isCapturing = true;

    try {
      _setState(ScannerState.capturing);

      if (_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (e) {
          debugPrint('Notice stopping image stream: $e');
        }
        // Give CameraX pipeline breathing room to flush active ImageProxy
        await Future.delayed(const Duration(milliseconds: 150));
      }

      final xFile = await _cameraController!.takePicture();
      _lastCapturedImagePath = xFile.path;
      return xFile.path;
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _setError('Failed to take photo: $e');
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  /// Crops an image file from disk with specific corners.
  Future<ScannedDocument?> cropFile(
    String filePath,
    DocumentCorners corners, {
    ScanFilter? filter,
  }) async {
    _setState(ScannerState.processing);
    try {
      final doc = await _processor.crop(
        ScanInput.file(filePath),
        corners,
        filter: filter ?? defaultFilter,
        background: true,
      );
      _lastScannedDocument = doc;
      _setState(ScannerState.done);
      return doc;
    } catch (e) {
      _setError('Failed to crop document: $e');
      return null;
    }
  }

  /// Rotates a [ScannedDocument] image by [degrees] (default 90° clockwise) on a background isolate.
  Future<ScannedDocument?> rotateDocument(
    ScannedDocument doc, {
    int degrees = 90,
  }) async {
    try {
      final docBytes = doc.bytes;
      final rotated = await Isolate.run(() {
        final decoded = img.decodeImage(docBytes);
        if (decoded == null) return null;
        final rot = img.copyRotate(decoded, angle: degrees);
        final encoded = img.encodeJpg(rot, quality: 90);
        return ScannedDocument(
          bytes: Uint8List.fromList(encoded),
          width: rot.width,
          height: rot.height,
        );
      });
      if (rotated != null) {
        _lastScannedDocument = rotated;
      }
      return rotated;
    } catch (e) {
      debugPrint('Error rotating document: $e');
      return null;
    }
  }

  /// Applies a [ScanFilter] to an already-cropped [ScannedDocument] on a background isolate.
  Future<ScannedDocument?> applyFilterToDocument(
    ScannedDocument doc,
    ScanFilter filter,
  ) async {
    try {
      final filtered = await _processor.applyFilter(
        ScanInput.bytes(
          doc.bytes,
          width: doc.width,
          height: doc.height,
        ),
        filter,
        background: true,
      );
      if (filtered != null) {
        _lastScannedDocument = filtered;
      }
      return filtered;
    } catch (e) {
      debugPrint('Error applying filter to document: $e');
      return null;
    }
  }

  /// Resumes the live camera preview and detection stream after capture or error.
  Future<void> resumePreview() async {
    if (_isDisposed ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _autoCaptureAnalyzer.reset();
      _detectedCorners = null;
      _autoCaptureStatus = AutoCaptureStatus.searching;
      _errorMessage = null;
      _isCapturing = false;

      _setState(ScannerState.previewing);

      // Brief pause to ensure CameraX image capture session has settled
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_handleCameraFrame);
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to resume preview: $e');
    }
  }

  /// Probes whether this device and camera sensor have a physical flashlight / torch unit.
  Future<void> _checkFlashAvailability() async {
    if (_isDisposed || _cameraController == null) {
      _hasFlash = false;
      return;
    }

    try {
      if (_cameraController!.description.lensDirection != CameraLensDirection.back) {
        _hasFlash = false;
        return;
      }

      await _cameraController!.setFlashMode(FlashMode.torch);
      final error = _cameraController!.value.errorDescription;
      if (error != null && error.isNotEmpty) {
        _hasFlash = false;
      } else {
        _hasFlash = true;
        await _cameraController!.setFlashMode(FlashMode.off);
      }
    } catch (_) {
      _hasFlash = false;
    }
  }

  /// Toggles camera flash (torch mode).
  ///
  /// Returns `true` if torch mode was successfully toggled, or `false`
  /// if flashlight is not supported or unavailable on this device.
  Future<bool> toggleFlash() async {
    if (_isDisposed || _cameraController == null || !isInitialized) {
      return false;
    }

    final targetMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
    try {
      await _cameraController!.setFlashMode(targetMode);

      final error = _cameraController!.value.errorDescription;
      if (targetMode == FlashMode.torch && error != null && error.isNotEmpty) {
        debugPrint('Camera flash/torch reported driver error: $error');
        _isFlashOn = false;
        _hasFlash = false;
        notifyListeners();
        return false;
      }

      _isFlashOn = targetMode == FlashMode.torch;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to set flash mode to $targetMode: $e');
      _isFlashOn = false;
      _hasFlash = false;
      notifyListeners();
      return false;
    }
  }

  /// Sets the camera focus and exposure metering point on the sensor.
  ///
  /// [point] coordinates are normalized: (0.0, 0.0) is top-left, (1.0, 1.0) is bottom-right.
  /// Passing `null` resets the sensor back to continuous auto-focus and auto-exposure.
  Future<void> setFocusPoint(Offset? point, {bool setExposure = true}) async {
    if (_isDisposed || _cameraController == null || !isInitialized) {
      return;
    }

    try {
      if (point != null) {
        final clampedPoint = Offset(
          point.dx.clamp(0.0, 1.0),
          point.dy.clamp(0.0, 1.0),
        );
        await _cameraController!.setFocusPoint(clampedPoint);
        if (setExposure) {
          await _cameraController!.setExposurePoint(clampedPoint);
        }
      } else {
        await _cameraController!.setFocusPoint(null);
        if (setExposure) {
          await _cameraController!.setExposurePoint(null);
        }
      }
    } catch (e) {
      debugPrint('Focus/Exposure point adjustment failed or not supported: $e');
    }
  }

  /// Toggles auto-capture on or off.
  void toggleAutoCapture() {
    enableAutoCapture = !enableAutoCapture;
    if (!enableAutoCapture) {
      _autoCaptureAnalyzer.reset();
    }
    notifyListeners();
  }

  void _setState(ScannerState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    if (_isDisposed) return;
    _errorMessage = message;
    _state = ScannerState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _detectionSubscription?.cancel();
    _frameStreamController?.close();
    final cam = _cameraController;
    _cameraController = null;
    cam?.dispose();
    super.dispose();
  }
}

