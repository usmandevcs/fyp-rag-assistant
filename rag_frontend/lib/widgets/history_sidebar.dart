import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/chat_provider.dart';
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
                        color: Colors.cyanAccent.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x33161A1F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.22),
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
                            color: Colors.cyanAccent,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'JARVIS CORE',
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.cyanAccent,
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
                    hoverColor: Colors.cyanAccent.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.cyanAccent.withValues(alpha: 0.22),
                      ),
                    ),
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: Colors.cyanAccent,
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
                        color: Colors.cyanAccent,
                      ),
                      title: Text(
                        'Current Document',
                        style: GoogleFonts.shareTechMono(color: Colors.white),
                      ),
                      subtitle: Text(
                        sessionId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
