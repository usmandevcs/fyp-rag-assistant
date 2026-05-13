import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get darkVesperTheme {
    // Deep Graphite and Neon Orange aesthetic
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5F1F),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFFFF5F1F), // Neon Orange
          secondary: const Color(0xFFFF5F1F),
          surface: const Color(0xFF242427), // slightly lighter graphite for surface
          onSurface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          outlineVariant: const Color(0xFFFF5F1F).withValues(alpha: 0.2),
        );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white70);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF1A1A1D), // Deep Graphite
      primaryColor: const Color(0xFFFF5F1F),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: const Color(0xFF1A1A1D),
        foregroundColor: Colors.white70,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF242427),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5F1F), width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF5F1F),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
