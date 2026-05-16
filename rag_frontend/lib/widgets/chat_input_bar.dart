import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
import 'package:frontend/utils/custom_snackbar.dart';
import 'package:frontend/widgets/premium_mic.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.messageController,
    required this.inputFocusNode,
    required this.hasText,
    required this.onSend,
  });

  final TextEditingController messageController;
  final FocusNode inputFocusNode;
  final bool hasText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x99111418),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: chatProvider.isRecording
                    ? const Color(0xFFEF4444)
                    : inputFocusNode.hasFocus
                        ? const Color(0xFFFF5F1F)
                        : Colors.white24,
                width: (inputFocusNode.hasFocus || chatProvider.isRecording)
                    ? 1.6
                    : 1,
              ),
              boxShadow: [
                if (inputFocusNode.hasFocus)
                  BoxShadow(
                    color: const Color(0xFFFF5F1F).withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: 0.6,
                  ),
                if (chatProvider.isRecording)
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 0.6,
                  ),
              ],
            ),
            child: Row(
              children: [
                // ---- Left section: TextField or recording row ----
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: chatProvider.isRecording
                        // ---- Recording row ----
                        ? Row(
                            key: const ValueKey('recording_row'),
                            children: [
                              // Blinking red dot
                              _BlinkingDot(),
                              const SizedBox(width: 10),
                              const Text(
                                'Recording...',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              // Slide to cancel hint
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    size: 18,
                                  ),
                                  Text(
                                    'Slide to cancel',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        // ---- Normal TextField ----
                        : Row(
                            key: const ValueKey('text_field_row'),
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (chatProvider.isProcessingVoice) ...[
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFFFF5F1F),
                                    backgroundColor: Color(0xFF27272A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('text_field'),
                                  focusNode: inputFocusNode,
                                  controller: messageController,
                                  textInputAction: TextInputAction.send,
                                  enabled: !chatProvider.isLoading &&
                                      !chatProvider.isProcessingVoice,
                                  onSubmitted: chatProvider.isLoading
                                      ? null
                                      : (_) => onSend(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: chatProvider.isProcessingVoice
                                        ? 'Sending voice…'
                                        : 'Ask a question about your document...',
                                    filled: true,
                                    fillColor: const Color(0xFF2D2D34),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: Colors.white24),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: Colors.white24),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFFF5F1F)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // ---- Right section: Send / Mic button ----
                hasText || chatProvider.isLoading
                    // --- Send text button ---
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5F1F)
                                  .withValues(alpha: 0.34),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed:
                              chatProvider.isLoading ? null : () => onSend(),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                            backgroundColor: const Color(0xFFFF5F1F),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                          ),
                          child: chatProvider.isLoading
                              ? const SpinKitPulse(
                                  color: Colors.white,
                                  size: 18.0,
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                ),
                        ),
                      )
                    // --- Mic (hold-to-record) button ---
                    : AbsorbPointer(
                        absorbing: chatProvider.isProcessingVoice ||
                            chatProvider.isLoading,
                        child: GestureDetector(
                          onTap: () {
                            if (chatProvider.isProcessingVoice) {
                              return;
                            }
                            CustomSnackBar.showInfo(
                              context,
                              'Hold the mic button to record a voice question',
                            );
                          },
                          onLongPress: chatProvider.isProcessingVoice
                              ? null
                              : () => chatProvider.startRecording(),
                          onLongPressEnd: (_) {
                            if (chatProvider.isProcessingVoice) {
                              return;
                            }
                            chatProvider.stopRecordingAndSend();
                          },
                          onLongPressMoveUpdate: (details) {
                            if (chatProvider.isProcessingVoice) {
                              return;
                            }
                            if (details.localOffsetFromOrigin.dx < -80) {
                              chatProvider.cancelRecording();
                            }
                          },
                          onLongPressCancel: () {
                            if (chatProvider.isProcessingVoice) {
                              return;
                            }
                            chatProvider.cancelRecording();
                          },
                          child: PremiumMicButton(
                            isRecording: chatProvider.isRecording,
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

/// Pulsing scale + glow while recording (replaces static mic feedback).
class _PulsingMicShell extends StatefulWidget {
  const _PulsingMicShell({
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<_PulsingMicShell> createState() => _PulsingMicShellState();
}

class _PulsingMicShellState extends State<_PulsingMicShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingMicShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && oldWidget.active) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = math.sin(_controller.value * math.pi);
        final scale = 1.0 + 0.09 * pulse;
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444)
                      .withValues(alpha: 0.22 + 0.38 * pulse),
                  blurRadius: 12 + 22 * pulse,
                  spreadRadius: 0.5 + 1.4 * pulse,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animated blinking red dot for the recording indicator.
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
