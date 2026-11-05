import 'dart:typed_data';
import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal 1x1 transparent PNG bytes for mock Image.memory
final Uint8List kTestImageBytes = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0,
  10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45,
  180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  group('DocumentScanner Facade Tests', () {
    test('navigatorKey is non-null by default', () {
      expect(DocumentScanner.navigatorKey, isNotNull);
    });

    test('getPictures throws StateError when no context or navigatorKey context is available', () async {
      DocumentScanner.navigatorKey = null;

      expect(
        () => DocumentScanner.getPictures(),
        throwsA(isA<StateError>()),
      );

      // Restore key
      DocumentScanner.navigatorKey = GlobalKey<NavigatorState>();
    });

    testWidgets('DocumentScannerScreen can be instantiated with default and custom values', (tester) async {
      const screen = DocumentScannerScreen(
        isGalleryImportAllowed: true,
        noOfPages: 3,
        edgeColor: Colors.purple,
        steadyEdgeColor: Colors.green,
        fillColor: Colors.blue,
        appBarTitle: 'Custom Scanner',
      );

      expect(screen.isGalleryImportAllowed, isTrue);
      expect(screen.noOfPages, equals(3));
      expect(screen.edgeColor, equals(Colors.purple));
      expect(screen.steadyEdgeColor, equals(Colors.green));
      expect(screen.fillColor, equals(Colors.blue));
      expect(screen.appBarTitle, equals('Custom Scanner'));
      expect(screen.showPreviewConfirmation, isTrue);
      expect(screen.enableTapToFocus, isTrue);
    });

    test('DocumentPreviewResult carries properties correctly', () {
      const result = DocumentPreviewResult(isRetake: true);
      expect(result.isRetake, isTrue);
      expect(result.document, isNull);
      expect(result.toString(), contains('isRetake: true'));

      const result2 = DocumentPreviewResult(isRetake: true);
      expect(result, equals(result2));
      expect(result.hashCode, equals(result2.hashCode));
    });

    test('ScannedDocumentPage model holds, updates, compares, and prints properties correctly', () {
      final doc = ScannedDocument(bytes: kTestImageBytes, width: 1, height: 1);
      const corners = DocumentCorners(
        topLeft: (x: 0.1, y: 0.1),
        topRight: (x: 0.9, y: 0.1),
        bottomRight: (x: 0.9, y: 0.9),
        bottomLeft: (x: 0.1, y: 0.9),
      );

      final page = ScannedDocumentPage(
        originalImagePath: '/path/to/img.jpg',
        corners: corners,
        document: doc,
        baseDocument: doc,
        filter: ScanFilter.enhance,
        rotationDegrees: 0,
      );

      expect(page.originalImagePath, equals('/path/to/img.jpg'));
      expect(page.corners, equals(corners));
      expect(page.document, equals(doc));
      expect(page.filter, equals(ScanFilter.enhance));
      expect(page.rotationDegrees, equals(0));
      expect(page.toString(), contains('/path/to/img.jpg'));

      final updated = page.copyWith(
        rotationDegrees: 90,
        filter: ScanFilter.magicColor,
      );

      expect(updated.rotationDegrees, equals(90));
      expect(updated.filter, equals(ScanFilter.magicColor));
      expect(updated.originalImagePath, equals('/path/to/img.jpg'));

      final duplicate = ScannedDocumentPage(
        originalImagePath: '/path/to/img.jpg',
        corners: corners,
        document: doc,
        baseDocument: doc,
        filter: ScanFilter.enhance,
        rotationDegrees: 0,
      );
      expect(page, equals(duplicate));
      expect(page.hashCode, equals(duplicate.hashCode));
    });

    test('CropAdjustmentResult converts to ScannedDocumentPage accurately and supports equality', () {
      final doc = ScannedDocument(bytes: kTestImageBytes, width: 1, height: 1);
      const corners = DocumentCorners(
        topLeft: (x: 0.05, y: 0.05),
        topRight: (x: 0.95, y: 0.05),
        bottomRight: (x: 0.95, y: 0.95),
        bottomLeft: (x: 0.05, y: 0.95),
      );

      final cropResult = CropAdjustmentResult(
        document: doc,
        baseDocument: doc,
        originalImagePath: '/test/photo.jpg',
        corners: corners,
        filter: ScanFilter.blackWhite,
        rotationDegrees: 180,
      );

      final page = cropResult.toScannedDocumentPage();
      expect(page.originalImagePath, equals('/test/photo.jpg'));
      expect(page.corners, equals(corners));
      expect(page.document, equals(doc));
      expect(page.baseDocument, equals(doc));
      expect(page.filter, equals(ScanFilter.blackWhite));
      expect(page.rotationDegrees, equals(180));
      expect(cropResult.toString(), contains('/test/photo.jpg'));

      final duplicate = CropAdjustmentResult(
        document: doc,
        baseDocument: doc,
        originalImagePath: '/test/photo.jpg',
        corners: corners,
        filter: ScanFilter.blackWhite,
        rotationDegrees: 180,
      );
      expect(cropResult, equals(duplicate));
      expect(cropResult.hashCode, equals(duplicate.hashCode));
    });

    test('Controller handles toggleFlash and setFocusPoint gracefully and tracks isDisposed', () async {
      final controller = DocumentScannerController();
      expect(controller.isDisposed, isFalse);

      final result = await controller.toggleFlash();
      expect(result, isFalse);
      expect(controller.isFlashOn, isFalse);

      await controller.setFocusPoint(const Offset(0.5, 0.5));
      await controller.setFocusPoint(null);

      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });

    testWidgets('FocusRingIndicator renders and completes animation', (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FocusRingIndicator(
                  position: const Offset(100, 100),
                  size: 64.0,
                  onCompleted: () => completed = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FocusRingIndicator), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(completed, isTrue);
    });

    testWidgets('MultiDocumentReviewScreen renders pages, actions, and thumbnails', (tester) async {
      final doc = ScannedDocument(bytes: kTestImageBytes, width: 1, height: 1);
      const corners = DocumentCorners(
        topLeft: (x: 0.0, y: 0.0),
        topRight: (x: 1.0, y: 0.0),
        bottomRight: (x: 1.0, y: 1.0),
        bottomLeft: (x: 0.0, y: 1.0),
      );

      final pages = [
        ScannedDocumentPage(
          originalImagePath: '/test/page1.jpg',
          corners: corners,
          document: doc,
          baseDocument: doc,
          filter: ScanFilter.enhance,
        ),
        ScannedDocumentPage(
          originalImagePath: '/test/page2.jpg',
          corners: corners,
          document: doc,
          baseDocument: doc,
          filter: ScanFilter.enhance,
        ),
      ];

      final controller = DocumentScannerController();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiDocumentReviewScreen(
            pages: pages,
            controller: controller,
            appBarTitle: 'Review Documents',
          ),
        ),
      );

      // Verify header with page count
      expect(find.text('Review Documents (1/2)'), findsOneWidget);
      expect(find.text('Confirm (2)'), findsOneWidget);

      // Verify Action Toolbar buttons
      expect(find.text('Re-crop'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Verify "+ Add" button in thumbnail strip
      expect(find.text('Add'), findsOneWidget);

      // Verify tapping Delete shows confirmation dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Page?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Page?'), findsNothing);

      // Verify tapping Filter shows bottom sheet
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Filter'), findsOneWidget);
      expect(find.text('Apply to all'), findsOneWidget);
    });

    test('DocumentScannerController tracks flash availability and crop corners', () {
      final controller = DocumentScannerController();
      expect(controller.hasFlash, isFalse);
      controller.hasFlash = true;
      expect(controller.hasFlash, isTrue);

      expect(controller.lastCropCorners, isNull);
    });

    testWidgets('DocumentScannerScreen supports showFlashlight and defaults noOfPages to 1', (tester) async {
      const screenDefault = DocumentScannerScreen();
      expect(screenDefault.noOfPages, equals(1));

      const screenWithFlash = DocumentScannerScreen(
        showFlashlight: true,
        noOfPages: 5,
      );
      expect(screenWithFlash.showFlashlight, isTrue);
      expect(screenWithFlash.noOfPages, equals(5));

      const screenWithoutFlash = DocumentScannerScreen(
        showFlashlight: false,
      );
      expect(screenWithoutFlash.showFlashlight, isFalse);
      expect(screenWithoutFlash.noOfPages, equals(1));

      const screenExplicitNull = DocumentScannerScreen(
        noOfPages: null,
      );
      expect(screenExplicitNull.noOfPages, isNull);
    });

    testWidgets('MultiDocumentReviewScreen hides Add button when limit reached and shows it when page deleted', (tester) async {
      final doc = ScannedDocument(bytes: kTestImageBytes, width: 1, height: 1);
      const corners = DocumentCorners(
        topLeft: (x: 0.0, y: 0.0),
        topRight: (x: 1.0, y: 0.0),
        bottomRight: (x: 1.0, y: 1.0),
        bottomLeft: (x: 0.0, y: 1.0),
      );

      final pages = [
        ScannedDocumentPage(
          originalImagePath: '/test/page1.jpg',
          corners: corners,
          document: doc,
          baseDocument: doc,
          filter: ScanFilter.enhance,
        ),
        ScannedDocumentPage(
          originalImagePath: '/test/page2.jpg',
          corners: corners,
          document: doc,
          baseDocument: doc,
          filter: ScanFilter.enhance,
        ),
      ];

      final controller = DocumentScannerController();
      dynamic poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MultiDocumentReviewScreen(
                      pages: pages,
                      controller: controller,
                      noOfPages: 2,
                    ),
                  ),
                );
              },
              child: const Text('Open Review'),
            ),
          ),
        ),
      );

      // Open screen
      await tester.tap(find.text('Open Review'));
      await tester.pumpAndSettle();

      // Because pages.length (2) == noOfPages (2), Add button is hidden
      expect(find.text('Add'), findsNothing);

      // Delete one page
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last); // Confirm delete in dialog
      await tester.pumpAndSettle();

      // Now pages.length is 1 < noOfPages (2), Add button appears!
      expect(find.text('Add'), findsOneWidget);

      // Tap Add button to pop back to camera
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify poppedResult is List<ScannedDocumentPage> with 1 page
      expect(poppedResult, isA<List<ScannedDocumentPage>>());
      expect((poppedResult as List<ScannedDocumentPage>).length, equals(1));
    });

    testWidgets('MultiDocumentReviewScreen auto-pops when all pages are deleted', (tester) async {
      final doc = ScannedDocument(bytes: kTestImageBytes, width: 1, height: 1);
      const corners = DocumentCorners(
        topLeft: (x: 0.0, y: 0.0),
        topRight: (x: 1.0, y: 0.0),
        bottomRight: (x: 1.0, y: 1.0),
        bottomLeft: (x: 0.0, y: 1.0),
      );

      final pages = [
        ScannedDocumentPage(
          originalImagePath: '/test/page1.jpg',
          corners: corners,
          document: doc,
          baseDocument: doc,
          filter: ScanFilter.enhance,
        ),
      ];

      final controller = DocumentScannerController();
      dynamic poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MultiDocumentReviewScreen(
                      pages: pages,
                      controller: controller,
                      noOfPages: 1,
                    ),
                  ),
                );
              },
              child: const Text('Open Review Single'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Review Single'));
      await tester.pumpAndSettle();

      // Delete the only page
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // Automatically returned back to caller with empty list
      expect(find.text('Open Review Single'), findsOneWidget);
      expect(poppedResult, isA<List<ScannedDocumentPage>>());
      expect((poppedResult as List<ScannedDocumentPage>).isEmpty, isTrue);
    });
  });
}
