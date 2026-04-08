import 'package:flutter/material.dart';

import 'live_lane_notice_contract.dart';

class LiveLaneNoticeSurface extends StatelessWidget {
  const LiveLaneNoticeSurface({super.key, required this.contract});

  final LiveLaneNoticeContract contract;

  @override
  Widget build(BuildContext context) {
    final entries = contract.entries;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    if (entries.length == 1) {
      return _LiveLaneNoticeCard(entry: entries.single);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _LiveLaneNoticeCard(entry: entries[index]),
        ],
      ],
    );
  }
}

class _LiveLaneNoticeCard extends StatelessWidget {
  const _LiveLaneNoticeCard({required this.entry});

  final LiveLaneNoticeEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (containerColor, borderColor, foregroundColor) = switch (entry.tone) {
      LiveLaneNoticeTone.informational => (
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.94),
        theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        theme.colorScheme.onSurface,
      ),
      LiveLaneNoticeTone.warning => (
        theme.colorScheme.secondaryContainer.withValues(alpha: 0.94),
        theme.colorScheme.secondary.withValues(alpha: 0.22),
        theme.colorScheme.onSecondaryContainer,
      ),
    };

    return DecoratedBox(
      key: ValueKey<String>('live_lane_notice_${entry.key}'),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(entry.icon, color: foregroundColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.88),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
