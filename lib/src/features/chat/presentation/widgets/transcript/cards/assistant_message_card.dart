import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/markdown_style_factory.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class AssistantMessageCard extends StatelessWidget {
  const AssistantMessageCard({super.key, required this.block, this.turnTimer});

  final CodexTextBlock block;
  final CodexSessionTurnTimer? turnTimer;

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

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(palette.icon, size: 18, color: palette.accent),
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
              if (turnTimer != null)
                TurnElapsedFooter(
                  turnTimer: turnTimer!,
                  accent: palette.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
