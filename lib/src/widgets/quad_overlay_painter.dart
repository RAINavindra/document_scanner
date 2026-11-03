import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

import '../models/overlay_style.dart';

/// CustomPainter that renders a dynamic, animated quad overlay over the camera preview.
class QuadOverlayPainter extends CustomPainter {
  const QuadOverlayPainter({
    required this.corners,
    required this.style,
    this.isSteady = false,
  });

  final DocumentCorners corners;
  final OverlayStyle style;
  final bool isSteady;

  @override
  void paint(Canvas canvas, Size size) {
    final tl = Offset(corners.topLeft.x * size.width, corners.topLeft.y * size.height);
    final tr = Offset(corners.topRight.x * size.width, corners.topRight.y * size.height);
    final br = Offset(corners.bottomRight.x * size.width, corners.bottomRight.y * size.height);
    final bl = Offset(corners.bottomLeft.x * size.width, corners.bottomLeft.y * size.height);

    // 1. Build polygon path
    final quadPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    // 2. Fill quad area
    final fillPaint = Paint()
      ..color = isSteady
          ? style.steadyBorderColor.withValues(alpha: 0.25)
          : style.fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(quadPath, fillPaint);

    // 3. Optional grid lines
    if (style.showGridLines) {
      final gridPaint = Paint()
        ..color = style.gridColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      for (int i = 1; i <= 2; i++) {
        final t = i / 3.0;
        // Horizontal grid line
        final leftPt = Offset.lerp(tl, bl, t)!;
        final rightPt = Offset.lerp(tr, br, t)!;
        canvas.drawLine(leftPt, rightPt, gridPaint);

        // Vertical grid line
        final topPt = Offset.lerp(tl, tr, t)!;
        final bottomPt = Offset.lerp(bl, br, t)!;
        canvas.drawLine(topPt, bottomPt, gridPaint);
      }
    }

    // 4. Border stroke
    final activeBorderColor = isSteady ? style.steadyBorderColor : style.borderColor;
    final strokePaint = Paint()
      ..color = activeBorderColor
      ..strokeWidth = style.borderWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(quadPath, strokePaint);

    // 5. Draw corner pins
    if (style.showCornerDots) {
      final dotPaint = Paint()
        ..color = style.cornerDotColor
        ..style = PaintingStyle.fill;

      final dotBorderPaint = Paint()
        ..color = activeBorderColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      for (final pt in [tl, tr, br, bl]) {
        canvas.drawCircle(pt, style.cornerDotRadius, dotPaint);
        canvas.drawCircle(pt, style.cornerDotRadius, dotBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant QuadOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.style != style ||
        oldDelegate.isSteady != isSteady;
  }
}

