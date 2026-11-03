import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverlayStyle Tests', () {
    test('Default values are correct', () {
      const style = OverlayStyle();
      expect(style.borderWidth, equals(2.5));
      expect(style.cornerDotRadius, equals(6.0));
      expect(style.showCornerDots, isTrue);
      expect(style.showGridLines, isFalse);
      expect(style.pulseWhenSteady, isTrue);
    });

    test('copyWith updates properties properly', () {
      const style = OverlayStyle();
      final updated = style.copyWith(
        borderWidth: 4.0,
        showGridLines: true,
        cornerDotRadius: 10.0,
        borderColor: Colors.red,
      );

      expect(updated.borderWidth, equals(4.0));
      expect(updated.showGridLines, isTrue);
      expect(updated.cornerDotRadius, equals(10.0));
      expect(updated.borderColor, equals(Colors.red));
      // Unchanged properties
      expect(updated.showCornerDots, isTrue);
      expect(updated.pulseWhenSteady, isTrue);
    });

    test('OverlayStyle.fromColor creates harmonized style', () {
      final style = OverlayStyle.fromColor(
        Colors.blue,
        steadyBorderColor: Colors.amber,
        borderWidth: 3.0,
      );

      expect(style.borderColor, equals(Colors.blue));
      expect(style.steadyBorderColor, equals(Colors.amber));
      expect(style.borderWidth, equals(3.0));
      expect(style.fillColor, equals(Colors.blue.withValues(alpha: 0.2)));
    });

    test('equality and hashCode work as expected', () {
      const style1 = OverlayStyle(borderColor: Colors.red);
      const style2 = OverlayStyle(borderColor: Colors.red);
      const style3 = OverlayStyle(borderColor: Colors.blue);

      expect(style1, equals(style2));
      expect(style1.hashCode, equals(style2.hashCode));
      expect(style1, isNot(equals(style3)));
    });
  });
}

