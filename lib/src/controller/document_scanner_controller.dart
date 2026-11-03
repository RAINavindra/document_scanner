import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/foundation.dart';
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
  String? _errorMessage;
  bool _isFlashOn = false;
  bool _isDisposed = false;
  bool _isCapturing = false;

  // Public Getters
  CameraController? get cameraController => _cameraController;
  ScannerState get state => _state;
  DocumentCorners? get detectedCorners => _detectedCorners;
  AutoCaptureStatus get autoCaptureStatus => _autoCaptureStatus;
  ScannedDocument? get lastScannedDocument => _lastScannedDocument;
  String? get lastCapturedImagePath => _lastCapturedImagePath;
  String? get errorMessage => _errorMessage;
  bool get isFlashOn => _isFlashOn;
  bool get isInitialized =>
      _cameraController != null && _cameraController!.value.isInitialized;

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

      // 4. Set up detection stream
      _setupDetectionPipeline();

      // 5. Start camera frame stream
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

      // Perform perspective correction & filtering on a background isolate
      final scannedDoc = await _processor.crop(
        ScanInput.file(imagePath),
        cornersToCrop ??
            const DocumentCorners(
              topLeft: (x: 0.0, y: 0.0),
              topRight: (x: 1.0, y: 0.0),
              bottomRight: (x: 1.0, y: 1.0),
              bottomLeft: (x: 0.0, y: 1.0),
            ),
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

  /// Toggles camera flash (torch mode).
  Future<void> toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final nextMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(nextMode);
      _isFlashOn = !_isFlashOn;
      notifyListeners();
    } catch (e) {
      debugPrint('Flash toggle error: $e');
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
    _cameraController?.dispose();
    super.dispose();
  }
}

