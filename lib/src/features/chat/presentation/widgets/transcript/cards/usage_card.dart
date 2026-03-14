import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class UsageCard extends StatelessWidget {
  const UsageCard({super.key, required this.block});

  final CodexUsageBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = violetAccent(Theme.of(context).brightness);
    final summary = UsagePresentation.fromBody(block.body);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: cards.tintedSurface(accent, lightAlpha: 0.05, darkAlpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cards.accentBorder(accent, lightAlpha: 0.24, darkAlpha: 0.34),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    block.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (summary.contextWindow != null)
                  _UsageBadge(
                    label: 'ctx ${summary.contextWindow!}',
                    color: accent,
                    tinted: true,
                  ),
              ],
            ),
            if (summary.sections.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (var index = 0; index < summary.sections.length; index += 1) ...[
                if (index > 0) const SizedBox(height: 5),
                _UsageSectionWrap(
                  section: summary.sections[index],
                  accent: accent,
                  cards: cards,
                ),
              ],
            ] else if (block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                block.body.trim(),
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageSectionWrap extends StatelessWidget {
  const _UsageSectionWrap({
    required this.section,
    required this.accent,
    required this.cards,
  });

  final UsageSection section;
  final Color accent;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (section.label != null)
          _UsageBadge(label: section.label!, color: accent, tinted: true),
        for (final metric in section.metrics)
          _UsageBadge(
            label: '${metric.label} ${metric.value}',
            color: accent,
            tinted: false,
          ),
        for (final note in section.notes)
          _UsageNoteBadge(label: note, cards: cards),
      ],
    );
  }
}

class _UsageBadge extends StatelessWidget {
  const _UsageBadge({
    required this.label,
    required this.color,
    required this.tinted,
  });

  final String label;
  final Color color;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: tinted
            ? color.withValues(alpha: cards.isDark ? 0.18 : 0.1)
            : cards.surface.withValues(alpha: cards.isDark ? 0.68 : 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: tinted
              ? color.withValues(alpha: cards.isDark ? 0.42 : 0.24)
              : cards.accentBorder(
                  color,
                  lightAlpha: 0.14,
                  darkAlpha: 0.22,
                ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tinted ? color : cards.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _UsageNoteBadge extends StatelessWidget {
  const _UsageNoteBadge({required this.label, required this.cards});

  final String label;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: cards.surface.withValues(alpha: cards.isDark ? 0.68 : 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cards.neutralBorder.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cards.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class UsagePresentation {
  const UsagePresentation({
    required this.sections,
    this.contextWindow,
  });

  factory UsagePresentation.fromBody(String body) {
    final sections = <UsageSection>[];
    String? contextWindow;

    for (final rawLine in body.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final contextMatch = RegExp(
        r'^Context window:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (contextMatch != null) {
        contextWindow = contextMatch.group(1)?.trim();
        continue;
      }

      final labeledMatch = RegExp(
        r'^(Last|Total):\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (labeledMatch != null) {
        sections.add(
          _parseUsageSection(
            labeledMatch.group(2) ?? '',
            label: labeledMatch.group(1)?.toLowerCase(),
          ),
        );
        continue;
      }

      sections.add(_parseUsageSection(line));
    }

    final compactSections = sections
        .where((section) => section.metrics.isNotEmpty || section.notes.isNotEmpty)
        .toList(growable: false);

    if (compactSections.length == 2 &&
        compactSections.first.hasSameContent(compactSections.last)) {
      return UsagePresentation(
        sections: <UsageSection>[
          compactSections.first.copyWith(label: null),
        ],
        contextWindow: contextWindow,
      );
    }

    return UsagePresentation(
      sections: compactSections,
      contextWindow: contextWindow,
    );
  }

  final List<UsageSection> sections;
  final String? contextWindow;
}

class UsageSection {
  const UsageSection({
    required this.metrics,
    required this.notes,
    this.label,
  });

  final String? label;
  final List<UsageMetric> metrics;
  final List<String> notes;

  UsageSection copyWith({
    String? label,
    List<UsageMetric>? metrics,
    List<String>? notes,
  }) {
    return UsageSection(
      label: label,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
    );
  }

  bool hasSameContent(UsageSection other) {
    if (metrics.length != other.metrics.length || notes.length != other.notes.length) {
      return false;
    }

    for (var index = 0; index < metrics.length; index += 1) {
      if (metrics[index] != other.metrics[index]) {
        return false;
      }
    }

    for (var index = 0; index < notes.length; index += 1) {
      if (notes[index] != other.notes[index]) {
        return false;
      }
    }

    return true;
  }
}

class UsageMetric {
  const UsageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  bool operator ==(Object other) {
    return other is UsageMetric &&
        other.label == label &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(label, value);
}

UsageSection _parseUsageSection(String source, {String? label}) {
  final metrics = <UsageMetric>[];
  final notes = <String>[];
  final recognizedMetricLabels = <String>{
    'input',
    'cached',
    'output',
    'reasoning',
    'total',
    'cost',
    'exit',
  };

  for (final rawSegment in source.split('·')) {
    final segment = rawSegment.trim();
    if (segment.isEmpty) {
      continue;
    }

    final match = RegExp(r'^([A-Za-z]+)\s+(.+)$').firstMatch(segment);
    final metricLabel = match?.group(1)?.toLowerCase();
    final metricValue = match?.group(2)?.trim();
    if (metricLabel != null &&
        metricValue != null &&
        metricValue.isNotEmpty &&
        recognizedMetricLabels.contains(metricLabel)) {
      metrics.add(UsageMetric(label: metricLabel, value: metricValue));
      continue;
    }

    notes.add(segment);
  }

  return UsageSection(label: label, metrics: metrics, notes: notes);
}
