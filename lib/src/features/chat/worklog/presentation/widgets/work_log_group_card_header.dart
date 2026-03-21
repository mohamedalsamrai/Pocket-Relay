part of 'work_log_group_card.dart';

class _WorkLogHeader extends StatelessWidget {
  const _WorkLogHeader({
    required this.label,
    required this.accent,
    required this.totalCount,
    required this.hiddenCount,
    required this.isExpanded,
    required this.isInteractive,
    this.onTap,
  });

  final String label;
  final Color accent;
  final int totalCount;
  final int hiddenCount;
  final bool isExpanded;
  final bool isInteractive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final header = Row(
      children: [
        Icon(Icons.construction_outlined, size: 16, color: cards.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Text(
          hiddenCount > 0 && !isExpanded
              ? '$totalCount total · $hiddenCount hidden'
              : '$totalCount total',
          style: TextStyle(
            color: cards.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (isInteractive) ...[
          const SizedBox(width: 6),
          Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: cards.textMuted,
          ),
        ],
      ],
    );

    if (!isInteractive || onTap == null) {
      return header;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: header,
        ),
      ),
    );
  }
}
