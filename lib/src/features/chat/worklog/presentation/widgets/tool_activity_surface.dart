import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class WebSearchActivitySurface extends StatelessWidget {
  const WebSearchActivitySurface({super.key, required this.entry});

  final ChatWebSearchWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final accent = tealAccent(Theme.of(context).brightness);
    final palette = TranscriptPalette.of(context);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.travel_explore_outlined,
        label: entry.activityLabel,
        accent: accent,
        trailing: entry.isRunning
            ? TranscriptBadge(label: 'running', color: accent)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.queryText,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.resultSummary ?? entry.scopeLabel,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
