import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/providers/chat_provider.dart';
// import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/welcome_screen.dart';

const Color _deepGraphite = Color(0xFF1A1A1D);
const Color _neonOrange = Color(0xFFFF5F1F);

/// Graphite + neon orange palette; color-only overrides on [AppTheme.darkVesperTheme].
ThemeData _graphiteNeonOrangeTheme(ThemeData base) {
  return base.copyWith(
    scaffoldBackgroundColor: _deepGraphite,
    primaryColor: _neonOrange,
    colorScheme: base.colorScheme.copyWith(
      primary: _neonOrange,
      secondary: _neonOrange,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white70,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: _deepGraphite,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white70,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _neonOrange,
        foregroundColor: Colors.white,
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: const Color(0xFF2D2D34),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _neonOrange, width: 1),
      ),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
  );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>(
      create: (_) {
        final provider = ChatProvider();
        unawaited(provider.init());
        return provider;
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VESPER AI',
        theme: _graphiteNeonOrangeTheme(AppTheme.darkVesperTheme),
        themeMode: ThemeMode.dark,
        home: const WelcomeScreen(),
      ),
    );
  }
}
