import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/utils/custom_snackbar.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Color _backgroundColor = Color(0xFF1A1A1D);
  static const Color _accentColor = Color(0xFFFF5F1F);

  @override
  void initState() {
    super.initState();
    _goToHome();
  }

  Future<void> _goToHome() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (e, st) {
      debugPrint('WelcomeScreen navigation failed: $e\n$st');
      if (mounted) {
        CustomSnackBar.showError(context, 'Could not open home: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final titleSize = isMobile ? 20.0 : 28.0;
    final letterSpacing = isMobile ? 1.6 : 4.0;
    final horizontalPad = isMobile ? 20.0 : 32.0;
    final spinnerSize = isMobile ? 12.0 : 14.0;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPad,
              vertical: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'VESPER CORE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: letterSpacing,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                SpinKitPulse(
                  color: _accentColor,
                  size: spinnerSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
