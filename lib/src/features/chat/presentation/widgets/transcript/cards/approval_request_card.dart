import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class ApprovalRequestCard extends StatelessWidget {
  const ApprovalRequestCard({
    super.key,
    required this.block,
    this.onApprove,
    this.onDeny,
  });

  final CodexApprovalRequestBlock block;
  final Future<void> Function(String requestId)? onApprove;
  final Future<void> Function(String requestId)? onDeny;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(Theme.of(context).brightness);
    final canRespond = !block.isResolved && onApprove != null && onDeny != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.14),
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
                Icon(Icons.gpp_maybe_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (block.isResolved)
                  TranscriptBadge(
                    label: block.resolutionLabel ?? 'resolved',
                    color: accent,
                  ),
              ],
            ),
            if (block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                block.body,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 13,
                  height: 1.32,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                  onPressed: canRespond ? () => onDeny!(block.requestId) : null,
                  child: const Text('Deny'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: canRespond ? () => onApprove!(block.requestId) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
