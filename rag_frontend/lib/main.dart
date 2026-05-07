import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/providers/chat_provider.dart';
// import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/welcome_screen.dart';

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
        theme: AppTheme.darkVesperTheme,
        themeMode: ThemeMode.dark,
        home: const WelcomeScreen(),
      ),
    );
  }
}
