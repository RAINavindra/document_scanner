# Document Scanner (`document_scanner`)

A turnkey, high-performance Flutter document scanner package. Combines the official Flutter `camera` stream with [`document_scan`](https://pub.dev/packages/document_scan) for real-time edge detection, auto-capture, tap-to-focus, manual corner adjustment, perspective correction, image filtering, and multi-page batch review.

**Zero custom native code required** — 100% pure Dart orchestration on top of established, production-grade Flutter plugins.

---

## Features

- 📸 **Live Camera Stream Edge Detection:** Real-time quad tracking directly over camera preview via high-speed YUV420/BGRA frame streaming.
- ⚡ **Steadiness Auto-Capture:** Analyzes consecutive frame steadiness and confidence to automatically snap the photo when held still.
- 🎯 **Interactive Tap-to-Focus:** Tap anywhere on the camera preview to focus the camera lens and meter exposure with an animated golden reticle.
- 🔦 **Hardware Flashlight Auto-Detection:** Automatically probes sensor hardware to detect whether the device has a physical flash unit (e.g. phones vs tablets/emulators), hiding the button when unsupported or allowing explicit manual overrides.
- ✂️ **Manual Corner Adjustment:** Post-capture adjustment screen with 4 draggable corner handles and real-time magnifier loupe for pixel-perfect edge correction.
- 📑 **Multi-Page Batch Review & Re-Crop:** Swipe through all scanned pages before final confirmation. Inspect fine text with pinch-to-zoom `InteractiveViewer`, re-crop any individual page from its original uncropped source photo, rotate 90°, switch filters with "Apply to all", delete pages, or tap "+ Add" to scan more pages.
- 🛑 **Page Limit Enforcement (`noOfPages`):** Set a maximum page count (e.g. `noOfPages: 3`). Once reached, the shutter button, auto-capture, and gallery import are automatically locked, and the "+ Add" button is hidden in review. Deleting a page instantly unlocks capture again.
- 🖼️ **Single-Page Instant Finish:** Set `noOfPages: 1` to immediately process, crop, and return a single document without the multi-page review screen.
- 🪄 **Background Isolate Processing:** Perspective warp, rotation, and scan filters (`enhance`, `magicColor`, `blackWhite`, `grayscale`, `none`) execute entirely off the UI thread via background isolates.
- 🎨 **Customizable Overlays:** Configure quad fill colors, border strokes, corner pins, and guide grids via `OverlayStyle` or harmonize with a single brand color using `OverlayStyle.fromColor(color)`.
- 📁 **Custom Output Directory:** Write scanned documents directly to custom directories or the application cache.

---

## Installation

Add `document_scanner` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  document_scanner: ^0.0.1
```

---

## Platform Setup

### Android Setup

1. Add camera and storage permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />

    <application ...>
        ...
    </application>
</manifest>
```

2. In `android/app/build.gradle.kts`, ensure your `minSdk` is at least 24 and `compileSdk` is at least 35:

```kotlin
android {
    compileSdk = 36 // or 35+
    defaultConfig {
        minSdk = 24
    }
}
```

> **Note on Android 37:** `permission_handler` 13+ introduced a requirement for `compileSdk = 37`. This package pins `permission_handler: ^12.0.3` to maintain standard compatibility with `compileSdk 35/36` and AGP 8/9.

---

### iOS Setup

Add camera and photo library usage descriptions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to scan documents.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires photo library access to import documents.</string>
```

---

## Quickstart

### 1. One-Line Turnkey API (Recommended)

Call `DocumentScanner.getPictures(...)` directly without manually configuring controllers, routes, or widgets. It launches a full scanning flow with camera preview, auto-capture, tap-to-focus, gallery import, manual corner adjustment, and multi-page review, returning a list of local file paths:

```dart
import 'package:document_scanner/document_scanner.dart';

// In any async method:
final List<String>? pictures = await DocumentScanner.getPictures(
  context: context, // optional if DocumentScanner.navigatorKey is set
  isGalleryImportAllowed: true,
  // noOfPages defaults to 1 (single-page scan). Pass e.g. 3 for batch scanning.
  edgeColor: Colors.blueAccent,
);

if (pictures != null && pictures.isNotEmpty) {
  for (final path in pictures) {
    print('Scanned document saved at: $path');
  }
}
```

#### Global `navigatorKey` (No `BuildContext` Needed)

Assign `DocumentScanner.navigatorKey` to your `MaterialApp` to call `DocumentScanner.getPictures()` from anywhere in your business logic without passing `BuildContext`:

```dart
MaterialApp(
  navigatorKey: DocumentScanner.navigatorKey,
  home: const MyHomePage(),
);

// Then anywhere in your app:
final pictures = await DocumentScanner.getPictures(isGalleryImportAllowed: true);
```

---

## Usage Recipes

### Recipe 1: Single-Page Instant Scan

Setting `noOfPages: 1` creates a streamlined single-page workflow that finishes immediately after the user captures and crops the first page:

```dart
final List<String>? result = await DocumentScanner.getPictures(
  context: context,
  noOfPages: 1, // Single-page mode
  initialFilter: ScanFilter.enhance,
);

if (result != null && result.isNotEmpty) {
  final singleDocPath = result.first;
  print('Single page: $singleDocPath');
}
```

---

### Recipe 2: Multi-Page Batch Scan with In-App Re-Crop Review

Setting `noOfPages > 1` (or leaving it `null` for unlimited pages) enables multi-page batch scanning:
- The camera displays the current progress in the title bar (e.g. `"Scan Document (2/3)"`).
- A floating **Review (N)** button displays the latest page thumbnail.
- Once the page limit is reached, the scanner locks the shutter, prevents auto-capture, and automatically opens the **Review Screen**.
- Users can swipe between pages, pinch-to-zoom to check legibility, rotate 90°, delete pages, or tap **Re-crop** to readjust edges using the original uncropped photo.

```dart
final List<String>? pages = await DocumentScanner.getPictures(
  context: context,
  noOfPages: 5,
  appBarTitle: 'Scan Contract',
  isGalleryImportAllowed: true,
);
```

---

### Recipe 3: Automatic Flashlight Detection & Manual Override

Document Scanner automatically detects whether the device's camera hardware has an LED flashlight unit (Samsung tablets, front cameras, and emulators do not have one). If no flash unit exists, the flashlight button is automatically hidden from the UI.

To manually force or hide the flashlight toggle:

```dart
// Auto-detect hardware flash (default):
await DocumentScanner.getPictures(context: context, showFlashlight: null);

// Force flashlight button visible:
await DocumentScanner.getPictures(context: context, showFlashlight: true);

// Force flashlight button hidden:
await DocumentScanner.getPictures(context: context, showFlashlight: false);
```

---

### Recipe 4: Interactive Tap-to-Focus

Users can tap anywhere on the camera preview to focus the camera lens and meter exposure at that exact point. An animated focus bracket animates at the tapped coordinate:

```dart
await DocumentScanner.getPictures(
  context: context,
  enableTapToFocus: true, // enabled by default
);
```

---

### Recipe 5: Custom Brand Styling (`OverlayStyle`)

Easily harmonize the live detection polygon with your application's brand color:

```dart
// Option A: Convenient shortcut parameters
await DocumentScanner.getPictures(
  context: context,
  edgeColor: Colors.deepPurpleAccent,
  steadyEdgeColor: Colors.tealAccent,
  fillColor: Colors.deepPurple.withValues(alpha: 0.15),
);

// Option B: Auto-harmonized from single brand color
await DocumentScanner.getPictures(
  context: context,
  overlayStyle: OverlayStyle.fromColor(
    Colors.deepOrange,
    showGridLines: true,
    showCornerDots: true,
  ),
);

// Option C: Granular style specification
await DocumentScanner.getPictures(
  context: context,
  overlayStyle: const OverlayStyle(
    borderColor: Color(0xFF00E676),
    steadyBorderColor: Color(0xFF69F0AE),
    fillColor: Color(0x3300E676),
    borderWidth: 3.0,
    cornerDotRadius: 7.0,
    cornerDotColor: Colors.white,
    showCornerDots: true,
    showGridLines: true,
    gridColor: Color(0x22FFFFFF),
    pulseWhenSteady: true,
  ),
);
```

---

### Recipe 6: Custom Output Directory

By default, scanned documents are saved as high-quality JPEGs in the app's temporary cache directory. You can specify a custom `Directory` to save directly to persistent application storage:

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final appDocsDir = await getApplicationDocumentsDirectory();

final List<String>? files = await DocumentScanner.getPictures(
  context: context,
  outputDirectory: appDocsDir,
);
```

---

### Recipe 7: Embeddable Camera Widget (`DocumentScannerCamera`)

If you want to build a completely custom UI or embed the camera scanner into an existing screen:

```dart
import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

class EmbeddedScannerWidget extends StatefulWidget {
  const EmbeddedScannerWidget({super.key});

  @override
  State<EmbeddedScannerWidget> createState() => _EmbeddedScannerWidgetState();
}

class _EmbeddedScannerWidgetState extends State<EmbeddedScannerWidget> {
  late final DocumentScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DocumentScannerController(
      enableAutoCapture: true,
      defaultFilter: ScanFilter.enhance,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DocumentScannerCamera(
        controller: _controller,
        appBarTitle: 'Scan Document',
        isGalleryImportAllowed: true,
        enableTapToFocus: true,
        openCropScreenOnCapture: true,
        onScanned: (ScannedDocument doc) {
          print('Cropped document dimensions: ${doc.width}x${doc.height}');
        },
        onPageScanned: (ScannedDocumentPage page) {
          print('Original image path: ${page.originalImagePath}');
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      ),
    );
  }
}
```

---

### Recipe 8: Standalone Corner Adjustment (`CropAdjustmentScreen`)

If your app already has an image on disk and detected corners, you can launch `CropAdjustmentScreen` directly:

```dart
final result = await Navigator.of(context).push<dynamic>(
  MaterialPageRoute(
    builder: (_) => CropAdjustmentScreen(
      imagePath: imageFile.path,
      initialCorners: detectedCorners,
      controller: _controller,
      initialFilter: ScanFilter.enhance,
      showPreviewConfirmation: true,
    ),
  ),
);

if (result is CropAdjustmentResult) {
  print('Adjusted corners: ${result.corners}');
  print('Cropped bytes: ${result.document.bytes.length}');
}
```

---

## API Reference

### `DocumentScanner.getPictures(...)`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `context` | `BuildContext?` | `null` | Context used to push scanner route. Optional if `DocumentScanner.navigatorKey` is set. |
| `isGalleryImportAllowed` | `bool` | `false` | When true, renders a gallery button allowing importing and scanning photos from the photo library. |
| `noOfPages` | `int?` | `1` | Maximum pages allowed. Defaults to `1` (completes and returns immediately upon preview confirmation). If `> 1`, allows batch scanning up to the limit. |
| `edgeColor` | `Color?` | `null` | Shortcut for the detected quad border and crop adjustment handles. |
| `steadyEdgeColor` | `Color?` | `null` | Shortcut for border color when document is held steady and ready for capture. |
| `fillColor` | `Color?` | `null` | Shortcut for quad interior semi-transparent fill color. |
| `overlayStyle` | `OverlayStyle?` | `null` | Granular styling for quad overlay lines, grid, and corner pins. |
| `initialFilter` | `ScanFilter` | `ScanFilter.enhance` | Default filter applied to the scanned document. |
| `imageFilters` | `List<ScanFilter>?` | `null` | Available filters displayed in the adjustment and review screens. |
| `appBarTitle` | `String` | `'Scan Document'` | Title displayed in the top navigation bar. |
| `showPreviewConfirmation` | `bool` | `true` | Whether to show the cropped document preview screen before saving. |
| `enableTapToFocus` | `bool` | `true` | Whether to allow tapping on the camera preview to focus and meter exposure. |
| `showFlashlight` | `bool?` | `null` | Explicit override for flashlight button visibility. If `null`, auto-detects hardware flash support. |
| `outputDirectory` | `Directory?` | `null` | Custom directory to write scanned files. If `null`, uses temporary cache directory. |

---

### `OverlayStyle`

| Property | Type | Default | Description |
|---|---|---|---|
| `borderColor` | `Color` | `Color(0xFF4CAF50)` | Border stroke color when a document quad is detected. |
| `steadyBorderColor` | `Color` | `Color(0xFF00E676)` | Border stroke color when document is held steady for auto-capture. |
| `fillColor` | `Color` | `Color(0x334CAF50)` | Fill color inside the detected quad. |
| `borderWidth` | `double` | `2.5` | Thickness of the quad border lines. |
| `cornerDotRadius` | `double` | `6.0` | Radius of corner handle dots. |
| `cornerDotColor` | `Color` | `Colors.white` | Color of corner handle dots. |
| `showCornerDots` | `bool` | `true` | Whether to draw circle dots at each corner vertex. |
| `showGridLines` | `bool` | `false` | Whether to draw guide grid lines inside the quad. |
| `gridColor` | `Color` | `Color(0x22FFFFFF)` | Color of guide grid lines. |
| `pulseWhenSteady` | `bool` | `true` | Whether to visually pulse when document is steady and ready. |

---

### `DocumentScannerController`

| Method / Property | Description |
|---|---|
| `initialize()` | Requests permissions, discovers camera hardware, probes flash availability, and starts image stream. |
| `resumePreview()` | Resumes camera streaming and edge detection pipeline after capture or error. |
| `toggleFlash()` | Toggles camera flashlight/torch mode. Returns `false` if unsupported. |
| `toggleAutoCapture()` | Enables or disables steadiness auto-capture mode. |
| `setFocusPoint(Offset? point)` | Sets sensor focus and exposure metering point (normalized `0.0..1.0`). |
| `takePhoto()` | Takes a high-resolution still photo without immediately cropping it. |
| `cropFile(filePath, corners)` | Perspective-crops and deskews a photo from disk on a background isolate. |
| `rotateDocument(doc, degrees)` | Rotates a scanned document image on a background isolate (default 90°). |
| `applyFilterToDocument(doc, filter)` | Applies a filter to an already-cropped document on a background isolate. |
| `isFlashOn` | Whether the camera torch is currently active. |
| `hasFlash` | Whether the device camera has a physical flashlight unit. |
| `isInitialized` | Whether the underlying camera controller is active and streaming. |
| `isDisposed` | Whether the controller has been disposed. |
| `state` | Current lifecycle state (`initializing`, `previewing`, `capturing`, `processing`, `done`, `error`). |
| `detectedCorners` | Currently detected normalized 4-corner quad geometry. |
| `autoCaptureStatus` | Current steadiness status (`searching`, `steady`, `ready`). |

---

### Available Scan Filters

The following filters from `document_scan` are supported:

| Filter | Description |
|---|---|
| `ScanFilter.enhance` | Clean "scanned" look: contrast boost + full-range normalization. |
| `ScanFilter.magicColor` | Local adaptive thresholding; whitens paper and enhances ink evenly. |
| `ScanFilter.blackWhite` | High-contrast black & white using Otsu's binarization. |
| `ScanFilter.grayscale` | Desaturated neutral grayscale. |
| `ScanFilter.sharpen` | High-pass kernel sharpening to enhance document clarity. |
| `ScanFilter.none` | Preserves original color image without filters. |

---

## Troubleshooting & FAQ

### 1. `PermissionDenied` error on Android
Make sure `<uses-permission android:name="android.permission.CAMERA" />` is declared in `android/app/src/main/AndroidManifest.xml` and permissions are granted at runtime.

### 2. Tablets or Emulators without Flashlight
On Android tablets (such as Samsung Galaxy Tab A) or front-facing cameras without an LED, calling `setFlashMode(FlashMode.torch)` throws a driver error. Document Scanner automatically probes the sensor on startup; if flash is missing, `controller.hasFlash` resolves to `false` and the flashlight button is cleanly hidden.

### 3. Gradle OpenCV Error
If your build fails with conflicting OpenCV dependencies, add this resolution strategy to your app's `android/build.gradle.kts`:

```kotlin
allprojects {
    configurations.all {
        resolutionStrategy {
            force("org.opencv:opencv:4.12.0")
        }
    }
}
```

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
