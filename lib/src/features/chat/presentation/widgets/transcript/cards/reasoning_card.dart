import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/markdown_style_factory.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class ReasoningCard extends StatelessWidget {
  const ReasoningCard({super.key, required this.block});

  final CodexTextBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final palette = paletteFor(block.kind, theme.brightness);
    final markdownStyle = buildConversationMarkdownStyle(
      theme: theme,
      cards: cards,
      accent: palette.accent,
      isAssistant: false,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 660),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.2 : 0.06),
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
                Icon(palette.icon, size: 16, color: palette.accent),
                const SizedBox(width: 7),
                Text(
                  block.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                    letterSpacing: 0.2,
                  ),
                ),
                if (block.isRunning) ...[
                  const SizedBox(width: 8),
                  const InlinePulseChip(label: 'running'),
                ],
              ],
            ),
            if (block.isRunning) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                minHeight: 2,
                color: palette.accent,
                backgroundColor: palette.accent.withValues(alpha: 0.08),
              ),
            ],
            const SizedBox(height: 8),
            MarkdownBody(
              data: block.body.trim().isEmpty
                  ? '_Waiting for content…_'
                  : block.body,
              selectable: true,
              styleSheet: markdownStyle,
            ),
          ],
        ),
      ),
    );
  }
}
