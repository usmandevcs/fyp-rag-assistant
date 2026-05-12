import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class ChatBubble extends StatefulWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.animate,
    this.sources,
    this.followUps,
    this.onFollowUpTap,
  });

  final String text;
  final bool isUser;
  final bool animate;
  final String? sources;
  final List<String>? followUps;
  final void Function(String)? onFollowUpTap;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  /// Tracks whether the initial streaming animation has already played.
  /// Once true, subsequent rebuilds (e.g. summary dashboard appearing)
  /// will render full static text instead of re-triggering the typewriter.
  bool _hasAnimated = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isUser
        ? const Color(0xFF1A1A1A)
        : Colors.transparent;
    final textColor = widget.isUser ? Colors.white : const Color(0xFFA78BFA);
    final alignment = widget.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(widget.isUser ? 20 : 6),
      bottomRight: Radius.circular(widget.isUser ? 6 : 20),
    );

    final hasSources = !widget.isUser &&
        widget.sources != null &&
        widget.sources!.trim().isNotEmpty;
    
    final hasFollowUps = !widget.isUser && 
        widget.followUps != null && 
        widget.followUps!.isNotEmpty;

    // Determine whether the typewriter animation should play this build.
    // It should only play once — when `animate` is first true and we haven't
    // animated yet. After it finishes (or if it already played), show static text.
    final shouldAnimate = widget.animate && !_hasAnimated && !widget.isUser;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Message text ---
              widget.isUser
                  ? Text(
                      widget.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        height: 1.35,
                      ),
                    )
                  : shouldAnimate
                      ? AnimatedTextKit(
                          key: ValueKey<String>(widget.text),
                          isRepeatingAnimation: false,
                          totalRepeatCount: 1,
                          onFinished: () {
                            // Mark as animated so future rebuilds skip the animation.
                            if (mounted) {
                              setState(() => _hasAnimated = true);
                            }
                          },
                          animatedTexts: [
                            TypewriterAnimatedText(
                              widget.text,
                              speed: const Duration(milliseconds: 18),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFFA78BFA),
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        )
                      : Text(
                          widget.text,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFA78BFA),
                                height: 1.35,
                              ),
                        ),

              // --- Citation chips ---
              if (hasSources) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 12,
                            color:
                                const Color(0xFFA78BFA).withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'SOURCES',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: const Color(0xFFA78BFA)
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: _buildSourceChips(widget.sources!),
                      ),
                    ],
                  ),
                ),
                // ),
              ],

              // --- Follow-Up Questions ---
              if (hasFollowUps) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 14,
                          color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SUGGESTED FOLLOW-UPS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFF22C55E).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.followUps!.map((q) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.onFollowUpTap?.call(q),
                            borderRadius: BorderRadius.circular(16),
                            hoverColor: const Color(0xFF22C55E).withValues(alpha: 0.1),
                            splashColor: const Color(0xFF22C55E).withValues(alpha: 0.2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      q,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF22C55E),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 10,
                                    color: Color(0xFF22C55E),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSourceChips(String sourcesString) {
    final items = sourcesString
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return items.map((label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFA78BFA).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFA78BFA).withValues(alpha: 0.25),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA78BFA).withValues(alpha: 0.06),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 11,
              color: const Color(0xFFA78BFA).withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA78BFA),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
