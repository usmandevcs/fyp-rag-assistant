import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/chat_message.dart';
import '../providers/chat_provider.dart';

class ChatBubble extends StatefulWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.animate,
    this.message,
    this.sources,
    this.followUps,
    this.onFollowUpTap,
    this.onAssistantAnimationFinished,
  });

  final String text;
  final bool isUser;
  final bool animate;
  /// When set for assistant messages, [isAnimationFinished] controls typewriter vs static markdown.
  final ChatMessage? message;
  final String? sources;
  final List<String>? followUps;
  final void Function(String)? onFollowUpTap;
  final void Function(ChatMessage message)? onAssistantAnimationFinished;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isUser
        ? Colors.transparent
        : const Color(0xFF2D2D34);
    final border = widget.isUser
        ? Border.all(color: const Color(0xFFFF5F1F), width: 1.5)
        : null;
    final textColor = Colors.white;
    final alignment = widget.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.circular(16);
    final screenWidth = MediaQuery.sizeOf(context).width;

    final hasSources = !widget.isUser &&
        widget.sources != null &&
        widget.sources!.trim().isNotEmpty;
    
    final hasFollowUps = !widget.isUser && 
        widget.followUps != null && 
        widget.followUps!.isNotEmpty;

    final animationFinished = widget.message?.isAnimationFinished ?? false;
    final useTypewriter =
        !widget.isUser && !animationFinished && widget.animate;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth < 600 ? screenWidth * 0.85 : screenWidth * 0.65,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: border,
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
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Message content (animated or static)
                        Expanded(
                          child: animationFinished
                              ? _buildAssistantMarkdown(context)
                              : useTypewriter
                                  ? AnimatedTextKit(
                                      key: ValueKey<String>(widget.text),
                                      isRepeatingAnimation: false,
                                      totalRepeatCount: 1,
                                      onFinished: () {
                                        final m = widget.message;
                                        if (m != null) {
                                          widget.onAssistantAnimationFinished
                                              ?.call(m);
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
                                                color: Colors.white70,
                                                height: 1.35,
                                              ),
                                        ),
                                      ],
                                    )
                                  : _buildAssistantMarkdown(context),
                        ),

                        // Pin button for AI messages
                        Consumer<ChatProvider>(
                          builder: (context, provider, _) {
                            final isPinned = provider.pinnedMessages.contains(widget.text);
                            return IconButton(
                              padding: const EdgeInsets.only(left: 8),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                size: 18,
                                color: isPinned
                                    ? const Color(0xFFFF5F1F)
                                    : const Color(0xFFFF5F1F).withValues(alpha: 0.6),
                              ),
                              onPressed: () => provider.togglePinMessage(widget.text),
                              tooltip: isPinned ? 'Unpin message' : 'Pin message',
                            );
                          },
                        ),
                      ],
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
                      color: const Color(0xFFFF5F1F).withValues(alpha: 0.18),
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
                                const Color(0xFFFF5F1F).withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'SOURCES',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: const Color(0xFFFF5F1F)
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
                          color: const Color(0xFFFF5F1F).withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SUGGESTED FOLLOW-UPS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFFFF5F1F).withValues(alpha: 0.7),
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
                            hoverColor: const Color(0xFFFF5F1F).withValues(alpha: 0.1),
                            splashColor: const Color(0xFFFF5F1F).withValues(alpha: 0.2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5F1F).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFF5F1F).withValues(alpha: 0.3),
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
                                        color: Color(0xFFFF5F1F),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 10,
                                    color: Color(0xFFFF5F1F),
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

  Widget _buildAssistantMarkdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: widget.text,
          styleSheet: MarkdownStyleSheet(
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.35,
                ),
            h1: const TextStyle(
              color: Color(0xFFFF5F1F),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            h2: const TextStyle(
              color: Color(0xFFFF5F1F),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            h3: const TextStyle(
              color: Color(0xFFFF5F1F),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            em: const TextStyle(
              color: Color(0xFFFF5F1F),
              fontStyle: FontStyle.italic,
            ),
            strong: const TextStyle(
              color: Color(0xFFFF5F1F),
              fontWeight: FontWeight.bold,
            ),
            listBullet: const TextStyle(
              color: Color(0xFFFF5F1F),
            ),
            tableBody: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            tableHead: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tableBorder: TableBorder.all(
              color: const Color(0xFFFF5F1F).withValues(alpha: 0.5),
              width: 1,
            ),
            tableColumnWidth: const IntrinsicColumnWidth(),
            tableCellsDecoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: const Color(0xFFFF5F1F).withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            tableHeadAlign: TextAlign.center,
          ),
          onTapLink: (text, href, title) {},
        ),
        if (widget.message?.chartData != null && widget.message!.chartData!.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: widget.message!.chartData!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value as Map<String, dynamic>;
                  final val = (data['value'] as num).toDouble();
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: const Color(0xFFFF5F1F),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < widget.message!.chartData!.length) {
                          final label = widget.message!.chartData![index]['label']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
        ],
      ],
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
          color: const Color(0xFFFF5F1F).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFFF5F1F).withValues(alpha: 0.25),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5F1F).withValues(alpha: 0.06),
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
              color: const Color(0xFFFF5F1F).withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF5F1F),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
