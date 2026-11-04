## 0.0.1

* Initial release of `document_scanner`.
* **Turnkey API**: `DocumentScanner.getPictures(...)` for one-line document scanning with `navigatorKey` support.
* **Live Camera Stream**: Real-time edge detection and quad tracking over camera preview frames.
* **Auto-Capture**: Intelligent frame steadiness analysis with automatic capture triggering.
* **Tap-to-Focus**: Interactive animated reticle indicator with camera lens focus and exposure metering.
* **Hardware Flashlight Auto-Detection**: Sensor hardware detection to display or hide the flashlight toggle based on physical LED presence.
* **Manual Corner Adjustment**: Interactive 4-corner draggable adjustment screen with real-time magnifier loupe.
* **Cropped Document Preview**: Pinch-to-zoom interactive viewer, 90° clockwise rotation, and non-destructive filter preview.
* **Multi-Page Batch Review**: Swipeable page carousel with thumbnail strip, re-cropping from raw uncropped images, rotation, filter switching with "Apply to all", and page deletion.
* **Page Limit Enforcement**: `noOfPages` parameter that locks shutter, suppresses auto-capture, and hides the "+ Add" button once limit is reached.
* **Custom Overlays**: `OverlayStyle` with auto-harmonization from brand colors, guide grids, and corner vertex pins.
* **Background Isolate Processing**: Off-thread image warping, perspective correction, rotation, and scan filtering.
