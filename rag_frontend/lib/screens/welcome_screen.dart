import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:frontend/screens/home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Color _backgroundColor = Color(0xFF0A0A0A);
  static const Color _accentColor = Color(0xFFA78BFA);

  @override
  void initState() {
    super.initState();
    _goToHome();
  }

  Future<void> _goToHome() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VESPER CORE',
              style: TextStyle(
                color: _accentColor,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 16),
            SpinKitPulse(
              color: _accentColor,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
