import 'package:flutter/material.dart';

/// Map AtCoder rating to its representative color.
/// Based on typical AtCoder color bands.
Color atcoderRatingToColor(int rating) {
  if (rating >= 2800) return const Color(0xFFFF0000); // Red
  if (rating >= 2400) return const Color(0xFFFF8000); // Orange
  if (rating >= 2000) return const Color(0xFFC0C000); // Yellow
  if (rating >= 1600) return const Color(0xFF0000FF); // Blue
  if (rating >= 1200) return const Color(0xFF00C0C0); // Cyan
  if (rating >= 800) return const Color(0xFF008000);  // Green
  if (rating >= 400) return const Color(0xFF804000); // Brown
  return const Color(0xFF808080); // Gray
}
