part of 'flutter_chat_screen_renderer.dart';

class _TimelineSelector extends StatelessWidget {
  const _TimelineSelector({
    required this.timelines,
    required this.onSelectTimeline,
  });

  final List<ChatTimelineSummaryContract> timelines;
  final ValueChanged<String> onSelectTimeline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        itemCount: timelines.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final timeline = timelines[index];
          return _TimelineChip(
            summary: timeline,
            onPressed: () => onSelectTimeline(timeline.threadId),
          );
        },
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  const _TimelineChip({required this.summary, required this.onPressed});

  final ChatTimelineSummaryContract summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final statusColor = _timelineStatusColor(summary.status, theme);
    final foregroundColor = summary.isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final backgroundColor = summary.isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.10)
        : palette.surface.withValues(alpha: 0.72);
    final borderColor = summary.isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.45)
        : palette.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('timeline_${summary.threadId}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: palette.shadowColor,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 132),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          summary.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (summary.hasUnreadActivity) ...[
                        const SizedBox(width: 6),
                        _TimelineSignalPill(
                          label: 'New',
                          backgroundColor: theme.colorScheme.primary,
                        ),
                      ],
                      if (summary.hasPendingRequests) ...[
                        const SizedBox(width: 6),
                        _TimelineSignalPill(
                          label: 'Needs action',
                          backgroundColor: theme.colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _timelineStatusLabel(summary),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineSignalPill extends StatelessWidget {
  const _TimelineSignalPill({
    required this.label,
    required this.backgroundColor,
  });

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: backgroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _timelineStatusLabel(ChatTimelineSummaryContract summary) {
  if (summary.isClosed) {
    return 'Closed';
  }

  return switch (summary.status) {
    CodexAgentLifecycleState.unknown => 'Starting',
    CodexAgentLifecycleState.starting => 'Starting',
    CodexAgentLifecycleState.idle => 'Ready',
    CodexAgentLifecycleState.running => 'Running',
    CodexAgentLifecycleState.waitingOnChild => 'Waiting on child',
    CodexAgentLifecycleState.blockedOnApproval => 'Waiting on approval',
    CodexAgentLifecycleState.blockedOnInput => 'Waiting on input',
    CodexAgentLifecycleState.completed => 'Completed',
    CodexAgentLifecycleState.failed => 'Failed',
    CodexAgentLifecycleState.aborted => 'Aborted',
    CodexAgentLifecycleState.closed => 'Closed',
  };
}

Color _timelineStatusColor(CodexAgentLifecycleState state, ThemeData theme) {
  return switch (state) {
    CodexAgentLifecycleState.unknown ||
    CodexAgentLifecycleState.starting => theme.colorScheme.primary,
    CodexAgentLifecycleState.idle => theme.colorScheme.secondary,
    CodexAgentLifecycleState.running => theme.colorScheme.primary,
    CodexAgentLifecycleState.waitingOnChild => theme.colorScheme.tertiary,
    CodexAgentLifecycleState.blockedOnApproval => const Color(0xFFB45309),
    CodexAgentLifecycleState.blockedOnInput => const Color(0xFF1D4ED8),
    CodexAgentLifecycleState.completed => const Color(0xFF15803D),
    CodexAgentLifecycleState.failed => theme.colorScheme.error,
    CodexAgentLifecycleState.aborted => theme.colorScheme.outline,
    CodexAgentLifecycleState.closed => theme.colorScheme.outline,
  };
}
