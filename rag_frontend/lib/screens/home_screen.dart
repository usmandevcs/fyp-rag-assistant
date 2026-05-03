import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
import 'package:frontend/screens/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastShownError;

  void _showErrorIfNeeded(BuildContext context, ChatProvider chatProvider) {
    final errorMessage = chatProvider.errorMessage;
    if (errorMessage == null ||
        errorMessage.isEmpty ||
        errorMessage == _lastShownError) {
      return;
    }

    _lastShownError = errorMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  Future<void> _uploadAndOpenChat(
    BuildContext context,
    ChatProvider chatProvider,
  ) async {
    final previousSessionId = chatProvider.sessionId;
    await chatProvider.pickAndUploadFile();

    if (!context.mounted) {
      return;
    }

    final hasNewSession =
        chatProvider.sessionId != null &&
        chatProvider.sessionId != previousSessionId;
    if (!hasNewSession) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        _showErrorIfNeeded(context, chatProvider);

        final hasRecentSession =
            chatProvider.sessionId != null &&
            chatProvider.sessionId!.isNotEmpty;
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF06090D),
                          const Color(0xFF0D0D0D),
                          const Color(0xFF10161C),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withValues(alpha: 0.08),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          blurRadius: 80,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -70,
                  left: -50,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Center(
                  child: chatProvider.isLoading
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SpinKitWave(
                              color: Theme.of(context).colorScheme.primary,
                              size: 50.0,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Uploading & Processing Document...',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.9,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please wait, Jarvis is analyzing the data. This may take a few moments.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey.shade400,
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0x8010151B),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.cyanAccent.withValues(
                                    alpha: 0.42,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withValues(
                                      alpha: 0.16,
                                    ),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.cyanAccent,
                                        width: 1.5,
                                      ),
                                      color: const Color(0x66121C24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.cyanAccent.withValues(
                                            alpha: 0.22,
                                          ),
                                          blurRadius: 22,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.hub,
                                      size: 44,
                                      color: Colors.cyanAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    'JARVIS RAG CORE',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: Colors.cyanAccent,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 30,
                                    child: DefaultTextStyle(
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            letterSpacing: 0.7,
                                          ),
                                      child: AnimatedTextKit(
                                        repeatForever: true,
                                        pause: const Duration(
                                          milliseconds: 900,
                                        ),
                                        animatedTexts: [
                                          FadeAnimatedText(
                                            'Neural document intelligence online',
                                          ),
                                          FadeAnimatedText(
                                            'Upload PDF and start mission query',
                                          ),
                                          FadeAnimatedText(
                                            'Context memory locked and ready',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 26),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: chatProvider.isLoading
                                          ? null
                                          : () => _uploadAndOpenChat(
                                              context,
                                              chatProvider,
                                            ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.cyanAccent,
                                        foregroundColor: const Color(
                                          0xFF001314,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      icon: chatProvider.isLoading
                                          ? const SpinKitPulse(
                                              color: Color(0xFF001314),
                                              size: 18,
                                            )
                                          : const Icon(
                                              Icons.upload_file_rounded,
                                            ),
                                      label: const Text('Upload New PDF'),
                                    ),
                                  ),
                                  if (hasRecentSession) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openChat(context),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: Colors.cyanAccent.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                          foregroundColor: Colors.cyanAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline,
                                        ),
                                        label: const Text(
                                          'Continue Recent Chat',
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  Text(
                                    'Session intelligence is preserved locally for fast re-entry.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.72),
                                          letterSpacing: 0.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
