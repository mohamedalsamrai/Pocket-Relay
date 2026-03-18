import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_work_log_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class WorkLogGroupCard extends StatefulWidget {
  const WorkLogGroupCard({super.key, required this.item});

  final ChatWorkLogGroupItemContract item;

  @override
  State<WorkLogGroupCard> createState() => _WorkLogGroupCardState();
}

class _WorkLogGroupCardState extends State<WorkLogGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final entries = widget.item.entries;
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
                  widget.item.hasOnlyKnownEntries ? 'Work log' : 'Activity',
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

  final ChatWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final ChatReadCommandWorkLogEntryContract readEntry =>
        _ReadCommandWorkLogEntryRow(entry: readEntry),
      final ChatGenericWorkLogEntryContract genericEntry =>
        _GenericWorkLogEntryRow(entry: genericEntry),
    };
  }
}

class _GenericWorkLogEntryRow extends StatelessWidget {
  const _GenericWorkLogEntryRow({required this.entry});

  final ChatGenericWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final icon = workLogIcon(entry.entryKind);
    final accent = workLogAccent(entry.entryKind, theme.brightness);

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
                  entry.title,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (entry.preview != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.preview!,
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

class _ReadCommandWorkLogEntryRow extends StatelessWidget {
  const _ReadCommandWorkLogEntryRow({required this.entry});

  final ChatReadCommandWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final accent = blueAccent(theme.brightness);
    final statusBadge = _readStatusBadge(theme, entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.1, darkAlpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cards.accentBorder(accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cards.tintedSurface(
                accent,
                lightAlpha: 0.16,
                darkAlpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.menu_book_outlined, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.lineSummary,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.fileName,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.filePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cards.textSecondary,
                    fontSize: 11.25,
                    height: 1.25,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (statusBadge != null) ...[const SizedBox(width: 8), statusBadge],
        ],
      ),
    );
  }
}

Widget? _readStatusBadge(
  ThemeData theme,
  ChatReadCommandWorkLogEntryContract entry,
) {
  if (entry.isRunning) {
    return TranscriptBadge(
      label: 'running',
      color: tealAccent(theme.brightness),
    );
  }
  if (entry.exitCode != null && entry.exitCode != 0) {
    return TranscriptBadge(
      label: 'exit ${entry.exitCode}',
      color: redAccent(theme.brightness),
    );
  }
  return null;
}
