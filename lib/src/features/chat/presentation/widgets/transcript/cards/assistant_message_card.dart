import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/markdown_style_factory.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class AssistantMessageCard extends StatelessWidget {
  const AssistantMessageCard({super.key, required this.block});

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
      isAssistant: true,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        decoration: BoxDecoration(
          color: cards.tintedSurface(
            palette.accent,
            lightAlpha: 0.1,
            darkAlpha: 0.18,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: cards.accentBorder(
              palette.accent,
              lightAlpha: 0.42,
              darkAlpha: 0.56,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(
                alpha: cards.isDark ? 0.16 : 0.1,
              ),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: cards.shadow.withValues(
                alpha: cards.isDark ? 0.26 : 0.08,
              ),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  palette.icon,
                  size: 18,
                  color: palette.accent,
                ),
                const SizedBox(width: 7),
                Text(
                  block.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                    letterSpacing: 0.3,
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
            const SizedBox(height: 10),
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
