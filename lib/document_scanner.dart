library;

// Re-exports from document_scan for convenient one-stop importing
export 'package:document_scan/document_scan.dart'
    show
        DocumentCorners,
        ScanPoint,
        ScanFilter,
        ScannedDocument,
        ScanInput,
        AutoCaptureStatus,
        AutoCaptureState,
        DetectionSensitivity,
        DocumentDetector,
        DocumentProcessor;

// One-line API
export 'src/document_scanner.dart';
export 'src/utils/file_saver.dart';

// Controller & States
export 'src/controller/document_scanner_controller.dart';
export 'src/models/overlay_style.dart';
export 'src/models/scanner_state.dart';

// UI Widgets
export 'src/widgets/crop_adjustment_screen.dart';
export 'src/widgets/document_preview_screen.dart';
export 'src/widgets/document_scanner_camera.dart';
export 'src/widgets/document_scanner_screen.dart';
export 'src/widgets/quad_overlay_painter.dart';
