import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

import 'models/overlay_style.dart';
import 'widgets/document_scanner_screen.dart';

/// Top-level facade offering a turnkey, one-line document scanning API.
class DocumentScanner {
  /// Global navigator key allowing [getPictures] to be called without explicitly passing [BuildContext].
  ///
  /// Set this in your [MaterialApp.navigatorKey]:
  /// ```dart
  /// MaterialApp(
  ///   navigatorKey: DocumentScanner.navigatorKey,
  ///   ...
  /// )
  /// ```
  static GlobalKey<NavigatorState>? navigatorKey = GlobalKey<NavigatorState>();

  /// Launches the document scanner flow and returns a list of local file paths
  /// to the scanned, perspective-corrected document images.
  ///
  /// Example:
  /// ```dart
  /// final files = await DocumentScanner.getPictures(
  ///   context: context,
  ///   isGalleryImportAllowed: true,
  ///   noOfPages: 3,
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [context]: BuildContext used to push the scanner. Required unless [navigatorKey] is attached to your [MaterialApp].
  /// - [isGalleryImportAllowed]: When true, displays a gallery button allowing importing and scanning photos from the photo gallery.
  /// - [noOfPages]: The maximum number of pages to scan. If 1, automatically finishes after 1 scan. If null or > 1, allows batch scanning.
  /// - [edgeColor]: Color of the detected quad border and crop adjustment handles.
  /// - [steadyEdgeColor]: Color of the border when document is held steady and ready for capture.
  /// - [fillColor]: Color of the semi-transparent overlay inside the detected document.
  /// - [overlayStyle]: Granular styling for the quad overlay lines, grid, and dots.
  /// - [initialFilter]: Default filter to apply to the scanned document.
  /// - [imageFilters]: List of available filters in the crop adjustment screen.
  /// - [appBarTitle]: Title displayed in the top bar.
  /// - [showPreviewConfirmation]: Whether to show the cropped document preview screen before saving. Defaults to true.
  ///
  /// Returns a `List<String>` containing the local file paths of the scanned documents,
  /// or `null` if the user closed the scanner without scanning any documents.
  static Future<List<String>?> getPictures({
    BuildContext? context,
    bool isGalleryImportAllowed = false,
    int? noOfPages,
    Color? edgeColor,
    Color? steadyEdgeColor,
    Color? fillColor,
    OverlayStyle? overlayStyle,
    ScanFilter initialFilter = ScanFilter.enhance,
    List<ScanFilter>? imageFilters,
    String appBarTitle = 'Scan Document',
    bool showPreviewConfirmation = true,
  }) async {
    final targetContext = context ?? navigatorKey?.currentContext;
    if (targetContext == null) {
      throw StateError(
        'DocumentScanner.getPictures requires either a valid BuildContext or '
        'DocumentScanner.navigatorKey to be assigned to your MaterialApp.',
      );
    }

    return Navigator.of(targetContext).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => DocumentScannerScreen(
          isGalleryImportAllowed: isGalleryImportAllowed,
          noOfPages: noOfPages,
          edgeColor: edgeColor,
          steadyEdgeColor: steadyEdgeColor,
          fillColor: fillColor,
          overlayStyle: overlayStyle ?? const OverlayStyle(),
          initialFilter: initialFilter,
          imageFilters: imageFilters,
          appBarTitle: appBarTitle,
          showPreviewConfirmation: showPreviewConfirmation,
        ),
      ),
    );
  }
}

