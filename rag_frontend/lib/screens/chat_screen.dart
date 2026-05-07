import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
import 'package:frontend/widgets/history_sidebar.dart';
import 'package:frontend/widgets/chat_bubble.dart';
import 'package:frontend/utils/summary_download.dart';

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
    final summaryPrompt =
        'Act as an expert data analyst. Please read the provided document context and generate a comprehensive, well-structured summary. Highlight the main topics, key arguments, and critical conclusions. Use Markdown formatting (bullet points, bold text) for clarity.';
    await chatProvider.sendMessage(summaryPrompt, isSummaryRequest: true);
    _scrollToBottom();
  }

  Future<void> _downloadSummary(ChatProvider chatProvider) async {
    final summary = chatProvider.generatedSummaryText;
    if (summary == null || summary.trim().isEmpty) {
      return;
    }

    try {
      await downloadSummaryMarkdown(
        markdown: summary,
        fileName: 'vesper_summary.md',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to download summary: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        _maybeShowError(context, chatProvider);

        final hasSession =
            chatProvider.sessionId != null &&
            chatProvider.sessionId!.isNotEmpty;
        final messages = chatProvider.messages;
        final reversedMessages = messages.reversed.toList();
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          drawer: const HistorySidebar(),
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.memory_outlined,
                  color: Color(0xFFA78BFA),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    chatProvider.filename ?? 'VESPER CHAT',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFA78BFA),
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
                color: const Color(0xFFA78BFA).withValues(alpha: 0.24),
              ),
            ),
            actions: [
              if (chatProvider.generatedSummaryText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: chatProvider.isLoading
                        ? null
                        : () => _downloadSummary(chatProvider),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A0A0A),
                      foregroundColor: const Color(0xFFA78BFA),
                      side: const BorderSide(
                        color: Color(0xFF27272A),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text(
                      'Download Summary',
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
                child: OutlinedButton.icon(
                  onPressed: chatProvider.isLoading
                      ? null
                      : () => _requestSummary(chatProvider),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A0A0A),
                    foregroundColor: const Color(0xFFA78BFA),
                    side: const BorderSide(
                      color: Color(0xFF27272A),
                      width: 1,
                    ),
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
                child: OutlinedButton.icon(
                  onPressed: chatProvider.isLoading
                      ? null
                      : () => _uploadFile(chatProvider),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A0A0A),
                    foregroundColor: const Color(0xFFA78BFA),
                    side: const BorderSide(
                      color: Color(0xFF27272A),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text(
                    'Upload PDF',
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
                          itemCount:
                              reversedMessages.length +
                              (chatProvider.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
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
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SpinKitPulse(
                                            color: Color(0xFFA78BFA),
                                            size: 24.0,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Thinking...',
                                            style: TextStyle(
                                              color: Color(0xFFA78BFA),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final messageIndex = chatProvider.isLoading
                                ? index - 1
                                : index;
                            final message = reversedMessages[messageIndex];
                            return ChatBubble(
                              text: message['text'] ?? '',
                              isUser: message['role'] == 'user',
                              animate: messageIndex == 0,
                            );
                          },
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 480),
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: const Color(0x6610161D),
                                borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                color: const Color(0xFFA78BFA).withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFA78BFA).withValues(
                                    alpha: 0.15,
                                    ),
                                    blurRadius: 24,
                                    spreadRadius: 0.6,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.radar_rounded,
                                    size: 64,
                                    color: Color(0xFFA78BFA),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No Active Document Session',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFFA78BFA),
                                          letterSpacing: 0.8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 22,
                                    child: DefaultTextStyle(
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                      child: AnimatedTextKit(
                                        repeatForever: true,
                                        pause: const Duration(
                                          milliseconds: 900,
                                        ),
                                        animatedTexts: [
                                          FadeAnimatedText(
                                            'Upload a PDF to initialize chat context',
                                          ),
                                          FadeAnimatedText(
                                            'Then ask targeted questions from your files',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Use the upload control in the top-right corner.',
                                    textAlign: TextAlign.center,
                                          style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x99111418),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _inputFocusNode.hasFocus
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFFA78BFA).withValues(alpha: 0.34),
                        width: _inputFocusNode.hasFocus ? 1.6 : 1,
                      ),
                      boxShadow: [
                        if (_inputFocusNode.hasFocus)
                          BoxShadow(
                            color: const Color(0xFFA78BFA).withValues(alpha: 0.28),
                            blurRadius: 18,
                            spreadRadius: 0.6,
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _inputFocusNode,
                            controller: _messageController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: chatProvider.isLoading
                                ? null
                                : (_) => _sendMessage(chatProvider),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Ask a question about your PDF...',
                              filled: true,
                              fillColor: Color(0x66161A20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA78BFA).withValues(
                                  alpha: 0.34,
                                ),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: chatProvider.isLoading
                                ? null
                                : () => _sendMessage(chatProvider),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.all(14),
                              backgroundColor: const Color(0xFFA78BFA),
                              foregroundColor: const Color(0xFF001314),
                              shape: const CircleBorder(),
                            ),
                            child: chatProvider.isLoading
                                ? const SpinKitPulse(
                                    color: Color(0xFF001314),
                                    size: 18.0,
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
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
}
