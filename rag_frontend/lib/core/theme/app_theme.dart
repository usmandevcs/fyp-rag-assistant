import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get darkVesperTheme {
    // Softer, more professional palette
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF6366F1), // soft indigo
          surface: const Color(0xFF1E293B), // slate surface
          onSurface: Colors.white,
          onPrimary: Colors.white,
          outlineVariant: const Color(0xFF6366F1).withValues(alpha: 0.12),
        );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(bodyColor: Colors.white, displayColor: const Color(0xFF6366F1));

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: const Color(0xFF101010),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
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
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
