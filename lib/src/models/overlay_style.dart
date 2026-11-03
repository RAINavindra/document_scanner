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
}

