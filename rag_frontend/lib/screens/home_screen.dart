import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
import 'package:frontend/screens/chat_screen.dart';
import 'package:frontend/utils/custom_snackbar.dart';
import 'package:frontend/widgets/history_sidebar.dart';

const Color _vesperBlack = Color(0xFF1A1A1D);
const Color _vesperSurface = Color(0xFF2D2D34);
const Color _vesperCyan = Color(0xFFFF5F1F);
const Color _vesperBorder = Colors.white12;
const Color _vesperTextMuted = Color(0xFFA1A1AA);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastShownError;

  late final TextEditingController _urlController;
  late final TextEditingController _textTitleController;
  late final TextEditingController _textContentController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController()..addListener(_onFieldsChanged);
    _textTitleController = TextEditingController()..addListener(_onFieldsChanged);
    _textContentController = TextEditingController()..addListener(_onFieldsChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onFieldsChanged);
    _textTitleController.removeListener(_onFieldsChanged);
    _textContentController.removeListener(_onFieldsChanged);
    _urlController.dispose();
    _textTitleController.dispose();
    _textContentController.dispose();
    super.dispose();
  }

  void _onFieldsChanged() => setState(() {});

  void _maybeShowError(BuildContext context, ChatProvider chatProvider) {
    final error = chatProvider.errorMessage;
    if (error == null || error.isEmpty || error == _lastShownError) return;
    _lastShownError = error;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CustomSnackBar.showError(context, error);
    });
  }

  Future<void> _uploadAndOpenChat(BuildContext context, ChatProvider chatProvider) async {
    await chatProvider.pickAndUploadFile();
    if (!context.mounted) return;
    if (chatProvider.sessionId != null && chatProvider.sessionId!.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
    }
  }

  void _openChat(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        _maybeShowError(context, chatProvider);

        final hasRecentSession = chatProvider.sessionId != null && chatProvider.sessionId!.isNotEmpty;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: _vesperBlack,
            appBar: AppBar(
              backgroundColor: _vesperBlack,
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: const BoxDecoration(
                    color: _vesperBlack,
                    border: Border(bottom: BorderSide(color: _vesperBorder, width: 1)),
                  ),
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Document', icon: Icon(Icons.description_outlined)),
                      Tab(text: 'Link', icon: Icon(Icons.link_outlined)),
                      Tab(text: 'Text', icon: Icon(Icons.text_fields_outlined)),
                    ],
                    labelColor: _vesperCyan,
                    unselectedLabelColor: _vesperTextMuted,
                    indicatorColor: _vesperCyan,
                    indicatorWeight: 2,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    labelStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            drawer: const HistorySidebar(),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: TabBarView(
                  children: [
                    _DocumentTab(
                      chatProvider: chatProvider,
                      hasRecentSession: hasRecentSession,
                      onUploadAndOpenChat: _uploadAndOpenChat,
                      onOpenChat: _openChat,
                    ),
                    _LinkTab(
                      chatProvider: chatProvider,
                      urlController: _urlController,
                    ),
                    _TextTab(
                      chatProvider: chatProvider,
                      titleController: _textTitleController,
                      contentController: _textContentController,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DocumentTab extends StatelessWidget {
  const _DocumentTab({
    required this.chatProvider,
    required this.hasRecentSession,
    required this.onUploadAndOpenChat,
    required this.onOpenChat,
  });

  final ChatProvider chatProvider;
  final bool hasRecentSession;
  final Future<void> Function(BuildContext, ChatProvider) onUploadAndOpenChat;
  final void Function(BuildContext) onOpenChat;

  @override
  Widget build(BuildContext context) {
    if (chatProvider.isLoading && chatProvider.loadingType == LoadingType.document) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinKitPulse(color: _vesperCyan, size: 28),
            SizedBox(height: 18),
            Text(
              'Processing Document...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            decoration: BoxDecoration(
              color: _vesperSurface,
              border: Border.all(color: _vesperBorder, width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    border: Border.all(color: _vesperBorder, width: 1),
                    borderRadius: BorderRadius.circular(44),
                  ),
                  child: const Icon(Icons.hub_outlined, size: 38, color: _vesperCyan),
                ),
                const SizedBox(height: 20),
                const Text(
                  'VESPER CORE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _vesperCyan,
                    fontFamily: 'Roboto',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 26,
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: _vesperTextMuted,
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                    child: AnimatedTextKit(
                      repeatForever: true,
                      pause: const Duration(milliseconds: 900),
                      animatedTexts: [
                        FadeAnimatedText('Neural document intelligence online'),
                        FadeAnimatedText('Upload PDF and begin precision query'),
                        FadeAnimatedText('Context memory aligned and ready'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: chatProvider.isLoading ? null : () => onUploadAndOpenChat(context, chatProvider),
                    style: FilledButton.styleFrom(
                      backgroundColor: _vesperSurface,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _vesperCyan, width: 1),
                      ),
                      elevation: 0,
                    ),
                    icon: chatProvider.isLoading
                        ? const SpinKitPulse(color: _vesperBlack, size: 16)
                        : const Icon(Icons.upload_file_rounded),
                    label: const Text(
                      'Upload New PDF',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (hasRecentSession) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => onOpenChat(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _vesperSurface,
                        side: const BorderSide(color: _vesperCyan, width: 1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text(
                        'Continue Recent Chat',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkTab extends StatefulWidget {
  const _LinkTab({required this.chatProvider, required this.urlController});

  final ChatProvider chatProvider;
  final TextEditingController urlController;

  @override
  State<_LinkTab> createState() => _LinkTabState();
}

enum _LinkType { none, youtube, web, drive }

class _LinkTabState extends State<_LinkTab> {
  _LinkType _selected = _LinkType.none;

  void _select(_LinkType t) {
    setState(() {
      _selected = t;
      widget.urlController.clear();
    });
  }

  void _back() {
    setState(() {
      _selected = _LinkType.none;
      widget.urlController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = widget.chatProvider;

    if (chatProvider.isLoading && chatProvider.loadingType == LoadingType.link) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinKitPulse(color: _vesperCyan, size: 28),
            SizedBox(height: 18),
            Text(
              'Processing Link...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            decoration: BoxDecoration(
              color: _vesperSurface,
              border: Border.all(color: _vesperBorder, width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _selected == _LinkType.none ? _buildChoice(context) : _buildInput(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoice(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool narrow = constraints.maxWidth < 600;
      final children = [
        _choiceCard(
          context,
          icon: Icons.smart_display_outlined,
          title: 'YouTube Video',
          subtitle: 'Process video transcripts',
          onTap: () => _select(_LinkType.youtube),
        ),
        _choiceCard(
          context,
          icon: Icons.article_outlined,
          title: 'Web Article',
          subtitle: 'Extract text from any website',
          onTap: () => _select(_LinkType.web),
        ),
        _choiceCard(
          context,
          icon: Icons.add_to_drive_outlined,
          title: 'Google Drive PDF',
          subtitle: 'Process shared Drive links',
          onTap: () => _select(_LinkType.drive),
        ),
      ];

      return SizedBox(
        key: const ValueKey('choices'),
        child: narrow
            ? Column(
                children: [
                  children[0],
                  const SizedBox(height: 12),
                  children[1],
                  const SizedBox(height: 12),
                  children[2],
                ],
              )
            : Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 12),
                  Expanded(child: children[1]),
                  const SizedBox(width: 12),
                  Expanded(child: children[2]),
                ],
              ),
      );
    });
  }

  Widget _choiceCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _vesperBlack,
          border: Border.all(color: _vesperBorder, width: 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: _vesperCyan),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: _vesperTextMuted, fontFamily: 'Roboto', fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final String label;
    final String hint;
    final IconData prefixIcon;

    switch (_selected) {
      case _LinkType.youtube:
        label = 'YouTube URL';
        hint = 'https://youtube.com/...';
        prefixIcon = Icons.smart_display_outlined;
        break;
      case _LinkType.drive:
        label = 'Google Drive URL';
        hint = 'https://drive.google.com/file/d/...';
        prefixIcon = Icons.add_to_drive_outlined;
        break;
      default:
        label = 'Article URL';
        hint = 'https://example.com/article';
        prefixIcon = Icons.article_outlined;
    }

    return Container(
      key: const ValueKey('input'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back, color: _vesperCyan),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.urlController,
            style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _vesperTextMuted, fontFamily: 'Roboto'),
              prefixIcon: Icon(prefixIcon, color: _vesperCyan),
              filled: true,
              fillColor: _vesperBlack,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _vesperBorder, width: 1)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _vesperBorder, width: 1)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _vesperCyan, width: 1)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _back(),
                  style: FilledButton.styleFrom(backgroundColor: _vesperBlack, foregroundColor: _vesperCyan, elevation: 0, side: const BorderSide(color: _vesperBorder, width: 1)),
                  child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Back', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.urlController.text.trim().isEmpty || widget.chatProvider.isLoading
                      ? null
                      : () async {
                          final previous = widget.chatProvider.sessionId;
                          final ctx = context;
                          try {
                            await widget.chatProvider.processUrl(widget.urlController.text.trim());
                            if (widget.chatProvider.sessionId != null && widget.chatProvider.sessionId != previous) {
                              widget.urlController.clear();
                              if (!ctx.mounted) return;
                              Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ChatScreen()));
                            }
                          } catch (_) {}
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _vesperSurface,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    side: const BorderSide(color: _vesperCyan, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Process', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.chatProvider,
    required this.titleController,
    required this.contentController,
  });

  final ChatProvider chatProvider;
  final TextEditingController titleController;
  final TextEditingController contentController;

  @override
  Widget build(BuildContext context) {
    if (chatProvider.isLoading && chatProvider.loadingType == LoadingType.text) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinKitPulse(color: _vesperCyan, size: 28),
            SizedBox(height: 18),
            Text(
              'Processing Text...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Indexing your content.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _vesperTextMuted,
                fontFamily: 'Roboto',
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            decoration: BoxDecoration(
              color: _vesperSurface,
              border: Border.all(color: _vesperBorder, width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.text_fields_outlined, size: 52, color: _vesperCyan),
                const SizedBox(height: 20),
                const Text(
                  'Process Raw Text',
                  style: TextStyle(
                    color: _vesperCyan,
                    fontFamily: 'Roboto',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paste text content for semantic analysis',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _vesperTextMuted,
                    fontFamily: 'Roboto',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Roboto',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Give this content a title',
                    hintStyle: const TextStyle(color: _vesperTextMuted, fontFamily: 'Roboto'),
                    prefixIcon: const Icon(Icons.label_outline, color: _vesperCyan),
                    filled: true,
                    fillColor: _vesperBlack,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _vesperBorder, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _vesperBorder, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _vesperCyan, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 8,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Roboto',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste your text content here...',
                    hintStyle: const TextStyle(color: _vesperTextMuted, fontFamily: 'Roboto'),
                    filled: true,
                    fillColor: _vesperBlack,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _vesperBorder, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _vesperBorder, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _vesperCyan, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: chatProvider.isLoading || titleController.text.trim().isEmpty || contentController.text.trim().isEmpty
                        ? null
                        : () async {
                            final previous = chatProvider.sessionId;
                            final ctx = context;
                            try {
                              await chatProvider.processText(contentController.text.trim(), titleController.text.trim());
                              if (chatProvider.sessionId != null && chatProvider.sessionId != previous) {
                                titleController.clear();
                                contentController.clear();
                                if (!ctx.mounted) return;
                                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ChatScreen()));
                              }
                            } catch (_) {}
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Process Text',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _vesperSurface,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _vesperCyan, width: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
