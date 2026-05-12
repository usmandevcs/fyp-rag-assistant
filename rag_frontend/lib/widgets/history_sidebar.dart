import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
import 'package:frontend/screens/chat_screen.dart';
import 'package:frontend/screens/home_screen.dart';

class HistorySidebar extends StatelessWidget {
  const HistorySidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final sessionId = chatProvider.sessionId;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF121212), const Color(0xFF0D0D0D)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: const Color(0x66111111),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x33161A1F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA78BFA).withValues(alpha: 0.22),
                          blurRadius: 14,
                          spreadRadius: 0.8,
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.memory,
                            color: const Color(0xFFA78BFA),
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VESPER CORE',
                                  style: GoogleFonts.shareTechMono(
                                    color: const Color(0xFFA78BFA),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'SYSTEM CONTROL PANEL',
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.white.withValues(alpha: 0.76),
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: ListTile(
                    tileColor: const Color(0x33222A31),
                    hoverColor: const Color(0xFFA78BFA).withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.22),
                      ),
                    ),
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: const Color(0xFFA78BFA),
                    ),
                    title: Text(
                      'New Chat',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      await chatProvider.clearSession();
                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(context);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (_) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ),
                if (sessionId != null && sessionId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: ListTile(
                      enabled: false,
                      tileColor: const Color(0x26222A31),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      leading: const Icon(
                        Icons.hub_outlined,
                        color: Color(0xFFA78BFA),
                      ),
                      title: Text(
                        'Current Document',
                        style: GoogleFonts.shareTechMono(color: Colors.white),
                      ),
                      subtitle: Text(
                        chatProvider.filename ?? 'Unknown Document',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                if (sessionId != null && sessionId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Divider(color: colorScheme.outlineVariant),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Text(
                    'PAST DOCUMENTS',
                    style: GoogleFonts.shareTechMono(
                      color: const Color(0xFFA78BFA),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (chatProvider.pastSessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(
                      'No past documents yet',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  ...chatProvider.pastSessions.map((session) {
                    final sid = session['session_id'] as String?;
                    final isCurrent = sid == sessionId;
                    final isSelected = sid != null &&
                        chatProvider.selectedSessionIds.contains(sid);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: ListTile(
                        tileColor: isSelected
                            ? const Color(0xFFA78BFA).withValues(alpha: 0.18)
                            : isCurrent
                                ? const Color(0xFFA78BFA)
                                    .withValues(alpha: 0.12)
                                : const Color(0x1A222A31),
                        hoverColor:
                            const Color(0xFFA78BFA).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFFA78BFA)
                                : isCurrent
                                    ? const Color(0xFFA78BFA)
                                    : const Color(0xFFA78BFA)
                                        .withValues(alpha: 0.18),
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        leading: Icon(
                          Icons.description_outlined,
                          color: isCurrent || isSelected
                              ? const Color(0xFFA78BFA)
                              : Colors.white.withValues(alpha: 0.6),
                          size: 18,
                        ),
                        title: Text(
                          session['filename'] ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.shareTechMono(
                            color: isCurrent || isSelected
                                ? const Color(0xFFA78BFA)
                                : Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: isCurrent || isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Multi-doc selection checkbox
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: sid == null
                                    ? null
                                    : (_) => chatProvider
                                        .toggleSessionSelection(sid),
                                activeColor: const Color(0xFFA78BFA),
                                checkColor: const Color(0xFF0D0D12),
                                side: BorderSide(
                                  color: const Color(0xFFA78BFA)
                                      .withValues(alpha: 0.5),
                                  width: 1.6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Delete button
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  await chatProvider
                                      .removeSession(session['session_id']);
                                },
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await chatProvider.loadSession(
                            session['session_id'],
                            session['filename'] ?? 'Unknown',
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.pop(context); // close the drawer
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChatScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
