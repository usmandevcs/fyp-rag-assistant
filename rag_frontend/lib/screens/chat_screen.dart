import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
import 'package:frontend/widgets/history_sidebar.dart';
import 'package:frontend/widgets/chat_bubble.dart';
import 'package:frontend/utils/summary_download.dart';
import 'package:frontend/utils/custom_snackbar.dart';

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
                                                'Upload a PDF to initialize chat context',
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
                Padding(
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
                            : _inputFocusNode.hasFocus
                                ? const Color(0xFFFF5F1F)
                                : Colors.white24,
                        width: (_inputFocusNode.hasFocus ||
                                chatProvider.isRecording)
                            ? 1.6
                            : 1,
                      ),
                      boxShadow: [
                        if (_inputFocusNode.hasFocus)
                          BoxShadow(
                            color: const Color(
                              0xFFFF5F1F,
                            ).withValues(alpha: 0.28),
                            blurRadius: 18,
                            spreadRadius: 0.6,
                          ),
                        if (chatProvider.isRecording)
                          BoxShadow(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.25),
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
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            size: 18,
                                          ),
                                          Text(
                                            'Slide to cancel',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.4),
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
                                          focusNode: _inputFocusNode,
                                          controller: _messageController,
                                          textInputAction: TextInputAction.send,
                                          enabled: !chatProvider.isLoading &&
                                              !chatProvider.isProcessingVoice,
                                          onSubmitted: chatProvider.isLoading
                                              ? null
                                              : (_) =>
                                                  _sendMessage(chatProvider),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: chatProvider
                                                    .isProcessingVoice
                                                ? 'Sending voice…'
                                                : 'Ask a question about your PDF...',
                                            filled: true,
                                            fillColor: const Color(0xFF2D2D34),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Colors.white24),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Colors.white24),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFFFF5F1F)),
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
                        _hasText || chatProvider.isLoading
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
                                  onPressed: chatProvider.isLoading
                                      ? null
                                      : () =>
                                          _sendMessage(chatProvider),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.all(14),
                                    backgroundColor:
                                        const Color(0xFFFF5F1F),
                                    foregroundColor:
                                        Colors.white,
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
                                    if (details.localOffsetFromOrigin.dx <
                                        -80) {
                                      chatProvider.cancelRecording();
                                    }
                                  },
                                  onLongPressCancel: () {
                                    if (chatProvider.isProcessingVoice) {
                                      return;
                                    }
                                    chatProvider.cancelRecording();
                                  },
                                  child: _PulsingMicShell(
                                    active: chatProvider.isRecording,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: EdgeInsets.all(
                                        chatProvider.isRecording
                                            ? 18
                                            : 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: chatProvider.isRecording
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFFF5F1F),
                                        shape: BoxShape.circle,
                                        boxShadow: chatProvider.isRecording
                                            ? const <BoxShadow>[]
                                            : [
                                                BoxShadow(
                                                  color: const Color(0xFFFF5F1F)
                                                      .withValues(alpha: 0.34),
                                                  blurRadius: 16,
                                                ),
                                              ],
                                      ),
                                      child: chatProvider.isProcessingVoice
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                                backgroundColor:
                                                    Color(0x33FFFFFF),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.mic_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                      ],
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

  // -------------------------------------------------------
  // Interactive Summary Dashboard widget
  // -------------------------------------------------------

  Widget _buildInteractiveSummary(Map<String, dynamic> summaryData) {
    const neonOrange = Color(0xFFFF5F1F);
    const cardBg = Color(0xFF2D2D34);
    const borderColor = Color(0xFF3F3F46);

    final sections = <_SummarySection>[
      _SummarySection(
        icon: Icons.dashboard_outlined,
        title: 'Overview',
        content: summaryData['overview']?.toString() ?? '',
        isExpandedByDefault: true,
      ),
      _SummarySection(
        icon: Icons.lightbulb_outline,
        title: 'Key Findings',
        items: _parseListField(summaryData['key_findings']),
      ),
      _SummarySection(
        icon: Icons.analytics_outlined,
        title: 'Critical Data Points',
        items: _parseListField(summaryData['critical_data_points']),
      ),
      _SummarySection(
        icon: Icons.flag_outlined,
        title: 'Conclusion',
        content: summaryData['conclusion']?.toString() ?? '',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: neonOrange.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: neonOrange.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: neonOrange.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: neonOrange.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: neonOrange, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'INTERACTIVE SUMMARY DASHBOARD',
                      style: TextStyle(
                        color: neonOrange,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    tooltip: 'Dismiss summary',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      context.read<ChatProvider>().dismissSummary();
                    },
                  ),
                ],
              ),
            ),
            // Sections
            ...sections.map((section) {
              return Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded:
                      section.isExpandedByDefault,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 2,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    14,
                  ),
                  collapsedIconColor:
                      neonOrange.withValues(alpha: 0.6),
                  iconColor: neonOrange,
                  shape: Border(
                    bottom: BorderSide(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  collapsedShape: Border(
                    bottom: BorderSide(
                      color: borderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  leading: Icon(
                    section.icon,
                    color: neonOrange,
                    size: 20,
                  ),
                  title: Text(
                    section.title,
                    style: const TextStyle(
                      color: neonOrange,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  children: [
                    if (section.content != null &&
                        section.content!.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          section.content!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.6,
                          ),
                        ),
                      ),
                    if (section.items != null)
                      ...section.items!.map(
                        (item) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 6),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: neonOrange
                                        .withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            // Download Button at the bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadSummary(context.read<ChatProvider>()),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download PDF/Markdown'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: neonOrange.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _parseListField(dynamic field) {
    if (field is List) {
      return field.map((e) => e.toString()).toList();
    }
    return <String>[];
  }
}

/// Helper data class for summary sections.
class _SummarySection {
  const _SummarySection({
    required this.icon,
    required this.title,
    this.content,
    this.items,
    this.isExpandedByDefault = false,
  });

  final IconData icon;
  final String title;
  final String? content;
  final List<String>? items;
  final bool isExpandedByDefault;
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
