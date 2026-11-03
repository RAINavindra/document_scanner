import 'package:flutter/material.dart';

/// Styling options for the real-time quad overlay and guide indicators.
class OverlayStyle {
  const OverlayStyle({
    this.fillColor = const Color(0x334CAF50),
    this.borderColor = const Color(0xFF4CAF50),
    this.steadyBorderColor = const Color(0xFF00E676),
    this.borderWidth = 2.5,
    this.cornerDotRadius = 6.0,
    this.cornerDotColor = Colors.white,
    this.showCornerDots = true,
    this.showGridLines = false,
    this.gridColor = const Color(0x22FFFFFF),
    this.pulseWhenSteady = true,
  });

  /// Creates an [OverlayStyle] where edge, line, fill, and grid colors are
  /// automatically harmonized from a single base [color].
  factory OverlayStyle.fromColor(
    Color color, {
    Color? steadyBorderColor,
    double borderWidth = 2.5,
    double cornerDotRadius = 6.0,
    Color cornerDotColor = Colors.white,
    bool showCornerDots = true,
    bool showGridLines = false,
    Color? gridColor,
    bool pulseWhenSteady = true,
  }) {
    return OverlayStyle(
      borderColor: color,
      fillColor: color.withValues(alpha: 0.2),
      steadyBorderColor: steadyBorderColor ?? const Color(0xFF00E676),
      borderWidth: borderWidth,
      cornerDotRadius: cornerDotRadius,
      cornerDotColor: cornerDotColor,
      showCornerDots: showCornerDots,
      showGridLines: showGridLines,
      gridColor: gridColor ?? color.withValues(alpha: 0.15),
      pulseWhenSteady: pulseWhenSteady,
    );
  }

  /// Fill color inside the detected document quad.
  final Color fillColor;

  /// Border stroke color when a document quad is detected.
  final Color borderColor;

  /// Border stroke color when document is held steady and ready for capture.
  final Color steadyBorderColor;

  /// Thickness of the quad border lines.
  final double borderWidth;

  /// Radius of corner handle dots.
  final double cornerDotRadius;

  /// Color of the corner handle dots.
  final Color cornerDotColor;

  /// Whether to draw circle dots at each corner vertex.
  final bool showCornerDots;

  /// Whether to draw light grid lines inside the quad.
  final bool showGridLines;

  /// Color of internal grid guide lines.
  final Color gridColor;

  /// Whether to provide visual pulse when document is steady and ready.
  final bool pulseWhenSteady;

  OverlayStyle copyWith({
    Color? fillColor,
    Color? borderColor,
    Color? steadyBorderColor,
    double? borderWidth,
    double? cornerDotRadius,
    Color? cornerDotColor,
    bool? showCornerDots,
    bool? showGridLines,
    Color? gridColor,
    bool? pulseWhenSteady,
  }) {
    return OverlayStyle(
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      steadyBorderColor: steadyBorderColor ?? this.steadyBorderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerDotRadius: cornerDotRadius ?? this.cornerDotRadius,
      cornerDotColor: cornerDotColor ?? this.cornerDotColor,
      showCornerDots: showCornerDots ?? this.showCornerDots,
      showGridLines: showGridLines ?? this.showGridLines,
      gridColor: gridColor ?? this.gridColor,
      pulseWhenSteady: pulseWhenSteady ?? this.pulseWhenSteady,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayStyle &&
          runtimeType == other.runtimeType &&
          fillColor == other.fillColor &&
          borderColor == other.borderColor &&
          steadyBorderColor == other.steadyBorderColor &&
          borderWidth == other.borderWidth &&
          cornerDotRadius == other.cornerDotRadius &&
          cornerDotColor == other.cornerDotColor &&
          showCornerDots == other.showCornerDots &&
          showGridLines == other.showGridLines &&
          gridColor == other.gridColor &&
          pulseWhenSteady == other.pulseWhenSteady;

  @override
  int get hashCode => Object.hash(
        fillColor,
        borderColor,
        steadyBorderColor,
        borderWidth,
        cornerDotRadius,
        cornerDotColor,
        showCornerDots,
        showGridLines,
        gridColor,
        pulseWhenSteady,
      );
}

