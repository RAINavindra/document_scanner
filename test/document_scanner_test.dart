import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    });

    test('DocumentPreviewResult carries properties correctly', () {
      const result = DocumentPreviewResult(isRetake: true);
      expect(result.isRetake, isTrue);
      expect(result.document, isNull);
    });
  });
}

