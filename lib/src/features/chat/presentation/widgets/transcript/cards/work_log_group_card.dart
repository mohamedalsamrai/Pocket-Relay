import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class WorkLogGroupCard extends StatefulWidget {
  const WorkLogGroupCard({super.key, required this.block});

  final CodexWorkLogGroupBlock block;

  @override
  State<WorkLogGroupCard> createState() => _WorkLogGroupCardState();
}

class _WorkLogGroupCardState extends State<WorkLogGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final entries = widget.block.entries;
    final hasOverflow = entries.length > 3;
    final visibleEntries = hasOverflow && !_expanded
        ? entries.skip(entries.length - 3).toList(growable: false)
        : entries;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cards.neutralBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 16,
                  color: cards.textMuted,
                ),
                const SizedBox(width: 7),
                Text(
                  entries.every(
                        (entry) =>
                            entry.entryKind != CodexWorkLogEntryKind.unknown,
                      )
                      ? 'Work log'
                      : 'Activity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cards.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length}',
                  style: TextStyle(
                    color: cards.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...visibleEntries.map((entry) => _WorkLogEntryRow(entry: entry)),
            if (hasOverflow) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded
                      ? 'Show less'
                      : 'Show ${entries.length - visibleEntries.length} more',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkLogEntryRow extends StatelessWidget {
  const _WorkLogEntryRow({required this.entry});

  final CodexWorkLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final icon = workLogIcon(entry.entryKind);
    final accent = workLogAccent(entry.entryKind, theme.brightness);
    final title = _normalizeCompactToolLabel(entry.title);
    final preview = _normalizedWorkLogPreview(entry.preview, title);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cards.accentBorder(accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cards.textSecondary,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.isRunning)
            TranscriptBadge(
              label: 'running',
              color: tealAccent(theme.brightness),
            )
          else if (entry.exitCode != null)
            TranscriptBadge(
              label: 'exit ${entry.exitCode}',
              color: entry.exitCode == 0
                  ? blueAccent(theme.brightness)
                  : redAccent(theme.brightness),
            ),
        ],
      ),
    );
  }
}

String _normalizeCompactToolLabel(String value) {
  return value
      .replaceFirst(
        RegExp(r'\s+(?:complete|completed)\s*$', caseSensitive: false),
        '',
      )
      .trim();
}

String? _normalizedWorkLogPreview(String? preview, String normalizedTitle) {
  final value = preview?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value == normalizedTitle) {
    return null;
  }
  return value;
}
