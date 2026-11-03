/// The current lifecycle state of the document scanner.
enum ScannerState {
  /// Requesting permissions and initializing camera hardware.
  initializing,

  /// Camera preview is running, streaming frames, and analyzing for document edges.
  previewing,

  /// High-resolution photo is being captured from the camera.
  capturing,

  /// Perspective warp and image filtering are processing in the background.
  processing,

  /// Document scan has completed successfully.
  done,

  /// An error occurred during initialization, capture, or processing.
  error,
}
