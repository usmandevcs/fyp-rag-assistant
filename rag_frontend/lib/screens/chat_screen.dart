// import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
import 'package:frontend/widgets/history_sidebar.dart';
import 'package:frontend/widgets/chat_bubble.dart';
import 'package:frontend/utils/summary_download.dart';
import 'package:frontend/utils/custom_snackbar.dart';

import 'package:frontend/widgets/summary_dashboard.dart';
import 'package:frontend/widgets/chat_input_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  String? _lastShownError;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(ChatProvider chatProvider) async {
    final text = _messageController.text;
    if (text.trim().isEmpty) {
      return;
    }

    _messageController.clear();

    await chatProvider.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _uploadFile(ChatProvider chatProvider) async {
    await chatProvider.pickAndUploadFile();
    _scrollToBottom();
  }

  Future<void> _requestSummary(ChatProvider chatProvider) async {
    await chatProvider.requestStructuredSummary();
    _scrollToBottom();
  }

  Future<void> _downloadSummary(ChatProvider chatProvider) async {
    final summaryMap = chatProvider.structuredSummary;
    if (summaryMap == null || summaryMap.isEmpty) {
      return;
    }

    // Format the structured summary Map into clean Markdown.
    final buffer = StringBuffer();
    buffer.writeln('# Vesper Document Summary');
    buffer.writeln();

    for (final entry in summaryMap.entries) {
      // Convert snake_case / camelCase keys to Title Case headings.
      final heading = entry.key
          .replaceAll('_', ' ')
          .replaceAllMapped(
            RegExp(r'(^|\s)\w'),
            (m) => m.group(0)!.toUpperCase(),
          );

      buffer.writeln('## $heading');
      buffer.writeln();

      final value = entry.value;
      if (value is List) {
        for (final item in value) {
          buffer.writeln('- $item');
        }
      } else {
        buffer.writeln(value.toString());
      }
      buffer.writeln();
    }

    final markdown = buffer.toString();

    try {
      await downloadSummaryMarkdown(
        markdown: markdown,
        fileName: 'vesper_summary.md',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            duration: const Duration(seconds: 3),
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D34),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF5F1F),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5F1F).withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5F1F).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFFFF5F1F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Summary downloaded successfully!',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      CustomSnackBar.showError(context, 'Failed to download summary: $error');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _maybeShowError(BuildContext context, ChatProvider chatProvider) {
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

      CustomSnackBar.showError(context, errorMessage);
    });
  }

  Widget _buildApiStatusChip(ChatProvider chatProvider) {
    final status = chatProvider.apiStatus;
    if (status == null) {
      return const SizedBox.shrink();
    }

    final usagePercent = status['groq_usage_percent'] as int? ?? 0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    Color statusColor;
    if (usagePercent < 70) {
      statusColor = const Color(0xFF22C55E); // Green
    } else if (usagePercent <= 90) {
      statusColor = const Color(0xFFEAB308); // Yellow
    } else {
      statusColor = const Color(0xFFEF4444); // Red
    }

    const double ringSize = 34;
    final progress = (usagePercent.clamp(0, 100)) / 100.0;

    final ringWithPercent = SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircularProgressIndicator(
                value: progress,
                backgroundColor: statusColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                strokeWidth: 2.5,
              ),
            ),
          ),
          Text(
            '$usagePercent%',
            style: TextStyle(
              color: const Color(0xFFE5E7EB),
              fontSize: isMobile ? 8.5 : 9.5,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Groq API Usage: $usagePercent%',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF27272A),
              width: 1,
            ),
          ),
          child: isMobile
              ? ringWithPercent
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ringWithPercent,
                    const SizedBox(width: 8),
                    const Text(
                      'API Health',
                      style: TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _maybeShowReadyPopup(BuildContext context, ChatProvider chatProvider) {
    if (!chatProvider.consumeReadyPopup()) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            duration: const Duration(seconds: 4),
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D34),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF5F1F),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5F1F).withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5F1F).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFF5F1F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Done! Text and Visuals/Graphs processed successfully. You can now ask questions.',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        _maybeShowError(context, chatProvider);
        _maybeShowReadyPopup(context, chatProvider);

        final hasSession =
            chatProvider.sessionId != null &&
            chatProvider.sessionId!.isNotEmpty;
        final messages = chatProvider.messages;
        final reversedMessages = messages.reversed.toList();
        final colorScheme = Theme.of(context).colorScheme;
        final isMobileSidebar = MediaQuery.sizeOf(context).width < 600;

        return Scaffold(
          drawer: const HistorySidebar(),
          appBar: AppBar(
            leading: isMobileSidebar
                ? Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: 'History',
                    ),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  chatProvider.isMultiDocMode
                      ? Icons.layers_outlined
                      : Icons.memory_outlined,
                  color: const Color(0xFFFF5F1F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    chatProvider.isMultiDocMode
                        ? 'Multi-Doc Mode (${chatProvider.selectedSessionIds.length} selected)'
                        : chatProvider.filename ?? 'VESPER CHAT',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFF5F1F),
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: const Color(0xFFFF5F1F).withValues(alpha: 0.24),
              ),
            ),
            actions: [
              _buildApiStatusChip(chatProvider),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: chatProvider.isLoading
                      ? null
                      : () => _requestSummary(chatProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5F1F),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    'Auto Summary',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: chatProvider.isLoading
                      ? null
                      : () => _uploadFile(chatProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5F1F),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text(
                    'Upload File',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: hasSession
                      ? ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: () {
                            int count = reversedMessages.length;
                            if (chatProvider.isLoading) count += 1;
                            if (chatProvider.structuredSummary != null) count += 1;
                            return count;
                          }(),
                          itemBuilder: (context, index) {
                            // --- Loading indicator (always at top = index 0 in reversed list) ---
                            if (chatProvider.isLoading && index == 0) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  8,
                                  24,
                                  16,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SpinKitPulse(
                                            color: Color(0xFFFF5F1F),
                                            size: 24.0,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            chatProvider.loadingType ==
                                                    LoadingType.summary
                                                ? 'Generating Summary...'
                                                : 'Thinking...',
                                            style: const TextStyle(
                                              color: Color(0xFFFF5F1F),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Adjust index after loading indicator
                            int adjustedIndex =
                                chatProvider.isLoading ? index - 1 : index;

                            // --- Structured Summary Dashboard (after loading, before messages) ---
                            if (chatProvider.structuredSummary != null &&
                                adjustedIndex == 0) {
                              return _buildInteractiveSummary(
                                chatProvider.structuredSummary!,
                              );
                            }

                            // Adjust for the summary card
                            final messageIndex =
                                chatProvider.structuredSummary != null
                                    ? adjustedIndex - 1
                                    : adjustedIndex;

                            final message = reversedMessages[messageIndex];
                            final followUps = message.followUps ?? <String>[];

                            return Column(
                              crossAxisAlignment: message.role == 'user' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                ChatBubble(
                                  message: message,
                                  text: message.text,
                                  isUser: message.role == 'user',
                                  animate: messageIndex == 0 && message.role != 'user',
                                  sources: message.sources,
                                  onAssistantAnimationFinished: (m) =>
                                      chatProvider.markMessageAnimationFinished(m),
                                ),
                                if (message.role != 'user' && followUps.isNotEmpty && messageIndex == 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12.0, bottom: 8.0, top: 4.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: followUps.map((q) => Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: ActionChip(
                                            label: Text(
                                              q,
                                              style: const TextStyle(
                                                color:  Color(0xFFFF5F1F),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                            backgroundColor: Colors.transparent,
                                            shape: StadiumBorder(
                                              side: BorderSide(
                                                color: const Color(0xFFFF5F1F).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            onPressed: () {
                                              _messageController.text = q;
                                              
                                              // Immediately hide the follow ups for this response from UI
                                              // Removing it from provider's model
                                              // We'll safely update the _messages in a localized way or we can just call sendMessage 
                                              // Since sendMessage triggers a new query, the current one will no longer be messageIndex == 0.
                                              
                                              _sendMessage(chatProvider);
                                            },
                                          ),
                                        )).toList(),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final w = MediaQuery.sizeOf(context).width;
                            final isMobile = w < 600;
                            final outerPad = isMobile ? 12.0 : 24.0;
                            final innerPad = isMobile ? 16.0 : 22.0;
                            final iconSize = isMobile ? 48.0 : 64.0;
                            final titleStyle = Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: const Color(0xFFFF5F1F),
                                      letterSpacing: isMobile ? 0.4 : 0.8,
                                      fontWeight: FontWeight.w700,
                                      fontSize: isMobile ? 16 : null,
                                    ) ??
                                const TextStyle(
                                  color:  Color(0xFFFF5F1F),
                                  fontWeight: FontWeight.w700,
                                );
                            final bodyStyle = Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: isMobile ? 13 : null,
                                  height: 1.35,
                                );
                            final hintStyle = Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontSize: isMobile ? 11.5 : null,
                                );

                            return Center(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(outerPad),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isMobile ? w - outerPad * 2 : 480,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(innerPad),
                                    decoration: BoxDecoration(
                                      color: const Color(0x6610161D),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFFF5F1F,
                                        ).withValues(alpha: 0.4),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFFF5F1F,
                                          ).withValues(alpha: 0.15),
                                          blurRadius: isMobile ? 16 : 24,
                                          spreadRadius: 0.6,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.radar_rounded,
                                          size: iconSize,
                                          color: const Color(0xFFFF5F1F),
                                        ),
                                        SizedBox(height: isMobile ? 10 : 14),
                                        Text(
                                          'No Active Document Session',
                                          textAlign: TextAlign.center,
                                          style: titleStyle,
                                        ),
                                        SizedBox(height: isMobile ? 8 : 10),
                                        DefaultTextStyle(
                                          style: bodyStyle ??
                                              const TextStyle(
                                                color: Colors.white,
                                              ),
                                          textAlign: TextAlign.center,
                                          child: AnimatedTextKit(
                                            repeatForever: true,
                                            pause: const Duration(
                                              milliseconds: 900,
                                            ),
                                            animatedTexts: [
                                              FadeAnimatedText(
                                                'Upload a document to initialize chat context',
                                                textAlign: TextAlign.center,
                                              ),
                                              FadeAnimatedText(
                                                'Then ask targeted questions from your files',
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: isMobile ? 6 : 8),
                                        Text(
                                          'Use the upload control in the top-right corner.',
                                          textAlign: TextAlign.center,
                                          style: hintStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // --- Input area ---
                ChatInputBar(
                  messageController: _messageController,
                  inputFocusNode: _inputFocusNode,
                  hasText: _hasText,
                  onSend: () => _sendMessage(context.read<ChatProvider>()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------
  // Interactive Summary Dashboard widget
  // -------------------------------------------------------

  Widget _buildInteractiveSummary(dynamic summaryData) {
    return SummaryDashboardWidget(
      summaryData: summaryData as Map<String, dynamic>,
      onDownload: () => _downloadSummary(context.read<ChatProvider>()),
      onDismiss: () => context.read<ChatProvider>().dismissSummary(),
    );
  }

}
