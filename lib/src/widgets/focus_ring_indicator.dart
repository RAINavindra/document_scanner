import 'package:flutter/material.dart';

/// Animated camera focus and exposure metering reticle indicator.
///
/// Appears at the tapped viewport coordinates, scales in sharply,
/// blinks briefly to signify focus acquisition, and fades out.
class FocusRingIndicator extends StatefulWidget {
  const FocusRingIndicator({
    super.key,
    required this.position,
    this.size = 68.0,
    this.color = Colors.amber,
    this.duration = const Duration(milliseconds: 1200),
    this.onCompleted,
  });

  /// The screen position where the user tapped.
  final Offset position;

  /// The diameter of the outer focus reticle.
  final double size;

  /// Accent color of the reticle brackets and center point.
  final Color color;

  /// Total duration of the animation lifecycle before self-dismissal.
  final Duration duration;

  /// Optional callback invoked when the fade-out completes.
  final VoidCallback? onCompleted;

  @override
  State<FocusRingIndicator> createState() => _FocusRingIndicatorState();
}

class _FocusRingIndicatorState extends State<FocusRingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Initial spring scale from 1.4 down to 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
    ]).animate(_controller);

    // Fade out towards the end
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onCompleted?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - widget.size / 2,
      top: widget.position.dy - widget.size / 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _FocusReticlePainter(color: widget.color),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FocusReticlePainter extends CustomPainter {
  const _FocusReticlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final cornerLen = w * 0.28;

    // 4 Corner Brackets
    // Top-Left
    canvas.drawLine(const Offset(0, 0), Offset(cornerLen, 0), strokePaint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerLen), strokePaint);

    // Top-Right
    canvas.drawLine(Offset(w, 0), Offset(w - cornerLen, 0), strokePaint);
    canvas.drawLine(Offset(w, 0), Offset(w, cornerLen), strokePaint);

    // Bottom-Left
    canvas.drawLine(Offset(0, h), Offset(cornerLen, h), strokePaint);
    canvas.drawLine(Offset(0, h), Offset(0, h - cornerLen), strokePaint);

    // Bottom-Right
    canvas.drawLine(Offset(w, h), Offset(w - cornerLen, h), strokePaint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cornerLen), strokePaint);

    // Center Dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _FocusReticlePainter oldDelegate) =>
      oldDelegate.color != color;
}

