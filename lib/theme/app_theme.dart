import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFFFF6081);
  static const Color secondary = Color(0xFFFFA9B9);
  static const Color surface = Color(0xFFFDF2F5);
  static const Color scaffold = Color(0xFFF9F8FB);
  static const Color textPrimary = Color(0xFF14181B);
  static const Color textMuted = Color(0xFF8A8D92);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      scaffoldBackgroundColor: scaffold,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineMedium: GoogleFonts.interTight(
          fontWeight: FontWeight.w600,
          fontSize: 24,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.interTight(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          color: textPrimary,
        ),
        labelLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.interTight(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.interTight(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: secondary,
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
      ),
    );
  }
}


