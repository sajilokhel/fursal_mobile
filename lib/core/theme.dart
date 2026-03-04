import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors mapped from `themes/default/variables.css`
  // Light mode
  static const Color accent = Color(0xFFEF5F15);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color foregroundLight = Color(0xFF0F172A);
  static const Color mutedLight = Color(0xFF475569);
  static const Color borderLight =
      Color(0x0F172A0F); // fallback; use opacity when needed
  static const Color shadowLight = Color(0x15020617);

  // Backwards-compatible aliases (used throughout the codebase)
  static const Color primaryColor = accent;
  static const Color primaryDark = Color(0xFF172554);
  static const Color secondaryColor = accent;
  static const Color backgroundColor = backgroundLight;
  static const Color surfaceColor = surfaceLight;
  static const Color errorColor = Color(0xFFEF4444);
  static const Color textPrimary = foregroundLight;
  static const Color textSecondary = mutedLight;

  // Dark mode
  static const Color backgroundDark = Color(0xFF071028);
  static const Color surfaceDark = Color(0xFF071028);
  static const Color foregroundDark = Color(0xFFE6EEF8);
  static const Color mutedDark = Color(0xFF93A7BF);
  static const Color accentDark = Color(0xFFFFB37A);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  static ThemeData get lightTheme {
    const textPrimary = foregroundLight;
    const textSecondary = mutedLight;

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surfaceLight,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
            color: textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: GoogleFonts.inter(
            color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
        displaySmall: GoogleFonts.inter(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 24),
        headlineMedium: GoogleFonts.inter(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: GoogleFonts.inter(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: danger)),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
    );
  }

  // Dark theme removed: app uses light-only theme per project request.
}
