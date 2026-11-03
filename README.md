# Document Scanner (`document_scanner`)

A turnkey, high-performance Flutter document scanner package. Combines the official Flutter `camera` stream with [`document_scan`](https://pub.dev/packages/document_scan) for real-time edge detection, auto-capture, manual corner adjustment, perspective correction, and image filtering.

**Zero custom native code required** — 100% pure Dart orchestration on top of established plugins.

---

## Features

- 📸 **Live Camera Stream Edge Detection:** Real-time quad tracking directly over camera preview via Android YUV420 frame streaming.
- ⚡ **Auto-Capture:** Analyzes consecutive frame steadiness and confidence to automatically snap the photo when held still.
- 🎯 **Manual Corner Adjustment:** Post-capture adjustment screen with 4 draggable corner handles and real-time magnifier loupe.
- 🪄 **Perspective Correction & Filters:** Crops, deskews, and applies clean scan filters (`enhance`, `magicColor`, `blackWhite`, `grayscale`, `none`) on background isolates.
- 🔦 **Camera Controls:** Flash / torch toggle, camera switching, and auto-capture mode toggle.
- 🎨 **Customizable Overlays:** Configure quad fill color, border styles, corner pins, and guide grids via `OverlayStyle`.

---

## Installation

Add `document_scanner` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  document_scanner: ^0.0.1
```

### Android Setup

Add the camera permission to `android/app/src/main/AndroidManifest.xml`:

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

In `android/app/build.gradle.kts`, ensure your `minSdk` is at least 24 and `compileSdk` is at least 35:

```kotlin
android {
    compileSdk = 36 // or 35+
    defaultConfig {
        minSdk = 24
    }
}
```

> **Note on Android 37:** `permission_handler` 13+ introduced a requirement for `compileSdk = 37`. This package pins `permission_handler: ^12.0.3` to maintain standard compatibility with `compileSdk 35/36` and AGP 8/9.
    defaultConfig {
        minSdk = 24
    }
}
```

---

## Quickstart

### 1. One-Line Turnkey API (Recommended)

Call `DocumentScanner.getPictures(...)` directly without manually creating controllers, routes, or widgets. It launches a complete scanning flow with camera preview, auto-capture, gallery import, manual corner adjustment, and filters, returning a list of local image file paths:

```dart
import 'package:document_scanner/document_scanner.dart';

// In any async function:
final List<String>? pictures = await DocumentScanner.getPictures(
  context: context, // optional if DocumentScanner.navigatorKey is set in MaterialApp
  isGalleryImportAllowed: true,
  noOfPages: 3, // optional limit; batch scans until limit or user taps 'Done'
  edgeColor: Colors.blueAccent,
);

if (pictures != null && pictures.isNotEmpty) {
  for (final path in pictures) {
    print('Scanned document saved at: $path');
  }
}
```

#### Setup with `navigatorKey` (No `BuildContext` Needed):
```dart
MaterialApp(
  navigatorKey: DocumentScanner.navigatorKey,
  home: const MyHomePage(),
);

// Then anywhere in your app:
final pictures = await DocumentScanner.getPictures(isGalleryImportAllowed: true);
```

---

### 2. Embeddable Scanner Camera Widget (Advanced)

If you need custom routing or want to embed the scanner directly into an existing widget tree:

```dart
import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

class MyScannerPage extends StatefulWidget {
  const MyScannerPage({super.key});

  @override
  State<MyScannerPage> createState() => _MyScannerPageState();
}

class _MyScannerPageState extends State<MyScannerPage> {
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
    return DocumentScannerCamera(
      controller: _controller,
      appBarTitle: 'Scan Document',
      openCropScreenOnCapture: true, // Opens corner adjustment before saving
      onScanned: (ScannedDocument doc) {
        // Access cropped & perspective-corrected bytes
        final Uint8List imageBytes = doc.bytes;
        print('Scanned document: ${doc.width}x${doc.height} (${imageBytes.length} bytes)');
        
        Navigator.of(context).pop(doc);
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      },
    );
  }
}
```

---

### 2. Manual Corner Adjustment Screen

If you already have a photo file and detected corners, you can present the `CropAdjustmentScreen` directly:

```dart
final ScannedDocument? result = await Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => CropAdjustmentScreen(
      imagePath: imageFile.path,
      initialCorners: detectedCorners,
      controller: _controller,
      initialFilter: ScanFilter.enhance,
    ),
  ),
);
```

---

### 3. Programmatic Control (`DocumentScannerController`)

You can also control the scanning process manually:

```dart
final controller = DocumentScannerController(
  enableAutoCapture: true,
  minDetectionInterval: const Duration(milliseconds: 100),
);

// Initialize camera hardware and begin stream
await controller.initialize();

// Toggle torch/flash
await controller.toggleFlash();

// Manually trigger capture and crop
final ScannedDocument? doc = await controller.captureAndProcess();

// Resume live detection
await controller.resumePreview();

// Clean up
controller.dispose();
```

---

## Styling the Overlay

Customize the live detection overlay using `OverlayStyle`:

```dart
DocumentScannerCamera(
  controller: _controller,
  overlayStyle: const OverlayStyle(
    borderColor: Color(0xFF00E676),
    fillColor: Color(0x3300E676),
    borderWidth: 3.0,
    showCornerDots: true,
    showGridLines: true,
  ),
  onScanned: (doc) { ... },
);
```

---

## Available Filters

The following filters from `document_scan` are supported:

| Filter | Description |
|---|---|
| `ScanFilter.enhance` | Clean "scanned" look: contrast boost + full-range normalization. |
| `ScanFilter.magicColor` | Local adaptive thresholding; whitens paper and enhances ink evenly. |
| `ScanFilter.blackWhite` | High-contrast black & white using Otsu's binarization. |
| `ScanFilter.grayscale` | Desaturated neutral grayscale. |
| `ScanFilter.none` | Preserves original color image without filters. |
