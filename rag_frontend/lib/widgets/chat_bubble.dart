import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.animate,
  });

  final String text;
  final bool isUser;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isUser
        ? const Color(0xFF1A1A1A)
        : Colors.transparent;
    final textColor = isUser ? Colors.white : const Color(0xFFA78BFA);
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 20),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
          ),
          child: isUser
              ? Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.35,
                  ),
                )
              : animate
                  ? AnimatedTextKit(
                      key: ValueKey<String>(text),
                      isRepeatingAnimation: false,
                      totalRepeatCount: 1,
                      animatedTexts: [
                        TypewriterAnimatedText(
                          text,
                          speed: const Duration(milliseconds: 18),
                          textStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFA78BFA), height: 1.35),
                        ),
                      ],
                    )
                  : Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFA78BFA),
                        height: 1.35,
                      ),
                    ),
        ),
      ),
    );
  }
}
