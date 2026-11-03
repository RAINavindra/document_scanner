import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuadOverlayPainter Tests', () {
    const corners = DocumentCorners(
      topLeft: (x: 0.1, y: 0.1),
      topRight: (x: 0.9, y: 0.1),
      bottomRight: (x: 0.9, y: 0.9),
      bottomLeft: (x: 0.1, y: 0.9),
    );

    testWidgets('Renders CustomPaint without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: Size(300, 400),
              painter: QuadOverlayPainter(
                corners: corners,
                style: OverlayStyle(showGridLines: true),
                isSteady: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('shouldRepaint returns true when properties change', () {
      const painter1 = QuadOverlayPainter(
        corners: corners,
        style: OverlayStyle(),
        isSteady: false,
      );

      const painter2 = QuadOverlayPainter(
        corners: corners,
        style: OverlayStyle(),
        isSteady: true,
      );

      const painter3 = QuadOverlayPainter(
        corners: corners,
        style: OverlayStyle(),
        isSteady: false,
        imageRect: Rect.fromLTWH(10, 10, 100, 100),
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
      expect(painter3.shouldRepaint(painter1), isTrue);
    });
  });
}

