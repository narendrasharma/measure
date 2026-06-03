import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color black       = Color(0xFF000000);
  static const Color bg          = Color(0xFF0A0A0A);
  static const Color surface     = Color(0xFF1C1C1E);
  static const Color surfaceHigh = Color(0xFF2C2C2E);
  static const Color divider     = Color(0xFF38383A);
  static const Color yellow      = Color(0xFFFFCC00);
  static const Color yellowDim   = Color(0xFFB8940A);
  static const Color yellowGlow  = Color(0x33FFCC00);
  static const Color green       = Color(0xFF30D158);
  static const Color red         = Color(0xFFFF453A);
  static const Color blue        = Color(0xFF0A84FF);
  static const Color white       = Color(0xFFFFFFFF);
  static const Color grey        = Color(0xFF8E8E93);
  static const Color greyDark    = Color(0xFF48484A);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: yellow, surface: surface, error: red),
    cardTheme: CardThemeData(
      color: surface, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
  );
}
