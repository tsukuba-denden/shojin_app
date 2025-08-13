import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Returns a TextStyle for a monospace font.
///
/// Handles the generic 'monospace' family by returning a standard [TextStyle],
/// and uses [GoogleFonts.getFont] for any other font family from the Google Fonts library.
TextStyle getMonospaceTextStyle(
  String fontFamily, {
  double? fontSize,
  Color? color,
  FontWeight? fontWeight,
}) {
  if (fontFamily == 'monospace') {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }
  // Try Google Fonts first; if unavailable, fall back to asset/system font family
  try {
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  } catch (_) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }
}
