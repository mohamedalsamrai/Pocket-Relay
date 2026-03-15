import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class PlanUpdateCard extends StatelessWidget {
  const PlanUpdateCard({super.key, required this.block});

  final CodexPlanUpdateBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = blueAccent(Theme.of(context).brightness);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rtl, size: 16, color: accent),
                const SizedBox(width: 7),
                Text(
                  'Updated Plan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            if (block.explanation != null &&
                block.explanation!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                block.explanation!,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 13,
                  height: 1.32,
                ),
              ),
            ],
            if (block.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...block.steps.map((step) {
                final status = planStepStatus(step.status, cards);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: status.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(status.icon, size: 16, color: status.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.step,
                          style: TextStyle(
                            color: cards.textPrimary,
                            fontSize: 13,
                            height: 1.28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TranscriptBadge(
                        label: status.label,
                        color: status.accent,
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Waiting for plan steps…',
                style: TextStyle(color: cards.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
