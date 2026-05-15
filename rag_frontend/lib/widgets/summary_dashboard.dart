import 'dart:convert';

import 'package:flutter/material.dart';

typedef VoidCallback = void Function();

/// Interactive Summary Dashboard extracted from chat_screen.
class SummaryDashboardWidget extends StatelessWidget {
  const SummaryDashboardWidget({
    super.key,
    required this.summaryData,
    required this.onDownload,
    required this.onDismiss,
  });

  final Map<String, dynamic> summaryData;
  final VoidCallback onDownload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const neonOrange = Color(0xFFFF5F1F);
    const cardBg = Color(0xFF2D2D34);
    const borderColor = Color(0xFF3F3F46);

    final normalizedSummary = _normalizeSummaryData(summaryData);

    final sections = <_SummarySection>[
      _SummarySection(
        icon: Icons.dashboard_outlined,
        title: 'Overview',
        content: _summaryTextValue(
          normalizedSummary['overview'],
          'No overview available',
        ),
        isExpandedByDefault: true,
      ),
      _SummarySection(
        icon: Icons.lightbulb_outline,
        title: 'Key Findings',
        items: _parseListField(normalizedSummary['key_findings']),
      ),
      _SummarySection(
        icon: Icons.analytics_outlined,
        title: 'Critical Data Points',
        items: _parseListField(normalizedSummary['critical_data_points']),
      ),
      _SummarySection(
        icon: Icons.flag_outlined,
        title: 'Conclusion',
        content: _summaryTextValue(
          normalizedSummary['conclusion'],
          'No conclusion available',
        ),
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
                    onPressed: onDismiss,
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
                  initiallyExpanded: section.isExpandedByDefault,
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
                  collapsedIconColor: neonOrange.withValues(alpha: 0.6),
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
                    if (section.content != null && section.content!.isNotEmpty)
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
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: neonOrange.withValues(alpha: 0.7),
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
                  onPressed: onDownload,
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
}

Map<String, dynamic> _normalizeSummaryData(dynamic summaryData) {
  dynamic value = summaryData;

  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      value = <String, dynamic>{};
    }
  }

  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

String _summaryTextValue(dynamic field, String fallback) {
  final value = field?.toString().trim();
  if (value == null || value.isEmpty) {
    return fallback;
  }
  return value;
}

List<String> _parseListField(dynamic field) {
  if (field is List) {
    return field.map((e) => e.toString()).toList();
  }
  return <String>[];
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
