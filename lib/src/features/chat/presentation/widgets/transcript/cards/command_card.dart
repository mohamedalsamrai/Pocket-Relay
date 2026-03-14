import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class CommandCard extends StatelessWidget {
  const CommandCard({super.key, required this.block});

  final CodexCommandExecutionBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final runningColor = tealAccent(theme.brightness);
    final output = block.output.trim().isEmpty
        ? 'Waiting for output…'
        : block.output;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        decoration: BoxDecoration(
          color: cards.terminalShell,
          borderRadius: BorderRadius.circular(18),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Icon(
                    Icons.terminal,
                    color: cards.terminalText.withValues(alpha: 0.72),
                    size: 16,
                  ),
                  Text(
                    block.command,
                    style: TextStyle(
                      color: cards.terminalText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (block.isRunning)
                    StateChip(label: 'running', color: runningColor)
                  else if (block.exitCode != null)
                    StateChip(
                      label: 'exit ${block.exitCode}',
                      color: block.exitCode == 0
                          ? blueAccent(theme.brightness)
                          : redAccent(theme.brightness),
                    ),
                ],
              ),
            ),
            if (block.isRunning)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: cards.terminalBody,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: SelectableText(
                output,
                style: TextStyle(
                  color: cards.terminalText,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
