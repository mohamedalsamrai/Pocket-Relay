part of 'changed_files_card.dart';

class _LiveUpdateLabel extends StatelessWidget {
  const _LiveUpdateLabel({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          'updating',
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ChangedFileRow extends StatelessWidget {
  const _ChangedFileRow({
    required this.row,
    required this.cards,
    required this.isLast,
    this.onOpenDiff,
  });

  final ChatChangedFileRowContract row;
  final ConversationCardPalette cards;
  final bool isLast;
  final void Function(ChatChangedFileDiffContract diff)? onOpenDiff;

  bool get _canOpenDiff => row.canOpenDiff && onOpenDiff != null;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForOperation(row.operationKind, cards.brightness);
    final body = Container(
      key: ValueKey<String>('changed_file_row_${row.id}'),
      decoration: BoxDecoration(
        color: _canOpenDiff
            ? cards.tintedSurface(accent, lightAlpha: 0.035, darkAlpha: 0.08)
            : Colors.transparent,
        borderRadius: PocketRadii.circular(PocketRadii.md),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Icon(_iconForOperation(row.operationKind), size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                if (_secondaryLabel(row) case final secondaryLabel?) ...[
                  Text(
                    secondaryLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cards.textMuted,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  _tertiaryLabel(row),
                  style: TextStyle(
                    color: _canOpenDiff ? cards.textSecondary : cards.textMuted,
                    fontSize: 11.5,
                    fontWeight: _canOpenDiff
                        ? FontWeight.w600
                        : FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ChangeStatColumn(row: row, cards: cards),
          if (_canOpenDiff) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cards.textMuted),
          ],
        ],
      ),
    );

    final content = Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, isLast ? 8 : 0),
      child: body,
    );
    final divider = isLast
        ? null
        : Divider(
            height: 1,
            thickness: 1,
            color: cards.neutralBorder.withValues(alpha: 0.45),
          );

    if (!_canOpenDiff) {
      return Column(
        children: [
          content,
          if (divider case final Divider resolvedDivider) resolvedDivider,
        ],
      );
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: PocketRadii.circular(PocketRadii.md),
            onTap: () => onOpenDiff!(row.diff!),
            child: content,
          ),
        ),
        if (divider case final Divider resolvedDivider) resolvedDivider,
      ],
    );
  }
}

class _ChangeStatColumn extends StatelessWidget {
  const _ChangeStatColumn({required this.row, required this.cards});

  final ChatChangedFileRowContract row;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    final hasChanges = row.stats.hasChanges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          hasChanges ? '+${row.stats.additions}' : ' ',
          style: TextStyle(
            color: tealAccent(cards.brightness),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hasChanges ? '-${row.stats.deletions}' : ' ',
          style: TextStyle(
            color: redAccent(cards.brightness),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
