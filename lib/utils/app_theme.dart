import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color palette - dark industrial with cyan accent
  static const Color background = Color(0xFF0A0C0F);
  static const Color surface = Color(0xFF131720);
  static const Color surfaceElevated = Color(0xFF1C2230);
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentDim = Color(0xFF00B8D4);
  static const Color accentGlow = Color(0x3300E5FF);
  static const Color warning = Color(0xFFFFB300);
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF1744);
  static const Color textPrimary = Color(0xFFECEFF1);
  static const Color textSecondary = Color(0xFF78909C);
  static const Color textDim = Color(0xFF37474F);
  static const Color divider = Color(0xFF1C2230);
  static const Color scanLine = Color(0x8000E5FF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentDim,
        surface: surface,
        error: error,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            color: textPrimary,
            fontSize: 48,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
          displayMedium: TextStyle(
            color: textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.0,
          ),
          headlineLarge: TextStyle(
            color: textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: textPrimary,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
          labelLarge: TextStyle(
            color: accent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      iconTheme: const IconThemeData(color: accent),
    );
  }
}
